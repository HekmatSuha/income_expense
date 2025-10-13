import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../local/app_database.dart';

final dbProvider = Provider<AppDatabase>((ref) => AppDatabase());

class TxRepository {
  final AppDatabase db;
  TxRepository(this.db);

  Stream<List<Transaction>> watch() => db.watchTransactions();

  Future<void> add({
    required String userId,
    required String type,
    required double amount,
    String? categoryId,
    String? note,
    required DateTime occurredAt,
  }) async {
    await db.addTransaction(TransactionsCompanion.insert(
      id: const Uuid().v4(),
      userId: userId,
      type: type,
      amount: amount,
      categoryId: Value(categoryId),
      note: Value(note),
      occurredAt: occurredAt,
    ));
  }

  Future<void> remove(String id) => db.deleteTransaction(id);
}

final txRepositoryProvider = Provider<TxRepository>((ref) {
  final db = ref.watch(dbProvider);
  return TxRepository(db);
});
