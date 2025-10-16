import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/remote/firebase_service.dart';
import '../../data/repositories/settings_repository.dart';
import '../auth/auth_state.dart';
import 'settings_controller.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _sendingVerification = false;
  bool _refreshingStatus = false;

  Future<void> _sendVerificationEmail(User user) async {
    setState(() {
      _sendingVerification = true;
    });
    try {
      await user.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent. Check your inbox.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not send verification email: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sendingVerification = false;
        });
      }
    }
  }

  Future<void> _refreshUser(User user) async {
    setState(() {
      _refreshingStatus = true;
    });
    try {
      await user.reload();
      ref.invalidate(authStateChangesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh account: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _refreshingStatus = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(firebaseUserProvider);
    final guestMode = ref.watch(guestModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: guestMode || user == null
                ? const _GuestModeNotice()
                : _AccountDetails(
                    user: user,
                    onSendVerification: _sendingVerification
                        ? null
                        : () => _sendVerificationEmail(user),
                    onRefreshStatus:
                        _refreshingStatus ? null : () => _refreshUser(user),
                    sendingVerification: _sendingVerification,
                    refreshingStatus: _refreshingStatus,
                  ),
          ),
        ),
      ),
    );
  }
}

class _GuestModeNotice extends StatelessWidget {
  const _GuestModeNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Icon(Icons.info_outline, size: 32),
            SizedBox(height: 16),
            Text(
              'Guest mode active',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Sign in to manage your account settings and email verification.',
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetSettingsCard extends ConsumerStatefulWidget {
  const _BudgetSettingsCard();

  @override
  ConsumerState<_BudgetSettingsCard> createState() => _BudgetSettingsCardState();
}

class _BudgetSettingsCardState extends ConsumerState<_BudgetSettingsCard> {
  static const _currencyOptions = <String>['KZT', 'USD', 'EUR', 'GBP', 'JPY'];

  late final TextEditingController _monthlyController;
  late final TextEditingController _annualController;
  bool _dirty = false;
  bool _saving = false;
  bool _applyingFromSettings = false;
  String? _currencyCode;
  ResolvedUserSettings? _lastSettings;

  @override
  void initState() {
    super.initState();
    _monthlyController = TextEditingController();
    _annualController = TextEditingController();
    _monthlyController.addListener(_onFieldChanged);
    _annualController.addListener(_onFieldChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initial = ref.read(userSettingsStreamProvider);
      initial.whenData(_applySettings);
    });
    ref.listen<AsyncValue<ResolvedUserSettings>>(
      userSettingsStreamProvider,
      (previous, next) {
        next.whenData(_applySettings);
      },
    );
  }

  @override
  void dispose() {
    _monthlyController.dispose();
    _annualController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (_applyingFromSettings) return;
    if (!_dirty) {
      setState(() {
        _dirty = true;
      });
    }
  }

  void _applySettings(ResolvedUserSettings settings) {
    _applyingFromSettings = true;
    _lastSettings = settings;
    final monthly = settings.monthlyBudgetLimit;
    final annual = settings.annualBudgetLimit;
    setState(() {
      _currencyCode = settings.currencyCode;
      _monthlyController.text = _formatInputValue(monthly);
      _annualController.text = _formatInputValue(annual);
      _dirty = false;
    });
    _applyingFromSettings = false;
  }

  String _formatInputValue(double? value) {
    if (value == null) return '';
    final isWhole = value.truncateToDouble() == value;
    return isWhole ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  double? _parseInput(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final normalized = trimmed.replaceAll(RegExp(r'[\s,]'), '');
    return double.tryParse(normalized);
  }

  Future<void> _saveSettings() async {
    final userId = ref.read(effectiveUserIdProvider);
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to update your budget settings.')),
        );
      }
      return;
    }

    final currency = _currencyCode ?? _lastSettings?.currencyCode ?? kDefaultCurrencyCode;
    final monthly = _parseInput(_monthlyController.text);
    final annual = _parseInput(_annualController.text);

    if (_monthlyController.text.trim().isNotEmpty && monthly == null) {
      _showError('Enter a valid number for the monthly budget.');
      return;
    }
    if (_annualController.text.trim().isNotEmpty && annual == null) {
      _showError('Enter a valid number for the annual budget.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
    });
    try {
      await ref.read(userSettingsRepositoryProvider).update(
            userId: userId,
            currencyCode: currency,
            monthlyBudget: monthly,
            annualBudget: annual,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Budget settings updated.')),
        );
      }
    } catch (e) {
      _showError('Could not save settings: $e');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _reset() {
    if (_lastSettings != null) {
      _applySettings(_lastSettings!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(userSettingsStreamProvider);
    final currencyFormats = ref.watch(currencyFormatsProvider);
    final isLoading = settingsAsync is AsyncLoading<ResolvedUserSettings>;
    final selectedCurrency = _currencyCode ??
        settingsAsync.maybeWhen(
          data: (value) => value.currencyCode,
          orElse: () => currencyFormats.currencyCode,
        );
    final previewFormat = NumberFormat.simpleCurrency(name: selectedCurrency);
    final currencyOptions = {
      ..._currencyOptions,
      if (selectedCurrency != null) selectedCurrency!,
    }.toList()
      ..sort();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings),
                const SizedBox(width: 12),
                Text(
                  'Budgets & currency',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Pick the currency used for reports and set optional monthly/annual targets.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedCurrency,
              decoration: const InputDecoration(
                labelText: 'Preferred currency',
                border: OutlineInputBorder(),
              ),
              onChanged: isLoading || _saving
                  ? null
                  : (value) {
                      setState(() {
                        _currencyCode = value;
                        _dirty = true;
                      });
                    },
              items: currencyOptions
                  .map(
                    (code) => DropdownMenuItem(
                      value: code,
                      child: Text('$code (${NumberFormat.simpleCurrency(name: code).currencySymbol})'),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _monthlyController,
              enabled: !isLoading && !_saving,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Monthly target',
                hintText: 'e.g. ${previewFormat.format(50000)}',
                prefixText: '${previewFormat.currencySymbol} ',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _annualController,
              enabled: !isLoading && !_saving,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Annual target',
                hintText: 'e.g. ${previewFormat.format(600000)}',
                prefixText: '${previewFormat.currencySymbol} ',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton(
                  onPressed: !_dirty || _saving ? null : _reset,
                  child: const Text('Reset'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: !_dirty || _saving ? null : _saveSettings,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Save settings'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountDetails extends ConsumerWidget {
  const _AccountDetails({
    required this.user,
    required this.onSendVerification,
    required this.onRefreshStatus,
    required this.sendingVerification,
    required this.refreshingStatus,
  });

  final User user;
  final VoidCallback? onSendVerification;
  final VoidCallback? onRefreshStatus;
  final bool sendingVerification;
  final bool refreshingStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = user.email ?? 'Unknown';
    final verified = user.emailVerified;

    return ListView(
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.person),
            title: Text(email),
            subtitle: const Text('Email'),
          ),
        ),
        const SizedBox(height: 12),
        const _BudgetSettingsCard(),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_outlined),
                    const SizedBox(width: 12),
                    Text(
                      verified ? 'Email verified' : 'Email not verified',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  verified
                      ? 'Your email address has been verified. No further action is required.'
                      : 'Verify your email to unlock all features. We use your email address to secure your account.',
                ),
                const SizedBox(height: 16),
                if (!verified)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: onSendVerification,
                        icon: sendingVerification
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.mail),
                        label: const Text('Resend verification email'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onRefreshStatus,
                        icon: refreshingStatus
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh),
                        label: const Text('I have verified my email'),
                      ),
                    ],
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: onRefreshStatus,
                      icon: refreshingStatus
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: const Text('Refresh status'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
