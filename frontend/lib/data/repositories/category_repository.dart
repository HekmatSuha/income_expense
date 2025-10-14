import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';
import '../remote/categories_remote_data_source.dart';
import '../remote/firebase_service.dart';
import 'tx_repository.dart' show dbProvider;

class CategoryRepository {
  CategoryRepository(this._ref, this.db, this.remote);

  final Ref _ref;
  final AppDatabase db;
  final CategoryRemoteDataSource remote;

  StreamSubscription<List<RemoteCategoryRecord>>? _remoteSubscription;
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

  Stream<List<Category>> watch(String userId) {
    _ensureRemoteSubscription(userId);
    return db.watchCategoriesForUser(userId);
  }

  Future<List<Category>> allForUser(String userId) => db.allCategoriesForUser(userId);

  Future<void> _ensureRemoteSubscription(String userId) async {
    if (!_shouldSyncRemote(userId)) {
      await _remoteSubscription?.cancel();
      _remoteSubscription = null;
      _activeUserId = null;
      return;
    }
    if (_activeUserId == userId && _remoteSubscription != null) {
      return;
    }
    await _remoteSubscription?.cancel();
    _activeUserId = userId;
    _remoteSubscription = remote.watch(userId).listen((records) {
      _mergeRemoteSnapshot(userId, records);
    });
  }

  Future<void> _mergeRemoteSnapshot(
    String userId,
    List<RemoteCategoryRecord> records,
  ) async {
    final remoteIds = records.map((record) => record.id).toSet();
    await db.transaction(() async {
      await db.upsertCategories(
        records.map((record) => record.toCompanion()).toList(),
      );
      final keepIds = remoteIds.union(_pendingUpserts);
      await db.purgeCategories(userId: userId, keepIds: keepIds);
    });

    for (final record in records) {
      _pendingUpserts.remove(record.id);
    }
  }

  Future<void> add({
    required String userId,
    required String name,
    required String type,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();
    final companion = CategoriesCompanion(
      id: Value(id),
      userId: Value(userId),
      name: Value(name),
      type: Value(type),
      createdAt: Value(now),
    );

    await db.upsertCategory(companion);

    if (_shouldSyncRemote(userId)) {
      _pendingUpserts.add(id);
      await remote.upsert(
        RemoteCategoryRecord(
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
    final existingKeys = existing
        .map((c) => '${c.type.toLowerCase()}::${c.name.toLowerCase()}')
        .toSet();

    const defaults = {
      'income': [
        'Salary',
        'Investments',
        'Freelance',
        'Gifts',
      ],
      'expense': [
        'Housing',
        'Food & Groceries',
        'Transportation',
        'Utilities',
        'Entertainment',
        'Healthcare',
      ],
    };

    for (final entry in defaults.entries) {
      for (final name in entry.value) {
        final key = '${entry.key}::${name.toLowerCase()}';
        if (existingKeys.contains(key)) continue;
        await add(userId: userId, name: name, type: entry.key);
      }
    }
  }

  void dispose() {
    _remoteSubscription?.cancel();
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final db = ref.watch(dbProvider);
  final remote = ref.watch(categoryRemoteDataSourceProvider);
  final repo = CategoryRepository(ref, db, remote);
  ref.onDispose(repo.dispose);
  return repo;
});
