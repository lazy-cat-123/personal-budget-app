import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money_format.dart';
import '../../../features/finance/domain/finance_models.dart';
import '../../../shared/providers/app_providers.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetUsageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Budget')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBudgetSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Budget'),
      ),
      body: budgets.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No budgets yet. Add a category budget to track spending.',
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _BudgetCard(
              usage: items[index],
              onDelete: () => _confirmDeleteBudget(context, ref, items[index]),
            ),
          );
        },
        error: (error, stackTrace) => Center(child: Text('$error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _showBudgetSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: const _AddBudgetSheet(),
      ),
    );
  }

  Future<void> _confirmDeleteBudget(
    BuildContext context,
    WidgetRef ref,
    BudgetUsage usage,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete budget?'),
        content: Text(
          'Delete the ${usage.category.name} ${usage.budget.periodType} budget? This will not delete any transactions.',
        ),
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
    await ref.read(financeRepositoryProvider).archiveBudget(usage.budget.id);
    ref.invalidate(budgetUsageProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(reportsDashboardProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Budget deleted')));
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.usage, required this.onDelete});

  final BudgetUsage usage;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final percent = (usage.usagePercentage * 100).clamp(0, 999).round();
    final statusColor = switch (usage.status) {
      BudgetStatus.ok => Colors.green,
      BudgetStatus.warning => Colors.orange,
      BudgetStatus.over => Colors.red,
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        usage.category.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        usage.budget.periodType == 'weekly'
                            ? 'Weekly budget'
                            : 'Monthly budget',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(usage.status.label),
                  side: BorderSide(color: statusColor),
                  labelStyle: TextStyle(color: statusColor),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: usage.usagePercentage.clamp(0, 1),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: statusColor,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _BudgetMetric(
                    label: 'Used',
                    value: formatMoney(usage.usedAmount),
                  ),
                ),
                Expanded(
                  child: _BudgetMetric(
                    label: 'Remaining',
                    value: formatMoney(usage.remainingAmount),
                  ),
                ),
                Expanded(
                  child: _BudgetMetric(label: 'Usage', value: '$percent%'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Limit ${formatMoney(usage.budget.amount)}'),
          ],
        ),
      ),
    );
  }
}

class _BudgetMetric extends StatelessWidget {
  const _BudgetMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _AddBudgetSheet extends ConsumerStatefulWidget {
  const _AddBudgetSheet();

  @override
  ConsumerState<_AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends ConsumerState<_AddBudgetSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String _periodType = 'monthly';
  double _alertThreshold = 0.8;
  int? _categoryId;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(expenseCategoriesProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
        child: categories.when(
          data: (items) => Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Budget',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: _categoryId,
                    decoration: const InputDecoration(
                      labelText: 'Expense category',
                    ),
                    items: [
                      for (final category in items)
                        DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _categoryId = value;
                      final category = items
                          .where((item) => item.id == value)
                          .firstOrNull;
                      if (category != null &&
                          category.defaultMonthlyBudget > 0 &&
                          _amountController.text.trim().isEmpty) {
                        _amountController.text =
                            category.defaultMonthlyBudget.toStringAsFixed(2);
                      }
                    }),
                    validator: (value) =>
                        value == null ? 'Choose a category' : null,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'monthly',
                        label: Text('Monthly'),
                        icon: Icon(Icons.calendar_month),
                      ),
                      ButtonSegment(
                        value: 'weekly',
                        label: Text('Weekly'),
                        icon: Icon(Icons.view_week),
                      ),
                    ],
                    selected: {_periodType},
                    onSelectionChanged: (values) =>
                        setState(() => _periodType = values.first),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Budget amount',
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
                  Text('Alert at ${(_alertThreshold * 100).round()}%'),
                  Slider(
                    value: _alertThreshold,
                    min: 0.5,
                    max: 1,
                    divisions: 10,
                    label: '${(_alertThreshold * 100).round()}%',
                    onChanged: (value) =>
                        setState(() => _alertThreshold = value),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _saveBudget,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Budget'),
                  ),
                ],
              ),
            ),
          ),
          error: (error, stackTrace) => Text('$error'),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final startDate = _periodType == 'weekly'
        ? DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: now.weekday - 1))
        : DateTime(now.year, now.month);

    await ref
        .read(financeRepositoryProvider)
        .addBudget(
          categoryId: _categoryId!,
          periodType: _periodType,
          amount: double.parse(_amountController.text),
          startDate: startDate,
          alertThreshold: _alertThreshold,
        );
    ref.invalidate(budgetUsageProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(reportsDashboardProvider);

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Budget saved')));
  }
}
