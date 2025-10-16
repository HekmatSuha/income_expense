import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/app_database.dart';
import 'tx_repository.dart';

const kDefaultCurrencyCode = 'KZT';
const kDefaultMonthlyBudget = 500000.0;
const kDefaultAnnualBudget = 6000000.0;

class ResolvedUserSettings {
  const ResolvedUserSettings({
    required this.userId,
    required this.currencyCode,
    this.monthlyBudgetLimit,
    this.annualBudgetLimit,
  });

  final String userId;
  final String currencyCode;
  final double? monthlyBudgetLimit;
  final double? annualBudgetLimit;
}

class UserSettingsRepository {
  UserSettingsRepository(this.db);

  final AppDatabase db;

  static ResolvedUserSettings defaultSettings(String userId) {
    return ResolvedUserSettings(
      userId: userId,
      currencyCode: kDefaultCurrencyCode,
      monthlyBudgetLimit: kDefaultMonthlyBudget,
      annualBudgetLimit: kDefaultAnnualBudget,
    );
  }

  ResolvedUserSettings mapToResolved(UserSetting setting) {
    return ResolvedUserSettings(
      userId: setting.userId,
      currencyCode: setting.currencyCode,
      monthlyBudgetLimit: setting.monthlyBudgetLimit,
      annualBudgetLimit: setting.annualBudgetLimit,
    );
  }

  Future<UserSetting> ensureDefaults(String userId) async {
    final existing = await db.userSettingForUser(userId);
    if (existing != null) {
      return existing;
    }
    final now = DateTime.now().toUtc();
    final companion = UserSettingsCompanion(
      userId: Value(userId),
      currencyCode: const Value(kDefaultCurrencyCode),
      monthlyBudgetLimit: const Value(kDefaultMonthlyBudget),
      annualBudgetLimit: const Value(kDefaultAnnualBudget),
      updatedAt: Value(now),
    );
    await db.upsertUserSetting(companion);
    return (await db.userSettingForUser(userId))!;
  }

  Future<ResolvedUserSettings> resolved(String userId) async {
    final data = await ensureDefaults(userId);
    return mapToResolved(data);
  }

  Stream<ResolvedUserSettings> watchResolved(String userId) async* {
    final initial = await resolved(userId);
    yield initial;
    yield* db
        .watchUserSettingForUser(userId)
        .asyncMap((value) async => mapToResolved(value ?? await ensureDefaults(userId)));
  }

  Future<UserSetting?> fetch(String userId) {
    return db.userSettingForUser(userId);
  }

  Future<void> update({
    required String userId,
    required String currencyCode,
    double? monthlyBudget,
    double? annualBudget,
  }) async {
    final companion = UserSettingsCompanion(
      userId: Value(userId),
      currencyCode: Value(currencyCode),
      monthlyBudgetLimit:
          monthlyBudget == null ? const Value.absent() : Value(monthlyBudget),
      annualBudgetLimit:
          annualBudget == null ? const Value.absent() : Value(annualBudget),
      updatedAt: Value(DateTime.now().toUtc()),
    );
    await db.upsertUserSetting(companion);
  }
}

final userSettingsRepositoryProvider = Provider<UserSettingsRepository>((ref) {
  final db = ref.watch(dbProvider);
  return UserSettingsRepository(db);
});
