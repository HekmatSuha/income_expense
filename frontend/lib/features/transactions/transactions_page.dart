import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/local/app_database.dart';
import '../../data/remote/firebase_service.dart';
import '../../data/repositories/tx_repository.dart';
import '../auth/auth_state.dart';
import 'tx_controller.dart';

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(ensureDefaultCategoriesProvider);
    final txItems = ref.watch(txItemsProvider);
    final categoriesAsync = ref.watch(categoryStreamProvider);
    final totals = ref.watch(totalsProvider);
    final budget = ref.watch(monthlyBudgetProvider);
    final userId = ref.watch(currentUserIdProvider);

    final guestMode = ref.watch(guestModeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: userId == null
            ? null
            : () async {
                final categories = ref.read(categoryStreamProvider).maybeWhen(
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
                await _openAddSheet(context, ref, userId, categories);
              },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: SafeArea(
        child: txItems.when(
          data: (items) => CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _DashboardHeader(
                  totals: totals,
                  budget: budget,
                  guestMode: guestMode,
                  onToggleGuest: () => ref.read(guestModeProvider.notifier).state = false,
                  onSignOut: () => ref.read(firebaseAuthProvider).signOut(),
                  onAddIncome: userId == null
                      ? null
                      : () => _handleQuickAdd(context, ref, userId, categoriesAsync, 'income'),
                  onAddExpense: userId == null
                      ? null
                      : () => _handleQuickAdd(context, ref, userId, categoriesAsync, 'expense'),
                ),
              ),
              if (guestMode)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _GuestModeBanner(),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _RecentTransactionsCard(
                    items: items,
                    onDismiss: (id) => ref.read(txRepositoryProvider).remove(id),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _MonthlyBudgetCard(summary: budget),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
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
      ),
    );
  }

  Future<void> _handleQuickAdd(
    BuildContext context,
    WidgetRef ref,
    String userId,
    AsyncValue<List<Category>> categoriesAsync,
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
    await _openAddSheet(context, ref, userId, categories, initialType: type);
  }

  Future<void> _openAddSheet(
    BuildContext context,
    WidgetRef ref,
    String userId,
    List<Category> categories,
    {String initialType = 'expense'}
  ) async {
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String type = initialType;
    String paymentMethod = 'Cash';
    String? categoryId = categories.where((c) => c.type == type).map((c) => c.id).firstOrNull;
    bool isRecurring = false;
    DateTime date = DateTime.now();
    DateTime? reminderAt;

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
                            final filteredCats = categories.where((c) => c.type == type).toList();
                            categoryId = filteredCats.isEmpty ? null : filteredCats.first.id;
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
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                        onChanged: (value) => setState(() => paymentMethod = value ?? 'Cash'),
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
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(DateFormat.yMMMd().format(date)),
                              subtitle: const Text('Transaction date'),
                              leading: const Icon(Icons.event),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: date,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() => date = picked);
                                }
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_calendar),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: date,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() => date = picked);
                              }
                            },
                          ),
                        ],
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Recurring transaction'),
                        value: isRecurring,
                        onChanged: (value) => setState(() => isRecurring = value),
                      ),
                      if (isRecurring) ...[
                        const SizedBox(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.alarm),
                          title: Text(
                            reminderAt == null
                                ? 'Add a reminder'
                                : 'Reminder ${DateFormat.yMMMd().format(reminderAt!)}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => reminderAt = null),
                          ),
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: ctx,
                              initialDate: reminderAt ?? date,
                              firstDate: DateTime.now().subtract(const Duration(days: 1)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (pickedDate == null) return;
                            final pickedTime = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.now(),
                            );
                            if (pickedTime == null) return;
                            final reminder = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                            setState(() => reminderAt = reminder);
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final amount = double.parse(amountCtrl.text);
                            await ref.read(txRepositoryProvider).add(
                                  userId: userId,
                                  type: type,
                                  amount: amount,
                                  categoryId: categoryId,
                                  note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
                                  paymentMethod: paymentMethod,
                                  isRecurring: isRecurring,
                                  reminderAt: reminderAt,
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
}

class _GuestModeBanner extends StatelessWidget {
  const _GuestModeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You are exploring the app without signing in. '
              'Your data stays on this device until you create an account.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.totals,
    required this.budget,
    required this.guestMode,
    required this.onToggleGuest,
    required this.onSignOut,
    required this.onAddIncome,
    required this.onAddExpense,
  });

  final Totals totals;
  final MonthlyBudgetSummary budget;
  final bool guestMode;
  final VoidCallback onToggleGuest;
  final VoidCallback onSignOut;
  final VoidCallback? onAddIncome;
  final VoidCallback? onAddExpense;

  @override
  Widget build(BuildContext context) {

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);
    final dateRange = '${DateFormat('dd MMM yyyy').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0057E7), Color(0xFF00A1FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),

        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.menu, color: Colors.white),
              ),
              const Spacer(),
              IconButton(
                tooltip: guestMode ? 'Return to login' : 'Sign out',
                onPressed: guestMode ? onToggleGuest : onSignOut,
                icon: Icon(guestMode ? Icons.login : Icons.logout, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Income Expense',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Track your money smartly',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          _QuickActionGrid(
            onAddIncome: onAddIncome,
            onAddExpense: onAddExpense,
          ),
          const SizedBox(height: 24),
          _BalanceOverviewCard(
            totals: totals,
            budget: budget,
            dateRange: dateRange,
          ),
        ],
      ),
    );
  }
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({
    required this.onAddIncome,
    required this.onAddExpense,
  });

  final VoidCallback? onAddIncome;
  final VoidCallback? onAddExpense;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final itemWidth = (width - 16) / 2;
        final actions = [
          (
            label: 'Add Income',
            icon: Icons.trending_up,
            color: const Color(0xFF2ECC71),
            onTap: onAddIncome,
          ),
          (
            label: 'Add Expense',
            icon: Icons.trending_down,
            color: const Color(0xFFE74C3C),
            onTap: onAddExpense,
          ),
          (
            label: 'Transfer',
            icon: Icons.compare_arrows,
            color: const Color(0xFFF39C12),
            onTap: null,
          ),
          (
            label: 'Transactions',
            icon: Icons.receipt_long,
            color: const Color(0xFF3498DB),
            onTap: null,
          ),
        ];

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: actions
              .map(
                (action) => SizedBox(
                  width: itemWidth,
                  child: _QuickActionCard(
                    label: action.label,
                    icon: action.icon,
                    color: action.color,
                    onTap: action.onTap,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {

    final disabled = onTap == null;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: disabled ? null : onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          color: disabled ? color.withOpacity(0.35) : color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 18),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],

        ),
      ),
    );
  }
}

class _BalanceOverviewCard extends StatelessWidget {
  const _BalanceOverviewCard({
    required this.totals,
    required this.budget,
    required this.dateRange,
  });

  final Totals totals;
  final MonthlyBudgetSummary budget;
  final String dateRange;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final currency = NumberFormat.currency(symbol: '₸', decimalDigits: 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F1FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: const Icon(Icons.calendar_month, color: Color(0xFF1565C0)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            dateRange,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0D1C2E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        _BalancePill(label: 'Income', value: currency.format(totals.income), color: const Color(0xFF2ECC71)),
                        _BalancePill(label: 'Expense', value: currency.format(totals.expense), color: const Color(0xFFE74C3C)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Balance', style: textTheme.labelLarge?.copyWith(color: Colors.black54)),
                  const SizedBox(height: 4),
                  Text(
                    currency.format(totals.balance),
                    style: textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF1B5E20),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Budget limit',
                      style: textTheme.labelMedium?.copyWith(color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currency.format(budget.limit),
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Remaining',
                    style: textTheme.labelMedium?.copyWith(color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currency.format(budget.remaining),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2ECC71),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalancePill extends StatelessWidget {
  const _BalancePill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color.darken(),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color.darken(),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _RecentTransactionsCard extends StatelessWidget {
  const _RecentTransactionsCard({
    required this.items,
    required this.onDismiss,
  });

  final List<TransactionListItem> items;
  final void Function(String id) onDismiss;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Transactions',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'No transactions yet. Tap “Add” to create one.',
              style: textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent Transactions',
                  style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Keep track of your latest activity',
                  style: textTheme.bodyMedium?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final item = items[index];
              final t = item.transaction;
              final isIncome = item.isIncome;
              final color = isIncome ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C);
              final sign = isIncome ? '+' : '-';
              final categoryLabel = item.category?.name ?? (isIncome ? 'Income' : 'Expense');

              return Dismissible(
                key: ValueKey(t.id),
                background: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE0E0),
                    borderRadius: index == items.length - 1
                        ? const BorderRadius.only(
                            bottomLeft: Radius.circular(24),
                            bottomRight: Radius.circular(24),
                          )
                        : BorderRadius.zero,
                  ),
                ),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => onDismiss(t.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          isIncome ? Icons.trending_up : Icons.trending_down,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              categoryLabel,
                              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_today, size: 14, color: Colors.black45),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat('EEE, d MMM').format(t.occurredAt),
                                      style: textTheme.bodySmall?.copyWith(color: Colors.black54),
                                    ),
                                  ],
                                ),
                                if ((t.paymentMethod ?? '').isNotEmpty)
                                  Chip(
                                    label: Text(t.paymentMethod!),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (item.isRecurring)
                                  const Chip(
                                    label: Text('Recurring'),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (t.reminderAt != null)
                                  Chip(
                                    label: Text('Reminder · ${DateFormat.MMMd().format(t.reminderAt!)}'),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            if ((t.note ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  t.note!,
                                  style: textTheme.bodySmall?.copyWith(color: Colors.black54),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$sign${NumberFormat('#,##0.00').format(t.amount)}',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
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
    final textTheme = Theme.of(context).textTheme;
    final currency = NumberFormat.currency(symbol: '₸', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.pie_chart, color: Color(0xFF16A085)),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly Budget',
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stay aligned with your plan',
                    style: textTheme.bodyMedium?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: summary.progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFEAF4FF),
              color: const Color(0xFF0057E7),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spent',
                      style: textTheme.labelMedium?.copyWith(color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currency.format(summary.spent),
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Remaining',
                    style: textTheme.labelMedium?.copyWith(color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currency.format(summary.remaining),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2ECC71),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension _ColorBrightness on Color {
  Color darken([double amount = .2]) {
    final hsl = HSLColor.fromColor(this);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) return null;
    return elementAt(0);
  }
}
