import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_database.dart';
import '../../data/repositories/account_repository.dart';
import 'tx_controller.dart';

class AccountManagementPage extends ConsumerWidget {
  const AccountManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final accountsAsync = ref.watch(accountStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage accounts'),
      ),
      floatingActionButton: userId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAccountForm(context, ref, userId: userId),
              icon: const Icon(Icons.add),
              label: const Text('Add account'),
            ),
      body: accountsAsync.when(
        data: (accounts) {
          if (userId == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Sign in to manage your accounts.'),
              ),
            );
          }

          if (accounts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No accounts yet. Tap “Add account” to create one.'),
              ),
            );
          }

          final sorted = [...accounts]
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final account = sorted[index];
              return Card(
                child: ListTile(
                  title: Text(account.name),
                  subtitle: Text(_capitalize(account.type)),
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  trailing: PopupMenuButton<String>(
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case 'rename':
                          _showAccountForm(
                            context,
                            ref,
                            userId: userId,
                            account: account,
                          );
                          break;
                        case 'delete':
                          _confirmDelete(
                            context,
                            ref,
                            account: account,
                            allAccounts: sorted,
                          );
                          break;
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Something went wrong: $error'),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _showAccountForm(
    BuildContext context,
    WidgetRef ref, {
    required String userId,
    Account? account,
  }) async {
    final isEditing = account != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: account?.name ?? '');
    var type = account?.type ?? 'cash';

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEditing ? 'Rename account' : 'Add account'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    prefixIcon: Icon(Icons.tune_outlined),
                    helperText: 'Examples: cash, bank, card',
                  ),
                  onChanged: (value) => type = value.trim().isEmpty ? 'cash' : value.trim(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(isEditing ? 'Save' : 'Create'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      nameController.dispose();
      return;
    }

    final trimmedName = nameController.text.trim();
    nameController.dispose();

    final repo = ref.read(accountRepositoryProvider);
    try {
      if (isEditing) {
        await repo.update(id: account!.id, name: trimmedName, type: type);
      } else {
        await repo.add(userId: userId, name: trimmedName, type: type);
      }
      ref.invalidate(accountStreamProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? 'Account updated' : 'Account created')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save account: $error')),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref, {
    required Account account,
    required List<Account> allAccounts,
  }) async {
    final repo = ref.read(accountRepositoryProvider);
    try {
      await repo.delete(id: account.id);
      ref.invalidate(accountStreamProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${account.name}"')),
        );
      }
    } on AccountInUseException catch (e) {
      final alternative = await _showAccountReassignDialog(
        context,
        account: account,
        allAccounts: allAccounts,
        transactionCount: e.transactionCount,
      );
      if (alternative == null) {
        return;
      }
      try {
        await repo.delete(
          id: account.id,
          reassignToAccountId: alternative,
        );
        ref.invalidate(accountStreamProvider);
        ref.invalidate(txStreamProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted "${account.name}"')),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to delete account: $error')),
          );
        }
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete account: $error')),
        );
      }
    }
  }

  Future<String?> _showAccountReassignDialog(
    BuildContext context, {
    required Account account,
    required List<Account> allAccounts,
    required int transactionCount,
  }) {
    final alternatives = allAccounts
        .where((a) => a.id != account.id)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (alternatives.isEmpty) {
      return showDialog<String?>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Account in use'),
            content: Text(
              '"${account.name}" is used in $transactionCount transactions. '
              'Add another account before deleting this one.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    }

    return showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        String? selectedId = alternatives.first.id;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Account in use'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '"${account.name}" is used in $transactionCount transactions. '
                    'Select another account to move them to.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedId,
                    decoration: const InputDecoration(
                      labelText: 'Reassign to',
                      prefixIcon: Icon(Icons.swap_horiz),
                    ),
                    items: alternatives
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => selectedId = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (selectedId == null) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Select an account to reassign to.')),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop(selectedId);
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}
