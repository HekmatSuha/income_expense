import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';
import '../remote/accounts_remote_data_source.dart';
import '../remote/firebase_service.dart';
import 'tx_repository.dart' show dbProvider;

class AccountRepository {
  AccountRepository(this._ref, this.db, this.remote);

  final Ref _ref;
  final AppDatabase db;
  final AccountRemoteDataSource remote;

  StreamSubscription<List<RemoteAccountRecord>>? _remoteSubscription;
  String? _activeUserId;
  final _pendingUpserts = <String>{};

  bool _shouldSyncRemote(String userId) {
    final user = _ref.read(firebaseUserProvider);
    return user != null && user.uid == userId;
  }

  Future<void> triggerSync(String userId) async {
    if (userId.isEmpty) return;
    await _ensureRemoteSubscription(userId);
  }

  Stream<List<Account>> watch(String userId) {
    _ensureRemoteSubscription(userId);
    return db.watchAccountsForUser(userId);
  }

  Future<List<Account>> allForUser(String userId) => db.allAccountsForUser(userId);


  Future<void> update({
    required String id,
    String? name,
    String? type,
  }) async {
    await db.updateAccount(id, name: name, type: type);
  }

  Future<void> delete({
    required String id,
    String? reassignToAccountId,
  }) async {
    final usage = await db.countTransactionsWithAccount(id);
    if (usage > 0) {
      if (reassignToAccountId == null) {
        throw AccountInUseException(usage);
      }
      if (reassignToAccountId == id) {
        throw ArgumentError('Cannot reassign account to itself.');
      }
      await db.reassignTransactionsAccount(
        fromAccountId: id,
        toAccountId: reassignToAccountId,
      );
    }
    await db.deleteAccount(id);

  }

  Future<void> add({
    required String userId,
    required String name,
    required String type,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();
    final companion = AccountsCompanion(
      id: Value(id),
      userId: Value(userId),
      name: Value(name),
      type: Value(type),
      createdAt: Value(now),
    );

    await db.upsertAccount(companion);

    if (_shouldSyncRemote(userId)) {
      _pendingUpserts.add(id);
      await remote.upsert(
        RemoteAccountRecord(
          id: id,
          userId: userId,
          name: name,
          type: type,
          createdAt: now,
        ),
      );
    }
  }

  Future<void> ensureDefaults(String userId) async {
    final existing = await allForUser(userId);
    if (existing.isNotEmpty) return;

    const defaults = [
      ('Cash Wallet', 'cash'),
      ('Main Checking', 'bank'),
    ];

    for (final entry in defaults) {
      await add(userId: userId, name: entry.$1, type: entry.$2);
    }
  }

  void dispose() {
    _remoteSubscription?.cancel();
  }
}

class AccountInUseException implements Exception {
  AccountInUseException(this.transactionCount);

  final int transactionCount;

  @override
  String toString() =>
      'Account cannot be deleted because it is used by $transactionCount transactions';
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final db = ref.watch(dbProvider);
  final remote = ref.watch(accountRemoteDataSourceProvider);
  final repo = AccountRepository(ref, db, remote);
  ref.onDispose(repo.dispose);
  return repo;
});
