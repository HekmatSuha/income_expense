import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';
import 'tx_repository.dart' show dbProvider;

class CategoryRepository {
  CategoryRepository(this.db);

  final AppDatabase db;

  Stream<List<Category>> watch(String userId) =>
      db.watchCategoriesForUser(userId);

  Future<List<Category>> allForUser(String userId) =>
      db.allCategoriesForUser(userId);

  Future<void> add({
    required String userId,
    required String name,
    required String type,
  }) async {
    await db.addCategory(
      CategoriesCompanion.insert(
        id: const Uuid().v4(),
        userId: userId,
        name: name,
        type: type,
      ),
    );
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
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final db = ref.watch(dbProvider);
  return CategoryRepository(db);
});
