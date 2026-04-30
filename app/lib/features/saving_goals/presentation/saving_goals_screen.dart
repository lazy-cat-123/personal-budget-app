import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money_format.dart';
import '../../../database/app_database.dart';
import '../../../features/finance/domain/finance_models.dart';
import '../../../shared/providers/app_providers.dart';

class SavingGoalsScreen extends ConsumerWidget {
  const SavingGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(savingGoalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saving Goals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGoalSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Goal'),
      ),
      body: goals.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No saving goals yet. Add a goal to track progress.',
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _SavingGoalCard(goal: items[index]),
          );
        },
        error: (error, stackTrace) => Center(child: Text('$error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _showGoalSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: const _AddGoalSheet(),
      ),
    );
  }
}

class _SavingGoalCard extends ConsumerWidget {
  const _SavingGoalCard({required this.goal});

  final SavingGoalProgress goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final percent = (goal.progressPercentage * 100).clamp(0, 999).round();
    final progressValue = goal.progressPercentage.clamp(0, 1).toDouble();

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
                        goal.goal.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (goal.goal.targetDate != null)
                        Text(
                          'Target ${goal.goal.targetDate!.year}-${goal.goal.targetDate!.month}-${goal.goal.targetDate!.day}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Add contribution',
                  icon: const Icon(Icons.add_card),
                  onPressed: () => _showContributionSheet(context, goal.goal),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value != 'archive') return;
                    final confirmed = await _confirmArchive(context, goal);
                    if (confirmed != true || !context.mounted) return;
                    await ref
                        .read(financeRepositoryProvider)
                        .archiveSavingGoal(goal.goal.id);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'archive', child: Text('Archive')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progressValue,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _GoalMetric(
                    label: 'Saved',
                    value: formatMoney(goal.currentAmount),
                  ),
                ),
                Expanded(
                  child: _GoalMetric(
                    label: 'Remaining',
                    value: formatMoney(goal.remainingAmount),
                  ),
                ),
                Expanded(
                  child: _GoalMetric(label: 'Progress', value: '$percent%'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Target ${formatMoney(goal.goal.targetAmount)}'),
            if (goal.goal.countContributionAsExpense)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Contributions count as expenses'),
              ),
          ],
        ),
      ),
    );
  }

  void _showContributionSheet(BuildContext context, SavingGoal goal) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: _AddContributionSheet(goal: goal),
      ),
    );
  }

  Future<bool?> _confirmArchive(BuildContext context, SavingGoalProgress goal) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive goal?'),
        content: Text(
          'Archive ${goal.goal.name}? Contributions will stay saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

class _GoalMetric extends StatelessWidget {
  const _GoalMetric({required this.label, required this.value});

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

class _AddGoalSheet extends ConsumerStatefulWidget {
  const _AddGoalSheet();

  @override
  ConsumerState<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends ConsumerState<_AddGoalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime? _targetDate;
  bool _countAsExpense = false;

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
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
                  'Add Saving Goal',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Goal name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a goal name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _targetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Target amount'),
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Enter an amount greater than zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                      initialDate: _targetDate ?? DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _targetDate = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _targetDate == null
                        ? 'Target date'
                        : '${_targetDate!.year}-${_targetDate!.month}-${_targetDate!.day}',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Count contributions as expenses'),
                  value: _countAsExpense,
                  onChanged: (value) => setState(() => _countAsExpense = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(labelText: 'Note'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saveGoal,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Goal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(financeRepositoryProvider)
        .addSavingGoal(
          name: _nameController.text.trim(),
          targetAmount: double.parse(_targetController.text),
          targetDate: _targetDate,
          countContributionAsExpense: _countAsExpense,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );

    ref.invalidate(dashboardProvider);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Saving goal saved')));
  }
}

class _AddContributionSheet extends ConsumerStatefulWidget {
  const _AddContributionSheet({required this.goal});

  final SavingGoal goal;

  @override
  ConsumerState<_AddContributionSheet> createState() =>
      _AddContributionSheetState();
}

class _AddContributionSheetState extends ConsumerState<_AddContributionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  int? _accountId;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountBalancesProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
        child: accounts.when(
          data: (items) => Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Contribution',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(widget.goal.name),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: _accountId,
                    decoration: const InputDecoration(labelText: 'Account'),
                    items: [
                      for (final account in items)
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
                    onPressed: _saveContribution,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Contribution'),
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

  Future<void> _saveContribution() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(financeRepositoryProvider)
        .addGoalContribution(
          goalId: widget.goal.id,
          accountId: _accountId!,
          amount: double.parse(_amountController.text),
          contributedAt: DateTime.now(),
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );

    ref.invalidate(dashboardProvider);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Contribution saved')));
  }
}
