import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/local/app_database.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/tx_repository.dart';
import '../../data/remote/firebase_service.dart';
import '../auth/auth_state.dart';
import 'manage_accounts.dart';
import 'manage_categories.dart';
import 'recurrence.dart';
import 'tx_controller.dart';

final homeNavIndexProvider = StateProvider<int>((ref) => 0);

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(ensureDefaultCategoriesProvider);
    ref.watch(ensureDefaultAccountsProvider);
    final userId = ref.watch(currentUserIdProvider);
    final navIndex = ref.watch(homeNavIndexProvider);

    Widget body;
    Widget? floatingActionButton;

    if (navIndex == 0) {
      final txItems = ref.watch(txItemsProvider);
      final categoriesAsync = ref.watch(categoryStreamProvider);
      final accountsAsync = ref.watch(accountStreamProvider);
      final totals = ref.watch(totalsProvider);
      final budget = ref.watch(monthlyBudgetProvider);

      floatingActionButton = FloatingActionButton.extended(
        onPressed: userId == null
            ? null
            : () async {
                final categories = ref.read(categoryStreamProvider).maybeWhen(
                      data: (value) => value,
                      orElse: () => null,
                    ) ??
                    [];
                final accounts = ref.read(accountStreamProvider).maybeWhen(
                      data: (value) => value,
                      orElse: () => null,
                    ) ??
                    [];
                if (categories.isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Add a category before creating transactions.')),
                    );
                  }
                  return;
                }
                if (accounts.isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Add an account before creating transactions.')),
                    );
                  }
                  return;
                }
                await _openAddSheet(context, ref, userId, categories, accounts);
              },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      );

      body = SafeArea(
        child: txItems.when(
          data: (items) => CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _QuickActions(
                        onAddIncome: userId == null
                            ? null
                            : () => _handleQuickAdd(
                                  context,
                                  ref,
                                  userId,
                                  categoriesAsync,
                                  accountsAsync,
                                  'income',
                                ),
                        onAddExpense: userId == null
                            ? null
                            : () => _handleQuickAdd(
                                  context,
                                  ref,
                                  userId,
                                  categoriesAsync,
                                  accountsAsync,
                                  'expense',
                                ),
                        onTransfer: userId == null
                            ? null
                            : () => _showTransferDialog(context, ref, userId),
                      ),
                      const SizedBox(height: 16),
                      _SummaryRow(totals: totals),
                      const SizedBox(height: 16),
                      _MonthlyBudgetCard(summary: budget),
                      const SizedBox(height: 24),
                      Text(
                        'Recent Transactions',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              if (items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('No transactions yet. Tap “Add” to create one.')),
                )
              else
                SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final t = item.transaction;
                    final color = item.isIncome ? Colors.teal : Colors.redAccent;
                    final sign = item.isIncome ? '+' : '-';
                    final categoryLabel = item.category?.name ?? (item.isIncome ? 'Income' : 'Expense');
                    final accountLabel = item.account?.name ?? 'Unassigned';
                    return Dismissible(
                      key: ValueKey(t.id),
                      background: Container(color: Colors.redAccent.withOpacity(0.2)),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) {
                        final uid = userId;
                        if (uid != null) {
                          ref
                              .read(txRepositoryProvider)
                              .remove(userId: uid, id: t.id);
                        }
                      },
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.12),
                          child: Icon(item.isIncome ? Icons.trending_up : Icons.trending_down, color: color),
                        ),
                        title: Text(
                          categoryLabel,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat.yMMMd().format(t.occurredAt)),
                            if ((t.note ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  t.note!,
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Chip(
                                  label: Text(accountLabel),
                                  avatar: const Icon(Icons.account_balance, size: 18),
                                ),
                                if ((t.paymentMethod ?? '').isNotEmpty)
                                  Chip(
                                    label: Text(t.paymentMethod!),
                                    avatar: const Icon(Icons.account_balance_wallet, size: 18),
                                  ),
                                if (item.isRecurring)
                                  const Chip(
                                    label: Text('Recurring'),
                                    avatar: Icon(Icons.autorenew, size: 18),
                                  ),
                                if (t.reminderAt != null)
                                  Chip(
                                    label: Text('Reminder · ${DateFormat.MMMd().format(t.reminderAt!)}'),
                                    avatar: const Icon(Icons.alarm, size: 18),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Text(
                          '$sign${NumberFormat('#,##0.00').format(t.amount)}',
                          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Something went wrong: $e'),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      );
    } else if (navIndex == 1) {
      final recurringAsync = ref.watch(recurringItemsProvider);
      floatingActionButton = userId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final categories = ref.read(categoryStreamProvider).maybeWhen(
                      data: (value) => value,
                      orElse: () => null,
                    ) ??
                    [];
                final accounts = ref.read(accountStreamProvider).maybeWhen(
                      data: (value) => value,
                      orElse: () => null,
                    ) ??
                    [];
                if (categories.isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Add a category before creating recurring transactions.')),
                    );
                  }
                  return;
                }
                if (accounts.isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Add an account before creating recurring transactions.')),
                    );
                  }
                  return;
                }
                await _openAddSheet(
                  context,
                  ref,
                  userId,
                  categories,
                  accounts,
                  forceRecurring: true,
                );
              },
              icon: const Icon(Icons.autorenew),
              label: const Text('Add recurring'),
            );

      body = SafeArea(
        child: _RecurringTab(
          itemsAsync: recurringAsync,
          onEdit: (item) => _openRecurringEditor(context, ref, item),
          onTogglePause: (item) => _toggleRecurringPause(context, ref, item),
          onCancel: (item) => _cancelRecurringSchedule(context, ref, item),
        ),
      );
    } else {
      final accountsAsync = ref.watch(accountStreamProvider);
      floatingActionButton = userId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddAccountDialog(context, ref, userId),
              icon: const Icon(Icons.add),
              label: const Text('Add account'),
            );

      body = SafeArea(
        child: _AccountsTab(
          accountsAsync: accountsAsync,
        ),
      );
    }


    String appBarTitle;
    if (navIndex == 0) {
      appBarTitle = 'Income & Expense';
    } else if (navIndex == 1) {
      appBarTitle = 'Recurring schedules';
    } else {
      appBarTitle = 'Accounts';
    }


    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        actions: [
          if (userId != null)
            PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'manage_categories':
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CategoryManagementPage(),
                      ),
                    );
                    ref.invalidate(categoryStreamProvider);
                    ref.invalidate(txStreamProvider);
                    break;
                  case 'manage_accounts':
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AccountManagementPage(),
                      ),
                    );
                    ref.invalidate(accountStreamProvider);
                    ref.invalidate(txStreamProvider);
                    break;
                  case 'settings':
                    if (context.mounted) {
                      context.push('/settings');
                    }
                    break;
                  case 'sign_out':
                    final auth = ref.read(firebaseAuthProvider);
                    final wasGuest = ref.read(guestModeProvider);
                    ref.read(guestModeProvider.notifier).state = false;
                    ref.read(homeNavIndexProvider.notifier).state = 0;
                    if (!wasGuest) {
                      await auth.signOut();
                    }
                    if (context.mounted) {
                      context.go('/login');
                    }
                    break;
                }
              },
              itemBuilder: (context) {
                return [
                  const PopupMenuItem(
                    value: 'manage_categories',
                    child: Text('Manage categories'),
                  ),
                  const PopupMenuItem(
                    value: 'manage_accounts',
                    child: Text('Manage accounts'),
                  ),
                  if (!guestMode)
                    const PopupMenuItem(
                      value: 'settings',
                      child: Text('Account settings'),
                    ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'sign_out',
                    child: Text(guestMode ? 'Exit guest mode' : 'Sign out'),
                  ),
                ];
              },
            ),
        ],
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (index) {
          ref.read(homeNavIndexProvider.notifier).state = index;
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.autorenew_outlined),
            selectedIcon: Icon(Icons.autorenew),
            label: 'Recurring',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Accounts',
          ),
        ],
      ),
    );
  }

  Future<void> _handleQuickAdd(
    BuildContext context,
    WidgetRef ref,
    String userId,
    AsyncValue<List<Category>> categoriesAsync,
    AsyncValue<List<Account>> accountsAsync,
    String type,
  ) async {
    final categories = categoriesAsync.maybeWhen(data: (value) => value, orElse: () => <Category>[]);
    final filtered = categories.where((c) => c.type == type).toList();
    if (filtered.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Add a $type category first.')),
        );
      }
      return;
    }
    final accounts = accountsAsync.maybeWhen(data: (value) => value, orElse: () => <Account>[]);
    if (accounts.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add an account before creating transactions.')),
        );
      }
      return;
    }
    await _openAddSheet(context, ref, userId, categories, accounts, initialType: type);
  }

  Future<void> _openAddSheet(
    BuildContext context,
    WidgetRef ref,
    String userId,
    List<Category> categories,
    List<Account> accounts, {
    String initialType = 'expense',
    bool forceRecurring = false,
    RecurrenceFrequency initialFrequency = RecurrenceFrequency.monthly,
  }) async {
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String type = initialType;
    String paymentMethod = 'Cash';
    String? categoryId =
        categories.where((c) => c.type == type).map((c) => c.id).firstOrNull;
    var availableAccounts = List<Account>.from(accounts);
    String? accountId = availableAccounts.firstOrNull?.id;
    bool isRecurring = forceRecurring;
    RecurrenceFrequency frequency = initialFrequency;
    DateTime date = DateTime.now();
    DateTime? nextOccurrence = isRecurring ? frequency.addTo(date) : null;
    DateTime? reminderAt = nextOccurrence;
    bool reminderManuallySet = false;
    String? recurrenceError;

    DateTime computeNext(DateTime base, RecurrenceFrequency freq) {
      return freq.addTo(base);
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (ctx, setState) {
              final filtered = categories.where((c) => c.type == type).toList();
              if (categoryId == null && filtered.isNotEmpty) {
                categoryId = filtered.first.id;
              }
              accountId ??= availableAccounts.firstOrNull?.id;
              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Add ${type == 'income' ? 'Income' : 'Expense'}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'income', label: Text('Income'), icon: Icon(Icons.trending_up)),
                          ButtonSegment(value: 'expense', label: Text('Expense'), icon: Icon(Icons.trending_down)),
                        ],
                        selected: {type},
                        onSelectionChanged: (selection) {
                          setState(() {
                            type = selection.first;
                            final filteredCats =
                                categories.where((c) => c.type == type).toList();
                            categoryId =
                                filteredCats.isEmpty ? null : filteredCats.first.id;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: amountCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          prefixIcon: Icon(Icons.payments),
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          final amount = double.tryParse(value ?? '');
                          if (amount == null || amount <= 0) {
                            return 'Enter a valid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: categoryId,
                        items: filtered
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category),
                        ),
                        onChanged: (value) => setState(() => categoryId = value),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Select a category';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: accountId,
                        items: availableAccounts
                            .map(
                              (a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(a.name),
                              ),
                            )
                            .toList(),
                        decoration: const InputDecoration(
                          labelText: 'Account',
                          prefixIcon: Icon(Icons.account_balance),
                        ),
                        onChanged: (value) => setState(() => accountId = value),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Select an account';
                          }
                          return null;
                        },
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () async {
                            await _showAddAccountDialog(context, ref, userId);
                            final latest =
                                await ref.read(accountRepositoryProvider).allForUser(userId);
                            if (!ctx.mounted) return;
                            final previousLength = availableAccounts.length;
                            setState(() {
                              availableAccounts = latest;
                              final selectedExists =
                                  latest.any((a) => a.id == accountId);
                              if (latest.length > previousLength) {
                                accountId = latest.last.id;
                              } else if (!selectedExists) {
                                accountId = latest.firstOrNull?.id;
                              }
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add account'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: paymentMethod,
                        items: const [
                          DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                          DropdownMenuItem(value: 'Card', child: Text('Card')),
                          DropdownMenuItem(value: 'Transfer', child: Text('Transfer')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Payment method',
                          prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                        ),
                        onChanged: (value) =>
                            setState(() => paymentMethod = value ?? 'Cash'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: noteCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          prefixIcon: Icon(Icons.note_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event),
                        title: Text(DateFormat.yMMMd().format(date)),
                        subtitle: const Text('Transaction date'),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: date,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              date = picked;
                              if (isRecurring) {
                                final candidate = computeNext(date, frequency);
                                if (nextOccurrence == null ||
                                    !nextOccurrence!.isAfter(date)) {
                                  nextOccurrence = candidate;
                                  if (!reminderManuallySet) {
                                    reminderAt = candidate;
                                  }
                                }
                              }
                            });
                          }
                        },
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Recurring transaction'),
                        value: isRecurring,
                        onChanged: (value) {
                          setState(() {
                            isRecurring = value;
                            if (isRecurring) {
                              final candidate = computeNext(date, frequency);
                              nextOccurrence = candidate;
                              recurrenceError = null;
                              if (!reminderManuallySet) {
                                reminderAt = candidate;
                              }
                            } else {
                              nextOccurrence = null;
                              reminderAt = null;
                              reminderManuallySet = false;
                              recurrenceError = null;
                            }
                          });
                        },
                      ),
                      if (isRecurring) ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<RecurrenceFrequency>(
                          value: frequency,
                          decoration: const InputDecoration(
                            labelText: 'Frequency',
                            prefixIcon: Icon(Icons.autorenew),
                          ),
                          items: RecurrenceFrequency.values
                              .map(
                                (freq) => DropdownMenuItem(
                                  value: freq,
                                  child: Text(freq.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              frequency = value;
                              final candidate = computeNext(date, frequency);
                              nextOccurrence = candidate;
                              recurrenceError = null;
                              if (!reminderManuallySet) {
                                reminderAt = candidate;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event_repeat),
                          title: Text(
                            nextOccurrence == null
                                ? 'Pick next occurrence'
                                : RecurrenceFrequencyParsing.formatDate(nextOccurrence!),
                          ),
                          subtitle: const Text('Next occurrence'),
                          trailing: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                nextOccurrence = null;
                                recurrenceError = 'Select the next occurrence';
                              });
                            },
                          ),
                          onTap: () async {
                            final base = nextOccurrence ?? computeNext(date, frequency);
                            final pickedDate = await showDatePicker(
                              context: ctx,
                              initialDate: base,
                              firstDate: date,
                              lastDate: DateTime.now().add(const Duration(days: 730)),
                            );
                            if (pickedDate == null) return;
                            final pickedTime = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.fromDateTime(base),
                            );
                            if (pickedTime == null) return;
                            final candidate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                            setState(() {
                              final adjusted = candidate.isAfter(date)
                                  ? candidate
                                  : computeNext(date, frequency);
                              nextOccurrence = adjusted;
                              recurrenceError = null;
                              if (!reminderManuallySet) {
                                reminderAt = adjusted;
                              }
                            });
                          },
                        ),
                        if (recurrenceError != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              recurrenceError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.alarm),
                          title: Text(
                            reminderAt == null
                                ? 'Add a reminder'
                                : 'Reminder ${RecurrenceFrequencyParsing.formatDate(reminderAt!)}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() {
                              reminderAt = null;
                              reminderManuallySet = false;
                            }),
                          ),
                          onTap: () async {
                            final initial = reminderAt ?? nextOccurrence ?? date;
                            final pickedDate = await showDatePicker(
                              context: ctx,
                              initialDate: initial,
                              firstDate: DateTime.now().subtract(const Duration(days: 1)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (pickedDate == null) return;
                            final pickedTime = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.fromDateTime(initial),
                            );
                            if (pickedTime == null) return;
                            final reminder = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                            setState(() {
                              reminderAt = reminder;
                              reminderManuallySet = true;
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            if (isRecurring && nextOccurrence == null) {
                              setState(() {
                                recurrenceError = 'Select the next occurrence';
                              });
                              return;
                            }
                            final amount = double.parse(amountCtrl.text);
                            await ref.read(txRepositoryProvider).add(
                                  userId: userId,
                                  type: type,
                                  amount: amount,
                                  accountId: accountId!,
                                  categoryId: categoryId,
                                  note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
                                  paymentMethod: paymentMethod,
                                  isRecurring: isRecurring,
                                  reminderAt: isRecurring ? reminderAt : null,
                                  recurrenceFrequency:
                                      isRecurring ? frequency.storageValue : null,
                                  nextOccurrence:
                                      isRecurring ? nextOccurrence : null,
                                  occurredAt: date,
                                );
                            if (context.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('Save transaction'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    amountCtrl.dispose();
    noteCtrl.dispose();
  }

  Future<void> _openRecurringEditor(
    BuildContext context,
    WidgetRef ref,
    TransactionListItem item,
  ) async {
    final transaction = item.transaction;
    var frequency = RecurrenceFrequencyParsing.fromStorage(
          transaction.recurrenceFrequency,
        ) ??
        RecurrenceFrequency.monthly;
    DateTime? nextOccurrence =
        transaction.nextOccurrence ?? frequency.addTo(DateTime.now());
    DateTime? reminderAt = transaction.reminderAt ?? nextOccurrence;
    String? recurrenceError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (ctx, setState) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit schedule',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      item.category?.name ??
                          (transaction.type == 'income' ? 'Income' : 'Expense'),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<RecurrenceFrequency>(
                      value: frequency,
                      decoration: const InputDecoration(
                        labelText: 'Frequency',
                        prefixIcon: Icon(Icons.autorenew),
                      ),
                      items: RecurrenceFrequency.values
                          .map(
                            (freq) => DropdownMenuItem(
                              value: freq,
                              child: Text(freq.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          frequency = value;
                          if (nextOccurrence != null) {
                            nextOccurrence =
                                frequency.addTo(nextOccurrence ?? DateTime.now());
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_repeat),
                      title: Text(
                        nextOccurrence == null
                            ? 'Pick next occurrence'
                            : RecurrenceFrequencyParsing.formatDate(nextOccurrence!),
                      ),
                      subtitle: const Text('Next occurrence'),
                      trailing: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            nextOccurrence = null;
                            recurrenceError = 'Select the next occurrence';
                          });
                        },
                      ),
                      onTap: () async {
                        final base = nextOccurrence ?? DateTime.now();
                        final pickedDate = await showDatePicker(
                          context: ctx,
                          initialDate: base,
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 730)),
                        );
                        if (pickedDate == null) return;
                        final pickedTime = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(base),
                        );
                        if (pickedTime == null) return;
                        final scheduled = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                        setState(() {
                          nextOccurrence = scheduled;
                          recurrenceError = null;
                        });
                      },
                    ),
                    if (recurrenceError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          recurrenceError!,
                          style:
                              TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.alarm),
                      title: Text(
                        reminderAt == null
                            ? 'Add a reminder'
                            : 'Reminder ${RecurrenceFrequencyParsing.formatDate(reminderAt!)}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => reminderAt = null),
                      ),
                      onTap: () async {
                        final base = reminderAt ?? nextOccurrence ?? DateTime.now();
                        final pickedDate = await showDatePicker(
                          context: ctx,
                          initialDate: base,
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (pickedDate == null) return;
                        final pickedTime = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(base),
                        );
                        if (pickedTime == null) return;
                        setState(() {
                          reminderAt = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          if (nextOccurrence == null) {
                            setState(() {
                              recurrenceError = 'Select the next occurrence';
                            });
                            return;
                          }
                          await ref.read(txRepositoryProvider).updateRecurringTemplate(
                                transaction,
                                recurrenceFrequency: frequency.storageValue,
                                nextOccurrence: nextOccurrence,
                                reminderAt: reminderAt,
                              );
                          if (!context.mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Recurring schedule updated'),
                            ),
                          );
                        },
                        child: const Text('Save changes'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _toggleRecurringPause(
    BuildContext context,
    WidgetRef ref,
    TransactionListItem item,
  ) async {
    final paused = !item.transaction.recurrencePaused;
    await ref.read(txRepositoryProvider).updateRecurringTemplate(
          item.transaction,
          recurrencePaused: paused,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(paused
            ? 'Recurring schedule paused'
            : 'Recurring schedule resumed'),
      ),
    );
  }

  Future<void> _cancelRecurringSchedule(
    BuildContext context,
    WidgetRef ref,
    TransactionListItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel recurring schedule'),
          content: const Text(
              'This will stop future occurrences but keep existing transactions.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cancel schedule'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await ref
        .read(txRepositoryProvider)
        .cancelRecurringTemplate(item.transaction);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recurring schedule cancelled')),
    );
  }

  Future<void> _showTransferDialog(BuildContext context, WidgetRef ref, String userId) async {
    final accounts = await ref.read(accountRepositoryProvider).allForUser(userId);
    if (accounts.length < 2) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least two accounts to record a transfer.')),
        );
      }
      return;
    }

    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    var fromId = accounts.first.id;
    var toId = accounts.firstWhere((a) => a.id != fromId).id;
    DateTime occurredAt = DateTime.now();
    String? errorMessage;
    var isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            final destinationAccounts = accounts.where((a) => a.id != fromId).toList();
            if (!destinationAccounts.any((a) => a.id == toId)) {
              toId = destinationAccounts.first.id;
            }
            return AlertDialog(
              title: const Text('Transfer between accounts'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: fromId,
                        decoration: const InputDecoration(
                          labelText: 'From account',
                          prefixIcon: Icon(Icons.arrow_upward),
                        ),
                        items: accounts
                            .map(
                              (a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(a.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            fromId = value;
                            final destinations = accounts.where((a) => a.id != fromId).toList();
                            if (!destinations.any((a) => a.id == toId)) {
                              toId = destinations.first.id;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: toId,
                        decoration: const InputDecoration(
                          labelText: 'To account',
                          prefixIcon: Icon(Icons.arrow_downward),
                        ),
                        items: destinationAccounts
                            .map(
                              (a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(a.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => toId = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: amountCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          final amount = double.tryParse(value ?? '');
                          if (amount == null || amount <= 0) {
                            return 'Enter a valid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: noteCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Note (optional)',
                          prefixIcon: Icon(Icons.note_alt_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event),
                        title: Text(DateFormat.yMMMd().format(occurredAt)),
                        subtitle: const Text('Transfer date'),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: occurredAt,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => occurredAt = picked);
                          }
                        },
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            errorMessage!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }
                          if (fromId == toId) {
                            setState(() {
                              errorMessage = 'Choose two different accounts.';
                            });
                            return;
                          }
                          setState(() {
                            isSaving = true;
                            errorMessage = null;
                          });
                          final fromAccount = accounts.firstWhere((a) => a.id == fromId);
                          final toAccount = accounts.firstWhere((a) => a.id == toId);
                          final amount = double.parse(amountCtrl.text);
                          final note = noteCtrl.text.trim();
                          final outNote = note.isEmpty
                              ? 'Transfer to ${toAccount.name}'
                              : 'Transfer to ${toAccount.name} · $note';
                          final inNote = note.isEmpty
                              ? 'Transfer from ${fromAccount.name}'
                              : 'Transfer from ${fromAccount.name} · $note';
                          try {
                            await ref.read(txRepositoryProvider).add(
                                  userId: userId,
                                  type: 'expense',
                                  amount: amount,
                                  accountId: fromId,
                                  categoryId: null,
                                  note: outNote,
                                  paymentMethod: 'Transfer',
                                  isRecurring: false,
                                  reminderAt: null,
                                  occurredAt: occurredAt,
                                );
                            await ref.read(txRepositoryProvider).add(
                                  userId: userId,
                                  type: 'income',
                                  amount: amount,
                                  accountId: toId,
                                  categoryId: null,
                                  note: inNote,
                                  paymentMethod: 'Transfer',
                                  isRecurring: false,
                                  reminderAt: null,
                                  occurredAt: occurredAt,
                                );
                            Navigator.of(dialogContext).pop();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Transfer recorded.')),
                            );
                          } catch (e) {
                            setState(() {
                              isSaving = false;
                              errorMessage = 'Could not save the transfer. Please try again.';
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Record transfer'),
                ),
              ],
            );
          },
        );
      },
    );

    amountCtrl.dispose();
    noteCtrl.dispose();
  }

  Future<void> _showAddAccountDialog(BuildContext context, WidgetRef ref, String userId) async {
    const accountTypes = [
      ('Cash', 'cash'),
      ('Bank account', 'bank'),
      ('Credit card', 'credit'),
      ('Investment', 'investment'),
      ('Other', 'other'),
    ];

    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    String type = accountTypes.first.$2;
    String? errorMessage;
    var isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('Add account'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Account name',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter an account name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: type,
                      items: accountTypes
                          .map(
                            (option) => DropdownMenuItem(
                              value: option.$2,
                              child: Text(option.$1),
                            ),
                          )
                          .toList(),
                      decoration: const InputDecoration(
                        labelText: 'Account type',
                        prefixIcon: Icon(Icons.layers_outlined),
                      ),
                      onChanged: (value) => setState(() => type = value ?? accountTypes.first.$2),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorMessage!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }
                          setState(() {
                            isSaving = true;
                            errorMessage = null;
                          });
                          try {
                            await ref.read(accountRepositoryProvider).add(
                                  userId: userId,
                                  name: nameCtrl.text.trim(),
                                  type: type,
                                );
                            Navigator.of(dialogContext).pop();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Account added')),
                            );
                          } catch (e) {
                            setState(() {
                              isSaving = false;
                              errorMessage = 'Could not add account. Please try again.';
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onAddIncome,
    required this.onAddExpense,
    required this.onTransfer,
  });

  final VoidCallback? onAddIncome;
  final VoidCallback? onAddExpense;
  final VoidCallback? onTransfer;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ActionChip(
          label: 'Add income',
          icon: Icons.trending_up,
          color: Colors.teal,
          onTap: onAddIncome,
        ),
        _ActionChip(
          label: 'Add expense',
          icon: Icons.trending_down,
          color: Colors.redAccent,
          onTap: onAddExpense,
        ),
        _ActionChip(
          label: 'Transfer funds',
          icon: Icons.swap_horiz,
          color: Colors.indigo,
          onTap: onTransfer,
        ),
      ],
    );
  }
}

class _RecurringTab extends StatelessWidget {
  const _RecurringTab({
    required this.itemsAsync,
    required this.onEdit,
    required this.onTogglePause,
    required this.onCancel,
  });

  final AsyncValue<List<TransactionListItem>> itemsAsync;
  final void Function(TransactionListItem item) onEdit;
  final void Function(TransactionListItem item) onTogglePause;
  final void Function(TransactionListItem item) onCancel;

  @override
  Widget build(BuildContext context) {
    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyRecurringState();
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            final transaction = item.transaction;
            final frequency = RecurrenceFrequencyParsing.fromStorage(
                  transaction.recurrenceFrequency,
                ) ??
                RecurrenceFrequency.monthly;
            final frequencyLabel = frequency.label;
            final nextLabel = transaction.nextOccurrence == null
                ? 'Not scheduled'
                : RecurrenceFrequencyParsing.formatDate(
                    transaction.nextOccurrence!,
                  );
            final reminderLabel = transaction.reminderAt == null
                ? null
                : 'Reminder ${RecurrenceFrequencyParsing.formatDate(transaction.reminderAt!)}';
            final accountLabel = item.account?.name ?? 'Unassigned';
            final typeColor =
                transaction.type == 'income' ? Colors.teal : Colors.redAccent;
            return Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: typeColor.withOpacity(0.12),
                      child: Icon(
                        transaction.type == 'income'
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: typeColor,
                      ),
                    ),
                    title: Text(
                      item.category?.name ??
                          (transaction.type == 'income' ? 'Income' : 'Expense'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$frequencyLabel · Next $nextLabel'),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Chip(
                              label: Text(accountLabel),
                              avatar:
                                  const Icon(Icons.account_balance, size: 18),
                            ),
                            if (transaction.recurrencePaused)
                              const Chip(
                                label: Text('Paused'),
                                avatar: Icon(Icons.pause, size: 18),
                              ),
                            if (reminderLabel != null)
                              Chip(
                                label: Text(reminderLabel),
                                avatar: const Icon(Icons.alarm, size: 18),
                              ),
                          ],
                        ),
                        if ((transaction.note ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(transaction.note!),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => onEdit(item),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => onTogglePause(item),
                          icon: Icon(transaction.recurrencePaused
                              ? Icons.play_arrow
                              : Icons.pause),
                          label: Text(
                              transaction.recurrencePaused ? 'Resume' : 'Pause'),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: () => onCancel(item),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load recurring schedules: $error'),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyRecurringState extends StatelessWidget {
  const _EmptyRecurringState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.autorenew,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No recurring schedules yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a recurring transaction to see it here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountsTab extends StatelessWidget {
  const _AccountsTab({required this.accountsAsync});

  final AsyncValue<List<Account>> accountsAsync;

  @override
  Widget build(BuildContext context) {
    return accountsAsync.when(
      data: (accounts) {
        if (accounts.isEmpty) {
          return const _EmptyAccountsState();
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: accounts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final account = accounts[index];
            final visuals = _AccountVisuals.forType(account.type, Theme.of(context).colorScheme);
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: visuals.color.withOpacity(0.12),
                  child: Icon(visuals.icon, color: visuals.color),
                ),
                title: Text(
                  account.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('${_AccountVisuals.labelFor(account.type)} · Added ${DateFormat.yMMMd().format(account.createdAt)}'),
              ),
            );
          },
        );
      },
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load accounts: $error'),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyAccountsState extends StatelessWidget {
  const _EmptyAccountsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'No accounts yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add an account to start tracking balances and transfers.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountVisuals {
  const _AccountVisuals({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  static _AccountVisuals forType(String type, ColorScheme scheme) {
    switch (type) {
      case 'cash':
        return _AccountVisuals(icon: Icons.payments_outlined, color: scheme.primary);
      case 'bank':
        return _AccountVisuals(icon: Icons.account_balance, color: scheme.secondary);
      case 'credit':
        return _AccountVisuals(icon: Icons.credit_card, color: scheme.error);
      case 'investment':
        return _AccountVisuals(icon: Icons.trending_up, color: scheme.tertiary);
      default:
        return _AccountVisuals(icon: Icons.account_balance_wallet, color: scheme.primary);
    }
  }

  static String labelFor(String type) {
    switch (type) {
      case 'cash':
        return 'Cash';
      case 'bank':
        return 'Bank account';
      case 'credit':
        return 'Credit card';
      case 'investment':
        return 'Investment';
      default:
        return 'Other';
    }
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.totals});

  final Totals totals;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Income',
            value: totals.income,
            icon: Icons.south_west,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            title: 'Expense',
            value: totals.expense,
            icon: Icons.north_east,
            color: colorScheme.error,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            title: 'Balance',
            value: totals.balance,
            icon: Icons.account_balance_wallet,
            color: colorScheme.secondary,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final double value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(
            NumberFormat.simpleCurrency(name: 'KZT').format(value),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _MonthlyBudgetCard extends StatelessWidget {
  const _MonthlyBudgetCard({required this.summary});

  final MonthlyBudgetSummary summary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monthly budget', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: summary.progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(12),
            backgroundColor: colorScheme.onPrimaryContainer.withOpacity(0.12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Spent: ${NumberFormat.compactCurrency(symbol: '₸').format(summary.spent)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Text(
                'Limit: ${NumberFormat.compactCurrency(symbol: '₸').format(summary.limit)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Remaining ${NumberFormat.compactCurrency(symbol: '₸').format(summary.remaining)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) return null;
    return elementAt(0);
  }
}
