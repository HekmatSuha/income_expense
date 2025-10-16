import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/repositories/settings_repository.dart';
import '../auth/auth_state.dart';

final userSettingsStreamProvider =
    StreamProvider.autoDispose<ResolvedUserSettings>((ref) {
  final userId = ref.watch(effectiveUserIdProvider);
  final repository = ref.watch(userSettingsRepositoryProvider);
  if (userId == null) {
    return Stream.value(UserSettingsRepository.defaultSettings('anonymous'));
  }
  return repository.watchResolved(userId);
});

class CurrencyFormats {
  CurrencyFormats({
    required this.regular,
    required this.compact,
    required this.currencyCode,
    required this.currencySymbol,
  });

  final NumberFormat regular;
  final NumberFormat compact;
  final String currencyCode;
  final String currencySymbol;
}

final currencyFormatsProvider = Provider<CurrencyFormats>((ref) {
  final settings = ref.watch(userSettingsStreamProvider).maybeWhen(
        data: (value) => value,
        orElse: () => UserSettingsRepository.defaultSettings('anonymous'),
      );
  final regular = NumberFormat.simpleCurrency(name: settings.currencyCode);
  final compact = NumberFormat.compactCurrency(
    name: settings.currencyCode,
    symbol: regular.currencySymbol,
  );
  return CurrencyFormats(
    regular: regular,
    compact: compact,
    currencyCode: settings.currencyCode,
    currencySymbol: regular.currencySymbol,
  );
});
