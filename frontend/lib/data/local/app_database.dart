import 'package:drift/drift.dart';

import 'connection/connection.dart';

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

class Accounts extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // 'cash' | 'bank' | 'card' | etc
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get accountId => text().nullable()();
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

@DriftDatabase(tables: [Categories, Accounts, Transactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.createTable(accounts);
            await migrator.addColumn(transactions, transactions.accountId);
          }
        },
      );

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

  Stream<List<Account>> watchAccountsForUser(String userId) {
    final query = select(accounts)
      ..where((a) => a.userId.equals(userId))
      ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]);
    return query.watch();
  }

  Future<List<Category>> allCategoriesForUser(String userId) {
    final query = select(categories)..where((c) => c.userId.equals(userId));
    return query.get();
  }

  Future<List<Account>> allAccountsForUser(String userId) {
    final query = select(accounts)..where((a) => a.userId.equals(userId));
    return query.get();
  }

  Future<void> addTransaction(TransactionsCompanion data) =>
      into(transactions).insert(data);

  Future<void> deleteTransaction(String id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  Future<void> addCategory(CategoriesCompanion data) => into(categories).insert(data);

  Future<void> updateCategory(
    String id, {
    String? name,
    String? type,
  }) async {
    final companion = CategoriesCompanion(
      name: name == null ? const Value.absent() : Value(name),
      type: type == null ? const Value.absent() : Value(type),
    );
    await (update(categories)..where((c) => c.id.equals(id))).write(companion);
  }

  Future<void> deleteCategory(String id) =>
      (delete(categories)..where((c) => c.id.equals(id))).go();

  Future<int> countTransactionsWithCategory(String categoryId) async {
    final query = select(transactions)..where((t) => t.categoryId.equals(categoryId));
    final results = await query.get();
    return results.length;
  }

  Future<void> reassignTransactionsCategory({
    required String fromCategoryId,
    String? toCategoryId,
  }) async {
    final updateQuery = update(transactions)
      ..where((t) => t.categoryId.equals(fromCategoryId));
    await updateQuery.write(TransactionsCompanion(categoryId: Value(toCategoryId)));
  }

  Future<void> addAccount(AccountsCompanion data) => into(accounts).insert(data);

  Future<void> updateAccount(
    String id, {
    String? name,
    String? type,
  }) async {
    final companion = AccountsCompanion(
      name: name == null ? const Value.absent() : Value(name),
      type: type == null ? const Value.absent() : Value(type),
    );
    await (update(accounts)..where((a) => a.id.equals(id))).write(companion);
  }

  Future<void> deleteAccount(String id) =>
      (delete(accounts)..where((a) => a.id.equals(id))).go();

  Future<int> countTransactionsWithAccount(String accountId) async {
    final query = select(transactions)..where((t) => t.accountId.equals(accountId));
    final results = await query.get();
    return results.length;
  }

  Future<void> reassignTransactionsAccount({
    required String fromAccountId,
    required String toAccountId,
  }) async {
    final updateQuery = update(transactions)
      ..where((t) => t.accountId.equals(fromAccountId));
    await updateQuery.write(TransactionsCompanion(accountId: Value(toAccountId)));
  }
}
