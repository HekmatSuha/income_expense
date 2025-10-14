import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_database.dart';
import '../../data/local/reminders/reminder_service.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/tx_repository.dart';
import '../auth/auth_state.dart';
import 'recurrence.dart';

class Totals {
  final double income;
  final double expense;
  const Totals({required this.income, required this.expense});
  double get balance => income - expense;
}

class TransactionListItem {
  const TransactionListItem({
    required this.transaction,
    this.category,
    this.account,
  });

  final Transaction transaction;
  final Category? category;
  final Account? account;

  bool get isIncome => transaction.type == 'income';
  bool get isRecurring => transaction.isRecurring;
}

final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(effectiveUserIdProvider);
});

final categoryStreamProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return const Stream<List<Category>>.empty();
  }
  return ref.watch(categoryRepositoryProvider).watch(userId);
});

final accountStreamProvider = StreamProvider.autoDispose<List<Account>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return const Stream<List<Account>>.empty();
  }
  return ref.watch(accountRepositoryProvider).watch(userId);
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
  final accounts = ref.watch(accountStreamProvider);

  if (txs is AsyncLoading<List<Transaction>> ||
      categories is AsyncLoading<List<Category>> ||
      accounts is AsyncLoading<List<Account>>) {
    return const AsyncLoading<List<TransactionListItem>>();
  }
  if (txs is AsyncError<List<Transaction>>) {
    return AsyncError<List<TransactionListItem>>(txs.error, txs.stackTrace);
  }
  if (categories is AsyncError<List<Category>>) {
    return AsyncError<List<TransactionListItem>>(categories.error, categories.stackTrace);
  }
  if (accounts is AsyncError<List<Account>>) {
    return AsyncError<List<TransactionListItem>>(accounts.error, accounts.stackTrace);
  }

  final txList = (txs as AsyncData<List<Transaction>>).value;
  final categoryList = (categories as AsyncData<List<Category>>).value;
  final accountList = (accounts as AsyncData<List<Account>>).value;
  final categoryMap = {for (final c in categoryList) c.id: c};
  final accountMap = {for (final a in accountList) a.id: a};
  final items = txList
      .map((t) => TransactionListItem(
            transaction: t,
            category: t.categoryId == null ? null : categoryMap[t.categoryId!],
            account: t.accountId == null ? null : accountMap[t.accountId!],
          ))
      .toList();
  return AsyncData(items);
});

final recurringItemsProvider = Provider<AsyncValue<List<TransactionListItem>>>((ref) {
  final items = ref.watch(txItemsProvider);
  return items.whenData(
    (list) => list.where((item) => item.transaction.isRecurring).toList(),
  );
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

final ensureDefaultAccountsProvider = FutureProvider.autoDispose<void>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return;
  await ref.watch(accountRepositoryProvider).ensureDefaults(userId);
});

final recurringReminderBootstrapperProvider = Provider<void>((ref) {
  final reminderService = ref.watch(reminderServiceProvider);
  ref.listen<AsyncValue<List<Transaction>>>(
    txStreamProvider,
    (previous, next) {
      next.whenData((transactions) {
        final templates = transactions.where((t) => t.isRecurring).toList();
        unawaited(reminderService.syncRecurringTemplates(templates));
      });
    },
    fireImmediately: true,
  );
});

final recurringAutomationProvider = Provider<void>((ref) {
  var processing = false;
  ref.listen<AsyncValue<List<Transaction>>>(
    txStreamProvider,
    (previous, next) {
      next.whenData((transactions) {
        if (processing) return;
        processing = true;
        unawaited(() async {
          try {
            await _processRecurringTemplates(ref, transactions);
          } finally {
            processing = false;
          }
        }());
      });
    },
    fireImmediately: true,
  );
});

Future<void> _processRecurringTemplates(
  Ref ref,
  List<Transaction> transactions,
) async {
  final repo = ref.read(txRepositoryProvider);
  final now = DateTime.now();
  for (final template in transactions.where((t) => t.isRecurring)) {
    final frequency =
        RecurrenceFrequencyParsing.fromStorage(template.recurrenceFrequency);
    if (frequency == null) continue;
    if (template.recurrencePaused) continue;
    if (template.accountId == null) continue;
    var currentTemplate = template;
    var nextOccurrence = currentTemplate.nextOccurrence;
    var iterations = 0;
    while (nextOccurrence != null && !nextOccurrence.isAfter(now) && iterations < 10) {
      await repo.add(
        userId: currentTemplate.userId,
        type: currentTemplate.type,
        amount: currentTemplate.amount,
        accountId: currentTemplate.accountId!,
        categoryId: currentTemplate.categoryId,
        note: currentTemplate.note,
        paymentMethod: currentTemplate.paymentMethod,
        occurredAt: nextOccurrence,
      );
      final newNext = frequency.addTo(nextOccurrence);
      final newReminder = currentTemplate.reminderAt == null ? null : newNext;
      currentTemplate = await repo.updateRecurringTemplate(
        currentTemplate,
        nextOccurrence: newNext,
        reminderAt: newReminder,
      );
      nextOccurrence = currentTemplate.nextOccurrence;
      iterations += 1;
    }
  }
}
