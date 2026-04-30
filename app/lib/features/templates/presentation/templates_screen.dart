import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money_format.dart';
import '../../../features/finance/domain/finance_models.dart';
import '../../../shared/providers/app_providers.dart';

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(quickAddTemplatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quick Add Templates')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTemplateSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Template'),
      ),
      body: templates.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No templates yet. Add one for repeated transactions.',
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _TemplateCard(entry: items[index]),
          );
        },
        error: (error, stackTrace) => Center(child: Text('$error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _showTemplateSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: const _AddTemplateSheet(),
      ),
    );
  }
}

class _TemplateCard extends ConsumerWidget {
  const _TemplateCard({required this.entry});

  final QuickAddTemplateEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          entry.template.transactionType == 'income'
              ? Icons.south_west
              : Icons.north_east,
        ),
        title: Text(entry.template.name),
        subtitle: Text(
          [
            entry.category?.name,
            entry.account?.name,
            'Used ${entry.template.useCount} times',
          ].whereType<String>().join(' - '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formatMoney(entry.template.defaultAmount)),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  _showEditSheet(context, entry);
                } else if (value == 'delete') {
                  await _confirmArchive(context, ref, entry);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
        onTap: () => _showUseSheet(context, entry),
      ),
    );
  }

  void _showUseSheet(BuildContext context, QuickAddTemplateEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: _UseTemplateSheet(entry: entry),
      ),
    );
  }

  void _showEditSheet(BuildContext context, QuickAddTemplateEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: _AddTemplateSheet(entry: entry),
      ),
    );
  }

  Future<void> _confirmArchive(
    BuildContext context,
    WidgetRef ref,
    QuickAddTemplateEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text('Delete ${entry.template.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete),
            label: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await ref
        .read(financeRepositoryProvider)
        .archiveQuickAddTemplate(entry.template.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Template deleted')));
  }
}

class _AddTemplateSheet extends ConsumerStatefulWidget {
  const _AddTemplateSheet({this.entry});

  final QuickAddTemplateEntry? entry;

  @override
  ConsumerState<_AddTemplateSheet> createState() => _AddTemplateSheetState();
}

class _AddTemplateSheetState extends ConsumerState<_AddTemplateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _type = 'expense';
  int? _categoryId;
  int? _accountId;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    if (entry == null) return;
    _nameController.text = entry.template.name;
    _amountController.text = entry.template.defaultAmount.toStringAsFixed(2);
    _noteController.text = entry.template.defaultNote ?? '';
    _type = entry.template.transactionType;
    _categoryId = entry.template.categoryId;
    _accountId = entry.template.accountId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountBalancesProvider);
    final categories = ref.watch(
      _type == 'income' ? incomeCategoriesProvider : expenseCategoriesProvider,
    );
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
        child: accounts.when(
          data: (accountItems) => categories.when(
            data: (categoryItems) => Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.entry == null ? 'Add Template' : 'Edit Template',
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
                      onSelectionChanged: (values) => setState(() {
                        _type = values.first;
                        _categoryId = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Template name',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _categoryId,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        for (final category in categoryItems)
                          DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          ),
                      ],
                      onChanged: (value) => setState(() => _categoryId = value),
                      validator: (value) =>
                          value == null ? 'Choose a category' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _accountId,
                      decoration: const InputDecoration(labelText: 'Account'),
                      items: [
                        for (final account in accountItems)
                          DropdownMenuItem(
                            value: account.account.id,
                            child: Text(account.account.name),
                          ),
                      ],
                      onChanged: (value) => setState(() => _accountId = value),
                      validator: (value) =>
                          value == null ? 'Choose an account' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Default amount',
                      ),
                      validator: (value) {
                        final parsed = double.tryParse(value ?? '');
                        if (parsed == null || parsed <= 0) {
                          return 'Enter an amount greater than zero';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: 'Default note',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saveTemplate,
                      icon: const Icon(Icons.save),
                      label: Text(
                        widget.entry == null
                            ? 'Save Template'
                            : 'Update Template',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            error: (error, stackTrace) => Text('$error'),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => Text('$error'),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;
    final repository = ref.read(financeRepositoryProvider);
    final entry = widget.entry;
    if (entry == null) {
      await repository.addQuickAddTemplate(
        name: _nameController.text.trim(),
        transactionType: _type,
        categoryId: _categoryId!,
        accountId: _accountId!,
        defaultAmount: double.parse(_amountController.text),
        defaultNote: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
    } else {
      await repository.updateQuickAddTemplate(
        templateId: entry.template.id,
        name: _nameController.text.trim(),
        transactionType: _type,
        categoryId: _categoryId!,
        accountId: _accountId!,
        defaultAmount: double.parse(_amountController.text),
        defaultNote: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.entry == null ? 'Template saved' : 'Template updated',
        ),
      ),
    );
  }
}

class _UseTemplateSheet extends ConsumerStatefulWidget {
  const _UseTemplateSheet({required this.entry});

  final QuickAddTemplateEntry entry;

  @override
  ConsumerState<_UseTemplateSheet> createState() => _UseTemplateSheetState();
}

class _UseTemplateSheetState extends ConsumerState<_UseTemplateSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.entry.template.defaultAmount.toStringAsFixed(2),
    );
    _noteController = TextEditingController(
      text: widget.entry.template.defaultNote ?? '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.entry.template.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                [
                  widget.entry.category?.name,
                  widget.entry.account?.name,
                ].whereType<String>().join(' - '),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Amount'),
                validator: (value) {
                  final parsed = double.tryParse(value ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Enter an amount greater than zero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Note'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saveTransaction,
                icon: const Icon(Icons.flash_on),
                label: const Text('Add Transaction'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(financeRepositoryProvider)
        .useQuickAddTemplate(
          templateId: widget.entry.template.id,
          amount: double.parse(_amountController.text),
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );

    ref.invalidate(dashboardProvider);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Transaction added')));
  }
}
