import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/repositories/tx_repository.dart';
import 'tx_controller.dart';

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(txStreamProvider);
    final totals = ref.watch(totalsProvider);
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Income & Expense')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: userId == null ? null : () => _openAddDialog(context, ref, userId),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: _metric('Income', totals.income, Icons.trending_up)),
                  Expanded(child: _metric('Expense', totals.expense, Icons.trending_down)),
                  Expanded(child: _metric('Balance', totals.balance, Icons.account_balance_wallet)),
                ],
              ),
            ),
          ),
          Expanded(
            child: txsAsync.when(
              data: (txs) => ListView.separated(
                itemCount: txs.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (_, i) {
                  final t = txs[i];
                  final sign = t.type == 'income' ? '+' : '-';
                  final color = t.type == 'income' ? Colors.green : Colors.red;
                  return Dismissible(
                    key: ValueKey(t.id),
                    background: Container(color: Colors.redAccent),
                    onDismissed: (_) => ref.read(txRepositoryProvider).remove(t.id),
                    child: ListTile(
                      leading: Icon(
                        t.type == 'income' ? Icons.south_west : Icons.north_east,
                        color: color,
                      ),
                      title: Text(t.type == 'income' ? 'Income' : 'Expense'),
                      subtitle: Text(DateFormat.yMMMd().format(t.occurredAt)),
                      trailing: Text(
                        '$sign${NumberFormat('#,##0.00').format(t.amount)}',
                        style: TextStyle(color: color, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                },
              ),
              error: (e, st) => Center(child: Text('Error: $e')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, double value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        Text(NumberFormat.simpleCurrency(name: 'KZT').format(value),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Future<void> _openAddDialog(BuildContext context, WidgetRef ref, String userId) async {
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController();
    String type = 'expense';
    DateTime date = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add transaction'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'income', label: Text('Income')),
                      ButtonSegment(value: 'expense', label: Text('Expense')),
                    ],
                    selected: {type},
                    onSelectionChanged: (s) => type = s.first,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Amount (KZT)',
                      prefixIcon: Icon(Icons.payments),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final x = double.tryParse(v ?? '');
                      if (x == null || x <= 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(DateFormat.yMMMd().format(date)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            date = picked;
                            (ctx as Element).markNeedsBuild();
                          }
                        },
                        icon: const Icon(Icons.event),
                        label: const Text('Pick date'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final amount = double.parse(amountCtrl.text);
                await ref.read(txRepositoryProvider).add(
                  userId: userId,
                  type: type,
                  amount: amount,
                  occurredAt: date,
                );
                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
