import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money_format.dart';
import '../../../database/app_database.dart';
import '../../../shared/providers/app_providers.dart';

const _categoryColors = [
  ('246B5F', 'Green'),
  ('0F5D4F', 'Dark green'),
  ('2F5F98', 'Blue'),
  ('D8A23A', 'Gold'),
  ('B85C38', 'Clay'),
  ('6F5FA8', 'Purple'),
  ('475569', 'Slate'),
];

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categories'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Expense'),
              Tab(text: 'Income'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCategorySheet(context),
          icon: const Icon(Icons.add),
          label: const Text('Category'),
        ),
        body: const TabBarView(
          children: [
            _CategoryList(type: 'expense'),
            _CategoryList(type: 'income'),
          ],
        ),
      ),
    );
  }

  static void _showCategorySheet(BuildContext context, [Category? category]) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: _CategorySheet(category: category),
      ),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.type});

  final String type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(
      type == 'income' ? incomeCategoriesProvider : expenseCategoriesProvider,
    );

    return categories.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No $type categories yet.'),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _CategoryCard(
            category: items[index],
            onEdit: () =>
                CategoriesScreen._showCategorySheet(context, items[index]),
            onArchive: () => _confirmArchive(context, ref, items[index]),
          ),
        );
      },
      error: (error, stackTrace) => Center(child: Text('$error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Future<void> _confirmArchive(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive category?'),
        content: Text(
          'Archive ${category.name}? Existing transactions will keep this category.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.archive),
            label: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await ref.read(financeRepositoryProvider).archiveCategory(category.id);
    ref.invalidate(incomeCategoriesProvider);
    ref.invalidate(expenseCategoriesProvider);
    ref.invalidate(budgetUsageProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(reportsDashboardProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Category archived')));
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.onEdit,
    required this.onArchive,
  });

  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(category.colorHex);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(_iconForType(category.type), color: Colors.white),
        ),
        title: Text(category.name),
        subtitle: Text(
          category.type == 'expense'
              ? 'Default budget ${formatMoney(category.defaultMonthlyBudget)}'
              : 'Income category',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'archive') onArchive();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'archive', child: Text('Archive')),
          ],
        ),
      ),
    );
  }
}

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({this.category});

  final Category? category;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();
  final _noteController = TextEditingController();
  String _type = 'expense';
  String _colorHex = '246B5F';

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    if (category != null) {
      _nameController.text = category.name;
      _budgetController.text = category.defaultMonthlyBudget.toStringAsFixed(2);
      _noteController.text = category.note ?? '';
      _type = category.type;
      _colorHex = category.colorHex ?? '246B5F';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.category == null ? 'Add Category' : 'Edit Category',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'expense',
                      label: Text('Expense'),
                      icon: Icon(Icons.north_east),
                    ),
                    ButtonSegment(
                      value: 'income',
                      label: Text('Income'),
                      icon: Icon(Icons.south_west),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: widget.category == null
                      ? (values) => setState(() => _type = values.first)
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Category name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a category name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _budgetController,
                  enabled: _type == 'expense',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Default monthly budget',
                  ),
                  validator: (value) {
                    if (_type == 'income') return null;
                    final parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed < 0) {
                      return 'Enter zero or more';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _colorHex,
                  decoration: const InputDecoration(labelText: 'Color'),
                  items: [
                    for (final item in _categoryColors)
                      DropdownMenuItem(
                        value: item.$1,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 8,
                              backgroundColor: _parseColor(item.$1),
                            ),
                            const SizedBox(width: 8),
                            Text(item.$2),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _colorHex = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(labelText: 'Note'),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: Text(
                    widget.category == null
                        ? 'Save Category'
                        : 'Update Category',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final note = _noteController.text.trim();
    final budget = _type == 'expense'
        ? double.parse(_budgetController.text.isEmpty ? '0' : _budgetController.text)
        : 0.0;
    final repository = ref.read(financeRepositoryProvider);
    final category = widget.category;

    if (category == null) {
      await repository.addCategory(
        name: _nameController.text.trim(),
        type: _type,
        defaultMonthlyBudget: budget,
        colorHex: _colorHex,
        note: note.isEmpty ? null : note,
      );
    } else {
      await repository.updateCategory(
        categoryId: category.id,
        name: _nameController.text.trim(),
        type: _type,
        defaultMonthlyBudget: budget,
        colorHex: _colorHex,
        note: note.isEmpty ? null : note,
      );
    }

    ref.invalidate(incomeCategoriesProvider);
    ref.invalidate(expenseCategoriesProvider);
    ref.invalidate(budgetUsageProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(reportsDashboardProvider);

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(category == null ? 'Category saved' : 'Category updated'),
      ),
    );
  }
}

Color _parseColor(String? hex) {
  final value = hex == null || hex.isEmpty ? '246B5F' : hex;
  return Color(int.parse('FF$value', radix: 16));
}

IconData _iconForType(String type) {
  return type == 'income' ? Icons.south_west : Icons.north_east;
}
