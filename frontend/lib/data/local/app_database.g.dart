// GENERATED CODE - MANUAL IMPLEMENTATION
// ignore_for_file: type=lint

part of 'app_database.dart';

class Category extends DataClass implements Insertable<Category> {
  const Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final String type;
  final DateTime createdAt;

  @override
  Map<String, Expression<Object?>> toColumns(bool nullToAbsent) {
    return {
      'id': Variable<String>(id),
      'user_id': Variable<String>(userId),
      'name': Variable<String>(name),
      'type': Variable<String>(type),
      'created_at': Variable<DateTime>(createdAt),
    };
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      userId: Value(userId),
      name: Value(name),
      type: Value(type),
      createdAt: Value(createdAt),
    );
  }

  factory Category.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }

  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Category copyWith({
    String? id,
    String? userId,
    String? name,
    String? type,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, name, type, createdAt);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == id &&
          other.userId == userId &&
          other.name == name &&
          other.type == type &&
          other.createdAt == createdAt);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  CategoriesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.createdAt = const Value.absent(),
  });

  CategoriesCompanion.insert({
    required String id,
    required String userId,
    required String name,
    required String type,
    this.createdAt = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        name = Value(name),
        type = Value(type);

  static Insertable<Category> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? name,
    Expression<String>? type,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? name,
    Value<String>? type,
    Value<DateTime>? createdAt,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression<Object?>> toColumns(bool nullToAbsent) {
    final map = <String, Expression<Object?>>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class Transaction extends DataClass implements Insertable<Transaction> {
  const Transaction({
    required this.id,
    required this.userId,
    this.categoryId,
    required this.type,
    required this.amount,
    this.note,
    this.paymentMethod,
    required this.isRecurring,
    this.reminderAt,
    required this.occurredAt,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? categoryId;
  final String type;
  final double amount;
  final String? note;
  final String? paymentMethod;
  final bool isRecurring;
  final DateTime? reminderAt;
  final DateTime occurredAt;
  final DateTime createdAt;

  @override
  Map<String, Expression<Object?>> toColumns(bool nullToAbsent) {
    return {
      'id': Variable<String>(id),
      'user_id': Variable<String>(userId),
      'category_id': Variable<String?>(categoryId),
      'type': Variable<String>(type),
      'amount': Variable<double>(amount),
      'note': Variable<String?>(note),
      'payment_method': Variable<String?>(paymentMethod),
      'is_recurring': Variable<bool>(isRecurring),
      'reminder_at': Variable<DateTime?>(reminderAt),
      'occurred_at': Variable<DateTime>(occurredAt),
      'created_at': Variable<DateTime>(createdAt),
    };
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      userId: Value(userId),
      categoryId:
          categoryId == null && nullToAbsent ? const Value.absent() : Value(categoryId),
      type: Value(type),
      amount: Value(amount),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      paymentMethod: paymentMethod == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentMethod),
      isRecurring: Value(isRecurring),
      reminderAt: reminderAt == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderAt),
      occurredAt: Value(occurredAt),
      createdAt: Value(createdAt),
    );
  }

  factory Transaction.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      type: serializer.fromJson<String>(json['type']),
      amount: serializer.fromJson<double>(json['amount']),
      note: serializer.fromJson<String?>(json['note']),
      paymentMethod: serializer.fromJson<String?>(json['paymentMethod']),
      isRecurring: serializer.fromJson<bool>(json['isRecurring']),
      reminderAt: serializer.fromJson<DateTime?>(json['reminderAt']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }

  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'categoryId': serializer.toJson<String?>(categoryId),
      'type': serializer.toJson<String>(type),
      'amount': serializer.toJson<double>(amount),
      'note': serializer.toJson<String?>(note),
      'paymentMethod': serializer.toJson<String?>(paymentMethod),
      'isRecurring': serializer.toJson<bool>(isRecurring),
      'reminderAt': serializer.toJson<DateTime?>(reminderAt),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Transaction copyWith({
    String? id,
    String? userId,
    Value<String?>? categoryId,
    String? type,
    double? amount,
    Value<String?>? note,
    Value<String?>? paymentMethod,
    bool? isRecurring,
    Value<DateTime?>? reminderAt,
    DateTime? occurredAt,
    DateTime? createdAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId != null
          ? categoryId.present
              ? categoryId.value
              : this.categoryId
          : this.categoryId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      note: note != null
          ? note.present
              ? note.value
              : this.note
          : this.note,
      paymentMethod: paymentMethod != null
          ? paymentMethod.present
              ? paymentMethod.value
              : this.paymentMethod
          : this.paymentMethod,
      isRecurring: isRecurring ?? this.isRecurring,
      reminderAt: reminderAt != null
          ? reminderAt.present
              ? reminderAt.value
              : this.reminderAt
          : this.reminderAt,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('categoryId: $categoryId, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('note: $note, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('isRecurring: $isRecurring, ')
          ..write('reminderAt: $reminderAt, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, categoryId, type, amount, note,
      paymentMethod, isRecurring, reminderAt, occurredAt, createdAt);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == id &&
          other.userId == userId &&
          other.categoryId == categoryId &&
          other.type == type &&
          other.amount == amount &&
          other.note == note &&
          other.paymentMethod == paymentMethod &&
          other.isRecurring == isRecurring &&
          other.reminderAt == reminderAt &&
          other.occurredAt == occurredAt &&
          other.createdAt == createdAt);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  TransactionsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.type = const Value.absent(),
    this.amount = const Value.absent(),
    this.note = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.isRecurring = const Value.absent(),
    this.reminderAt = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });

  TransactionsCompanion.insert({
    required String id,
    required String userId,
    this.categoryId = const Value.absent(),
    required String type,
    required double amount,
    this.note = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.isRecurring = const Value(false),
    this.reminderAt = const Value.absent(),
    required DateTime occurredAt,
    this.createdAt = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        type = Value(type),
        amount = Value(amount),
        occurredAt = Value(occurredAt);

  static Insertable<Transaction> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String?>? categoryId,
    Expression<String>? type,
    Expression<double>? amount,
    Expression<String?>? note,
    Expression<String?>? paymentMethod,
    Expression<bool>? isRecurring,
    Expression<DateTime?>? reminderAt,
    Expression<DateTime>? occurredAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (categoryId != null) 'category_id': categoryId,
      if (type != null) 'type': type,
      if (amount != null) 'amount': amount,
      if (note != null) 'note': note,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (isRecurring != null) 'is_recurring': isRecurring,
      if (reminderAt != null) 'reminder_at': reminderAt,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TransactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String?>? categoryId,
    Value<String>? type,
    Value<double>? amount,
    Value<String?>? note,
    Value<String?>? paymentMethod,
    Value<bool>? isRecurring,
    Value<DateTime?>? reminderAt,
    Value<DateTime>? occurredAt,
    Value<DateTime>? createdAt,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isRecurring: isRecurring ?? this.isRecurring,
      reminderAt: reminderAt ?? this.reminderAt,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression<Object?>> toColumns(bool nullToAbsent) {
    final map = <String, Expression<Object?>>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String?>(categoryId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (note.present) {
      map['note'] = Variable<String?>(note.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String?>(paymentMethod.value);
    }
    if (isRecurring.present) {
      map['is_recurring'] = Variable<bool>(isRecurring.value);
    }
    if (reminderAt.present) {
      map['reminder_at'] = Variable<DateTime?>(reminderAt.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('categoryId: $categoryId, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('note: $note, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('isRecurring: $isRecurring, ')
          ..write('reminderAt: $reminderAt, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  $CategoriesTable(this.attachedDatabase, [String? alias])
      : super(attachedDatabase, alias);

  final GeneratedDatabase attachedDatabase;
  final String? _alias;

  @override
  List<GeneratedColumn> get $columns => [id, userId, name, type, createdAt];

  @override
  String get aliasedName => _alias ?? 'categories';

  @override
  String get actualTableName => 'categories';

  @override
  VerificationContext validateIntegrity(Insertable<Category> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(
          const VerificationMeta('id'), id.isAcceptableOrUnknown(data['id']!, const VerificationMeta('id')));
    } else if (isInserting) {
      context.missing(const VerificationMeta('id'));
    }
    if (data.containsKey('user_id')) {
      context.handle(
          const VerificationMeta('userId'), userId.isAcceptableOrUnknown(data['user_id']!, const VerificationMeta('userId')));
    } else if (isInserting) {
      context.missing(const VerificationMeta('userId'));
    }
    if (data.containsKey('name')) {
      context.handle(
          const VerificationMeta('name'), name.isAcceptableOrUnknown(data['name']!, const VerificationMeta('name')));
    } else if (isInserting) {
      context.missing(const VerificationMeta('name'));
    }
    if (data.containsKey('type')) {
      context.handle(
          const VerificationMeta('type'), type.isAcceptableOrUnknown(data['type']!, const VerificationMeta('type')));
    } else if (isInserting) {
      context.missing(const VerificationMeta('type'));
    }
    if (data.containsKey('created_at')) {
      context.handle(
          const VerificationMeta('createdAt'), createdAt.isAcceptableOrUnknown(data['created_at']!, const VerificationMeta('createdAt')));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};

  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, Transaction> {
  $TransactionsTable(this.attachedDatabase, [String? alias])
      : super(attachedDatabase, alias);

  final GeneratedDatabase attachedDatabase;
  final String? _alias;

  @override
  List<GeneratedColumn> get $columns => [
        id,
        userId,
        categoryId,
        type,
        amount,
        note,
        paymentMethod,
        isRecurring,
        reminderAt,
        occurredAt,
        createdAt
      ];

  @override
  String get aliasedName => _alias ?? 'transactions';

  @override
  String get actualTableName => 'transactions';

  @override
  VerificationContext validateIntegrity(Insertable<Transaction> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(const VerificationMeta('id'),
          id.isAcceptableOrUnknown(data['id']!, const VerificationMeta('id')));
    } else if (isInserting) {
      context.missing(const VerificationMeta('id'));
    }
    if (data.containsKey('user_id')) {
      context.handle(const VerificationMeta('userId'), userId.isAcceptableOrUnknown(
          data['user_id']!, const VerificationMeta('userId')));
    } else if (isInserting) {
      context.missing(const VerificationMeta('userId'));
    }
    if (data.containsKey('category_id')) {
      context.handle(
          const VerificationMeta('categoryId'),
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, const VerificationMeta('categoryId')));
    }
    if (data.containsKey('type')) {
      context.handle(const VerificationMeta('type'),
          type.isAcceptableOrUnknown(data['type']!, const VerificationMeta('type')));
    } else if (isInserting) {
      context.missing(const VerificationMeta('type'));
    }
    if (data.containsKey('amount')) {
      context.handle(const VerificationMeta('amount'),
          amount.isAcceptableOrUnknown(data['amount']!, const VerificationMeta('amount')));
    } else if (isInserting) {
      context.missing(const VerificationMeta('amount'));
    }
    if (data.containsKey('note')) {
      context.handle(const VerificationMeta('note'),
          note.isAcceptableOrUnknown(data['note']!, const VerificationMeta('note')));
    }
    if (data.containsKey('payment_method')) {
      context.handle(
          const VerificationMeta('paymentMethod'),
          paymentMethod.isAcceptableOrUnknown(
              data['payment_method']!, const VerificationMeta('paymentMethod')));
    }
    if (data.containsKey('is_recurring')) {
      context.handle(
          const VerificationMeta('isRecurring'),
          isRecurring.isAcceptableOrUnknown(
              data['is_recurring']!, const VerificationMeta('isRecurring')));
    }
    if (data.containsKey('reminder_at')) {
      context.handle(
          const VerificationMeta('reminderAt'),
          reminderAt.isAcceptableOrUnknown(
              data['reminder_at']!, const VerificationMeta('reminderAt')));
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
          const VerificationMeta('occurredAt'),
          occurredAt.isAcceptableOrUnknown(
              data['occurred_at']!, const VerificationMeta('occurredAt')));
    } else if (isInserting) {
      context.missing(const VerificationMeta('occurredAt'));
    }
    if (data.containsKey('created_at')) {
      context.handle(
          const VerificationMeta('createdAt'),
          createdAt.isAcceptableOrUnknown(
              data['created_at']!, const VerificationMeta('createdAt')));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};

  @override
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      categoryId: attachedDatabase.typeMapping
          .read<String?>(DriftSqlType.string, data['${effectivePrefix}category_id']),
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      note: attachedDatabase.typeMapping
          .read<String?>(DriftSqlType.string, data['${effectivePrefix}note']),
      paymentMethod: attachedDatabase.typeMapping.read<String?>(
          DriftSqlType.string, data['${effectivePrefix}payment_method']),
      isRecurring: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_recurring'])!,
      reminderAt: attachedDatabase.typeMapping.read<DateTime?>(
          DriftSqlType.dateTime, data['${effectivePrefix}reminder_at']),
      occurredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}occurred_at'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);

  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => [categories, transactions];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [categories, transactions];
}
