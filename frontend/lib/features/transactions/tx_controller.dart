import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/tx_repository.dart';
import '../../data/remote/supabase_service.dart';

class Totals {
  final double income;
  final double expense;
  const Totals({required this.income, required this.expense});
  double get balance => income - expense;
}

final txStreamProvider = StreamProvider((ref) {
  return ref.watch(txRepositoryProvider).watch();
});

final totalsProvider = Provider<Totals>((ref) {
  final txs = ref.watch(txStreamProvider).maybeWhen(data: (d) => d, orElse: () => []);
  double inc = 0, exp = 0;
  for (final t in txs) {
    if (t.type == 'income') inc += t.amount;
    else exp += t.amount;
  }
  return Totals(income: inc, expense: exp);
});

final currentUserIdProvider = Provider<String?>((ref) {
  final session = ref.watch(sessionProvider);
  return session?.user.id;
});
