import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';
import '../remote/firebase_service.dart';
import '../remote/transactions_remote_data_source.dart';

final dbProvider = Provider<AppDatabase>((ref) => AppDatabase());

class TxRepository {
  TxRepository(this._ref, this.db, this.remote);

  final Ref _ref;
  final AppDatabase db;
  final TxRemoteDataSource remote;

  StreamSubscription<List<RemoteTransactionRecord>>? _remoteSubscription;
  String? _activeUserId;
  final _pendingUpserts = <String>{};
  final _pendingDeletes = <String>{};

  bool _shouldSyncRemote(String userId) {
    final user = _ref.read(firebaseUserProvider);
    return user != null && user.uid == userId;
  }

  Future<void> triggerSync(String userId) async {
    if (userId.isEmpty) return;
    await _ensureRemoteSubscription(userId);
  }

  Stream<List<Transaction>> watch(String userId) {
    _ensureRemoteSubscription(userId);
    return db.watchTransactionsForUser(userId);
  }

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
    List<RemoteTransactionRecord> records,
  ) async {
    final filtered =
        records.where((record) => !_pendingDeletes.contains(record.id)).toList();
    final remoteIds = filtered.map((record) => record.id).toSet();

    await db.transaction(() async {
      await db.upsertTransactions(
        filtered.map((record) => record.toCompanion()).toList(),
      );
      final keepIds = remoteIds.union(_pendingUpserts);
      await db.purgeTransactions(userId: userId, keepIds: keepIds);
    });

    for (final record in filtered) {
      _pendingUpserts.remove(record.id);
    }

    final snapshotIds = records.map((record) => record.id).toSet();
    _pendingDeletes.removeWhere((id) => !snapshotIds.contains(id));
  }

  Future<void> add({
    required String userId,
    required String type,
    required double amount,
    required String accountId,
    String? categoryId,
    String? note,
    String? paymentMethod,
    bool isRecurring = false,
    DateTime? reminderAt,
    String? recurrenceFrequency,
    DateTime? nextOccurrence,
    bool recurrencePaused = false,
    required DateTime occurredAt,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();
    final companion = TransactionsCompanion(
      id: Value(id),
      userId: Value(userId),
      type: Value(type),
      amount: Value(amount),
      accountId: Value(accountId),
      occurredAt: Value(occurredAt),
      createdAt: Value(now),
      categoryId:
          categoryId == null ? const Value.absent() : Value(categoryId),
      note: note == null ? const Value.absent() : Value(note),
      paymentMethod:
          paymentMethod == null ? const Value.absent() : Value(paymentMethod),
      isRecurring: Value(isRecurring),
      reminderAt:
          reminderAt == null ? const Value.absent() : Value(reminderAt),
      recurrenceFrequency: recurrenceFrequency == null
          ? const Value.absent()
          : Value(recurrenceFrequency),
      nextOccurrence: nextOccurrence == null
          ? const Value.absent()
          : Value(nextOccurrence),
      recurrencePaused: Value(recurrencePaused),
    );

    await db.upsertTransaction(companion);

    if (_shouldSyncRemote(userId)) {
      _pendingUpserts.add(id);
      await remote.upsert(
        RemoteTransactionRecord(
          id: id,
          userId: userId,
          type: type,
          amount: amount,
          categoryId: categoryId,
          accountId: accountId,
          note: note,
          paymentMethod: paymentMethod,
          isRecurring: isRecurring,
          reminderAt: reminderAt,
          recurrenceFrequency: recurrenceFrequency,
          nextOccurrence: nextOccurrence,
          recurrencePaused: recurrencePaused,
          occurredAt: occurredAt,
          createdAt: now,
        ),
      );
    }
  }

  Future<Transaction> updateRecurringTemplate(
    Transaction template, {
    String? recurrenceFrequency,
    DateTime? nextOccurrence,
    bool? recurrencePaused,
    DateTime? reminderAt,
  }) async {
    final companion = TransactionsCompanion(
      recurrenceFrequency: recurrenceFrequency == null
          ? const Value.absent()
          : Value(recurrenceFrequency),
      nextOccurrence: nextOccurrence == null
          ? const Value.absent()
          : Value(nextOccurrence),
      recurrencePaused: recurrencePaused == null
          ? const Value.absent()
          : Value(recurrencePaused),
      reminderAt:
          reminderAt == null ? const Value.absent() : Value(reminderAt),
    );

    await db.updateTransactionFields(template.id, companion);

    final updated = template.copyWith(
      recurrenceFrequency: recurrenceFrequency ?? template.recurrenceFrequency,
      nextOccurrence: nextOccurrence ?? template.nextOccurrence,
      recurrencePaused: recurrencePaused ?? template.recurrencePaused,
      reminderAt: reminderAt ?? template.reminderAt,
    );

    if (_shouldSyncRemote(template.userId)) {
      _pendingUpserts.add(template.id);
      await remote.upsert(RemoteTransactionRecord.fromTransaction(updated));
    }

    return updated;
  }

  Future<void> cancelRecurringTemplate(Transaction template) async {
    final companion = TransactionsCompanion(
      isRecurring: const Value(false),
      recurrenceFrequency: const Value<String?>(null),
      nextOccurrence: const Value<DateTime?>(null),
      recurrencePaused: const Value(false),
      reminderAt: const Value<DateTime?>(null),
    );

    await db.updateTransactionFields(template.id, companion);

    final updated = template.copyWith(
      isRecurring: false,
      recurrenceFrequency: null,
      nextOccurrence: null,
      recurrencePaused: false,
      reminderAt: null,
    );

    if (_shouldSyncRemote(template.userId)) {
      _pendingUpserts.add(template.id);
      await remote.upsert(RemoteTransactionRecord.fromTransaction(updated));
    }
  }

  Future<void> remove({required String userId, required String id}) async {
    await db.deleteTransaction(id);
    _pendingUpserts.remove(id);
    if (_shouldSyncRemote(userId)) {
      _pendingDeletes.add(id);
      await remote.delete(userId, id);
    }
  }

  void dispose() {
    _remoteSubscription?.cancel();
  }
}

final txRepositoryProvider = Provider<TxRepository>((ref) {
  final db = ref.watch(dbProvider);
  final remote = ref.watch(txRemoteDataSourceProvider);
  final repo = TxRepository(ref, db, remote);
  ref.onDispose(repo.dispose);
  return repo;
});
