import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/local/app_database.dart';
import '../../data/repositories/tx_repository.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Income & Expense')),
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _QuickActions(
                        onAddIncome: userId == null
                            ? null
                            : () => _handleQuickAdd(context, ref, userId, categoriesAsync, 'income'),
                        onAddExpense: userId == null
                            ? null
                            : () => _handleQuickAdd(context, ref, userId, categoriesAsync, 'expense'),
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
                    return Dismissible(
                      key: ValueKey(t.id),
                      background: Container(color: Colors.redAccent.withOpacity(0.2)),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => ref.read(txRepositoryProvider).remove(t.id),
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
    List<Category> categories, {
    String initialType = 'expense',
  }) async {
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

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onAddIncome,
    required this.onAddExpense,
  });

  final VoidCallback? onAddIncome;
  final VoidCallback? onAddExpense;

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
          label: 'Transfer',
          icon: Icons.compare_arrows,
          color: Colors.orange,
          onTap: null,
        ),
        _ActionChip(
          label: 'Transactions',
          icon: Icons.list_alt,
          color: Colors.blueGrey,
          onTap: null,
        ),
      ],
    );
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
