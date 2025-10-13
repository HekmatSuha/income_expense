import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/tx_repository.dart';
import '../../data/remote/supabase_service.dart';

class Totals {
  final double income;
  final double expense;
  const Totals({required this.income, required this.expense});
  double get balance => income - expense;
}

class TransactionListItem {
  const TransactionListItem({required this.transaction, this.category});

  final Transaction transaction;
  final Category? category;

  bool get isIncome => transaction.type == 'income';
  bool get isRecurring => transaction.isRecurring;
}

final currentUserIdProvider = Provider<String?>((ref) {
  final session = ref.watch(sessionProvider);
  return session?.user.id;
});

final categoryStreamProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return const Stream<List<Category>>.empty();
  }
  return ref.watch(categoryRepositoryProvider).watch(userId);
});

final txStreamProvider = StreamProvider.autoDispose<List<Transaction>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return const Stream<List<Transaction>>.empty();
  }
  return ref.watch(txRepositoryProvider).watch(userId);
});

final txItemsProvider = Provider<AsyncValue<List<TransactionListItem>>>((ref) {
  final txs = ref.watch(txStreamProvider);
  final categories = ref.watch(categoryStreamProvider);

  if (txs is AsyncLoading<List<Transaction>> ||
      categories is AsyncLoading<List<Category>>) {
    return const AsyncLoading<List<TransactionListItem>>();
  }
  if (txs is AsyncError<List<Transaction>>) {
    return AsyncError<List<TransactionListItem>>(txs.error, txs.stackTrace);
  }
  if (categories is AsyncError<List<Category>>) {
    return AsyncError<List<TransactionListItem>>(categories.error, categories.stackTrace);
  }

  final txList = (txs as AsyncData<List<Transaction>>).value;
  final categoryList = (categories as AsyncData<List<Category>>).value;
  final categoryMap = {for (final c in categoryList) c.id: c};
  final items = txList
      .map((t) => TransactionListItem(
            transaction: t,
            category: t.categoryId == null ? null : categoryMap[t.categoryId!],
          ))
      .toList();
  return AsyncData(items);
});

final totalsProvider = Provider<Totals>((ref) {
  final txs = ref.watch(txStreamProvider).maybeWhen(data: (d) => d, orElse: () => <Transaction>[]);
  double inc = 0, exp = 0;
  for (final t in txs) {
    if (t.type == 'income') {
      inc += t.amount;
    } else {
      exp += t.amount;
    }
  }
  return Totals(income: inc, expense: exp);
});

class MonthlyBudgetSummary {
  const MonthlyBudgetSummary({required this.limit, required this.spent});

  final double limit;
  final double spent;

  double get remaining => (limit - spent).clamp(0, limit);
  double get progress => limit == 0 ? 0 : (spent / limit).clamp(0, 1);
}

final monthlyBudgetProvider = Provider<MonthlyBudgetSummary>((ref) {
  final txs = ref.watch(txStreamProvider).maybeWhen(data: (d) => d, orElse: () => <Transaction>[]);
  final now = DateTime.now();
  final spent = txs
      .where((t) =>
          t.type == 'expense' &&
          t.occurredAt.year == now.year &&
          t.occurredAt.month == now.month)
      .fold<double>(0, (prev, t) => prev + t.amount);

  // Default monthly limit; in a production app this would be user-configurable.
  const limit = 500000.0;
  return MonthlyBudgetSummary(limit: limit, spent: spent);
});

final ensureDefaultCategoriesProvider = FutureProvider.autoDispose<void>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return;
  await ref.watch(categoryRepositoryProvider).ensureDefaults(userId);
});
