import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';
import 'tx_repository.dart' show dbProvider;

class AccountRepository {
  AccountRepository(this.db);

  final AppDatabase db;

  Stream<List<Account>> watch(String userId) => db.watchAccountsForUser(userId);

  Future<List<Account>> allForUser(String userId) => db.allAccountsForUser(userId);

  Future<void> add({
    required String userId,
    required String name,
    required String type,
  }) async {
    await db.addAccount(
      AccountsCompanion.insert(
        id: const Uuid().v4(),
        userId: userId,
        name: name,
        type: type,
      ),
    );
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
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final db = ref.watch(dbProvider);
  return AccountRepository(db);
});
