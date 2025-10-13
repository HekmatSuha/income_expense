import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_sqflite/drift_sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class Categories extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // 'income' or 'expense'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get type => text()(); // 'income' | 'expense'
  RealColumn get amount => real()();
  TextColumn get note => text().nullable()();
  TextColumn get paymentMethod => text().nullable()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  DateTimeColumn get reminderAt => dateTime().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Categories, Transactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openDB());

  @override
  int get schemaVersion => 1;

  Future<List<Transaction>> allTransactions() => select(transactions).get();

  Stream<List<Transaction>> watchTransactionsForUser(String userId) {
    final query = select(transactions)
      ..where((t) => t.userId.equals(userId))
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]);
    return query.watch();
  }

  Stream<List<Category>> watchCategoriesForUser(String userId) {
    final query = select(categories)
      ..where((c) => c.userId.equals(userId))
      ..orderBy([(c) => OrderingTerm.asc(c.createdAt)]);
    return query.watch();
  }

  Future<List<Category>> allCategoriesForUser(String userId) {
    final query = select(categories)..where((c) => c.userId.equals(userId));
    return query.get();
  }

  Future<void> addTransaction(TransactionsCompanion data) =>
      into(transactions).insert(data);

  Future<void> deleteTransaction(String id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  Future<void> addCategory(CategoriesCompanion data) => into(categories).insert(data);
}

LazyDatabase _openDB() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app.db'));
    final sqflite = SqfliteQueryExecutor(databasePath: file.path);
    return sqflite;
  });
}
