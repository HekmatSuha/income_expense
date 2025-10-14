import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_database.dart';
import '../../data/repositories/category_repository.dart';
import 'tx_controller.dart';

class CategoryManagementPage extends ConsumerWidget {
  const CategoryManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final categoriesAsync = ref.watch(categoryStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage categories'),
      ),
      floatingActionButton: userId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showCategoryForm(context, ref, userId: userId),
              icon: const Icon(Icons.add),
              label: const Text('Add category'),
            ),
      body: categoriesAsync.when(
        data: (categories) {
          if (userId == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Sign in to manage your categories.'),
              ),
            );
          }

          if (categories.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No categories yet. Tap “Add category” to create one.'),
              ),
            );
          }

          final incomeCategories = categories
              .where((c) => c.type == 'income')
              .toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          final expenseCategories = categories
              .where((c) => c.type == 'expense')
              .toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              if (incomeCategories.isNotEmpty)
                _CategorySection(
                  title: 'Income categories',
                  categories: incomeCategories,
                  onRename: (category) =>
                      _showCategoryForm(context, ref, userId: userId, category: category),
                  onDelete: (category) => _confirmDelete(
                    context,
                    ref,
                    category: category,
                    allCategories: categories,
                  ),
                ),
              if (expenseCategories.isNotEmpty)
                _CategorySection(
                  title: 'Expense categories',
                  categories: expenseCategories,
                  onRename: (category) =>
                      _showCategoryForm(context, ref, userId: userId, category: category),
                  onDelete: (category) => _confirmDelete(
                    context,
                    ref,
                    category: category,
                    allCategories: categories,
                  ),
                ),
            ],
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

  Future<void> _showCategoryForm(
    BuildContext context,
    WidgetRef ref, {
    required String userId,
    Category? category,
  }) async {
    final isEditing = category != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: category?.name ?? '');
    var type = category?.type ?? 'expense';

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEditing ? 'Rename category' : 'Add category'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    prefixIcon: Icon(Icons.tune_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'income',
                      child: Text('Income'),
                    ),
                    DropdownMenuItem(
                      value: 'expense',
                      child: Text('Expense'),
                    ),
                  ],
                  onChanged: (value) => type = value ?? 'expense',
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

    final repo = ref.read(categoryRepositoryProvider);
    try {
      if (isEditing) {
        await repo.update(id: category!.id, name: trimmedName, type: type);
      } else {
        await repo.add(userId: userId, name: trimmedName, type: type);
      }
      ref.invalidate(categoryStreamProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? 'Category updated' : 'Category created')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save category: $error')),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref, {
    required Category category,
    required List<Category> allCategories,
  }) async {
    final repo = ref.read(categoryRepositoryProvider);
    try {
      await repo.delete(id: category.id);
      ref.invalidate(categoryStreamProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${category.name}"')),
        );
      }
    } on CategoryInUseException catch (e) {
      final resolution = await _showCategoryReassignDialog(
        context,
        category: category,
        allCategories: allCategories,
        transactionCount: e.transactionCount,
      );
      if (resolution == null) {
        return;
      }
      try {
        if (resolution.unassign) {
          await repo.delete(
            id: category.id,
            setTransactionsToNull: true,
          );
        } else {
          await repo.delete(
            id: category.id,
            reassignToCategoryId: resolution.categoryId,
          );
        }
        ref.invalidate(categoryStreamProvider);
        ref.invalidate(txStreamProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted "${category.name}"')),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to delete category: $error')),
          );
        }
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete category: $error')),
        );
      }
    }
  }

  Future<_CategoryDeleteResolution?> _showCategoryReassignDialog(
    BuildContext context, {
    required Category category,
    required List<Category> allCategories,
    required int transactionCount,
  }) {
    final alternatives = allCategories
        .where((c) => c.id != category.id && c.type == category.type)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return showDialog<_CategoryDeleteResolution>(
      context: context,
      builder: (dialogContext) {
        var unassign = alternatives.isEmpty;
        String? selectedId = alternatives.isEmpty ? null : alternatives.first.id;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Category in use'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '"${category.name}" is used in $transactionCount transactions. '
                    'Choose how to proceed.',
                  ),
                  const SizedBox(height: 16),
                  if (alternatives.isNotEmpty) ...[
                    RadioListTile<bool>(
                      value: false,
                      groupValue: unassign,
                      onChanged: (value) => setState(() => unassign = value ?? false),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Reassign to another category'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedId,
                            decoration: const InputDecoration(
                              labelText: 'New category',
                              prefixIcon: Icon(Icons.swap_horiz),
                            ),
                            items: alternatives
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) => setState(() => selectedId = value),
                          ),
                        ],
                      ),
                    ),
                    RadioListTile<bool>(
                      value: true,
                      groupValue: unassign,
                      onChanged: (value) => setState(() => unassign = value ?? false),
                      title: const Text('Remove category from existing transactions'),
                    ),
                  ] else
                    const Text(
                      'There are no other categories of this type. '
                      'Existing transactions will lose their category.',
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
                    if (!unassign && selectedId == null) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Select a category to reassign to.')),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop(
                      _CategoryDeleteResolution(
                        categoryId: selectedId,
                        unassign: unassign,
                      ),
                    );
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

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.categories,
    required this.onRename,
    required this.onDelete,
  });

  final String title;
  final List<Category> categories;
  final void Function(Category category) onRename;
  final void Function(Category category) onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 0),
            ...categories.map(
              (category) => Column(
                children: [
                  ListTile(
                    title: Text(category.name),
                    subtitle: Text(_capitalize(category.type)),
                    trailing: PopupMenuButton<String>(
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'rename', child: Text('Rename')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                      onSelected: (value) {
                        switch (value) {
                          case 'rename':
                            onRename(category);
                            break;
                          case 'delete':
                            onDelete(category);
                            break;
                        }
                      },
                    ),
                  ),
                  if (category != categories.last) const Divider(height: 0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryDeleteResolution {
  const _CategoryDeleteResolution({
    required this.categoryId,
    required this.unassign,
  });

  final String? categoryId;
  final bool unassign;
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}
