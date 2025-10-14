import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/app_database.dart';
import 'firebase_service.dart';

class RemoteTransactionRecord {
  const RemoteTransactionRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.occurredAt,
    required this.createdAt,
    this.categoryId,
    this.accountId,
    this.note,
    this.paymentMethod,
    this.isRecurring = false,
    this.reminderAt,
    this.recurrenceFrequency,
    this.nextOccurrence,
    this.recurrencePaused = false,
  });

  final String id;
  final String userId;
  final String type;
  final double amount;
  final DateTime occurredAt;
  final DateTime createdAt;
  final String? categoryId;
  final String? accountId;
  final String? note;
  final String? paymentMethod;
  final bool isRecurring;
  final DateTime? reminderAt;
  final String? recurrenceFrequency;
  final DateTime? nextOccurrence;
  final bool recurrencePaused;

  TransactionsCompanion toCompanion() {
    return TransactionsCompanion(
      id: Value(id),
      userId: Value(userId),
      type: Value(type),
      amount: Value(amount),
      occurredAt: Value(occurredAt),
      createdAt: Value(createdAt),
      categoryId:
          categoryId == null ? const Value.absent() : Value(categoryId!),
      accountId: accountId == null ? const Value.absent() : Value(accountId!),
      note: note == null ? const Value.absent() : Value(note!),
      paymentMethod:
          paymentMethod == null ? const Value.absent() : Value(paymentMethod!),
      isRecurring: Value(isRecurring),
      reminderAt:
          reminderAt == null ? const Value.absent() : Value(reminderAt!),
      recurrenceFrequency: recurrenceFrequency == null
          ? const Value.absent()
          : Value(recurrenceFrequency!),
      nextOccurrence: nextOccurrence == null
          ? const Value.absent()
          : Value(nextOccurrence!),
      recurrencePaused: Value(recurrencePaused),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'type': type,
      'amount': amount,
      'categoryId': categoryId,
      'accountId': accountId,
      'note': note,
      'paymentMethod': paymentMethod,
      'isRecurring': isRecurring,
      'reminderAt': reminderAt,
      'recurrenceFrequency': recurrenceFrequency,
      'nextOccurrence': nextOccurrence,
      'recurrencePaused': recurrencePaused,
      'occurredAt': occurredAt,
      'createdAt': createdAt,
    };
  }

  factory RemoteTransactionRecord.fromTransaction(Transaction transaction) {
    return RemoteTransactionRecord(
      id: transaction.id,
      userId: transaction.userId,
      type: transaction.type,
      amount: transaction.amount,
      categoryId: transaction.categoryId,
      accountId: transaction.accountId,
      note: transaction.note,
      paymentMethod: transaction.paymentMethod,
      isRecurring: transaction.isRecurring,
      reminderAt: transaction.reminderAt,
      recurrenceFrequency: transaction.recurrenceFrequency,
      nextOccurrence: transaction.nextOccurrence,
      recurrencePaused: transaction.recurrencePaused,
      occurredAt: transaction.occurredAt,
      createdAt: transaction.createdAt,
    );
  }

  static RemoteTransactionRecord fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final occurredAtRaw = data['occurredAt'];
    final createdAtRaw = data['createdAt'];
    final reminderRaw = data['reminderAt'];
    final nextRaw = data['nextOccurrence'];
    return RemoteTransactionRecord(
      id: snapshot.id,
      userId: data['userId'] as String,
      type: data['type'] as String,
      amount: (data['amount'] as num).toDouble(),
      categoryId: data['categoryId'] as String?,
      accountId: data['accountId'] as String?,
      note: data['note'] as String?,
      paymentMethod: data['paymentMethod'] as String?,
      isRecurring: (data['isRecurring'] as bool?) ?? false,
      reminderAt: reminderRaw is Timestamp
          ? reminderRaw.toDate()
          : (reminderRaw as DateTime?),
      recurrenceFrequency: data['recurrenceFrequency'] as String?,
      nextOccurrence: nextRaw is Timestamp
          ? nextRaw.toDate()
          : (nextRaw as DateTime?),
      recurrencePaused: (data['recurrencePaused'] as bool?) ?? false,
      occurredAt: occurredAtRaw is Timestamp
          ? occurredAtRaw.toDate()
          : (occurredAtRaw as DateTime? ?? DateTime.now().toUtc()),
      createdAt: createdAtRaw is Timestamp
          ? createdAtRaw.toDate()
          : (createdAtRaw as DateTime? ?? DateTime.now().toUtc()),
    );
  }
}

class TxRemoteDataSource {
  TxRemoteDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String userId) {
    return _firestore.collection('users').doc(userId).collection('transactions');
  }

  Stream<List<RemoteTransactionRecord>> watch(String userId) {
    return _collection(userId)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) =>
            snapshot.docs.map(RemoteTransactionRecord.fromSnapshot).toList());
  }

  Future<void> upsert(RemoteTransactionRecord record) {
    return _collection(record.userId)
        .doc(record.id)
        .set(record.toJson(), SetOptions(merge: true));
  }

  Future<void> delete(String userId, String id) {
    return _collection(userId).doc(id).delete();
  }
}

final txRemoteDataSourceProvider = Provider<TxRemoteDataSource>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return TxRemoteDataSource(firestore);
});
