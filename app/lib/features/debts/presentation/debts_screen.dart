import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money_format.dart';
import '../../../database/app_database.dart';
import '../../../features/finance/domain/finance_models.dart';
import '../../../shared/providers/app_providers.dart';

class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debts = ref.watch(debtsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Debts / Installments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDebtSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Debt'),
      ),
      body: debts.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No debts yet. Add a debt or installment to track payments.',
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _DebtCard(progress: items[index]),
          );
        },
        error: (error, stackTrace) => Center(child: Text('$error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _showDebtSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: const _AddDebtSheet(),
      ),
    );
  }
}

class _DebtCard extends ConsumerWidget {
  const _DebtCard({required this.progress});

  final DebtProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final percent = (progress.progressPercentage * 100).clamp(0, 999).round();
    final progressValue = progress.progressPercentage.clamp(0, 1).toDouble();

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
                        progress.debt.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        _typeLabel(progress.debt.type),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Add payment',
                  icon: const Icon(Icons.payments),
                  onPressed: progress.isComplete
                      ? null
                      : () => _showPaymentSheet(context, progress.debt),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value != 'archive') return;
                    final confirmed = await _confirmArchive(context, progress);
                    if (confirmed != true || !context.mounted) return;
                    await ref
                        .read(financeRepositoryProvider)
                        .archiveDebt(progress.debt.id);
                    _invalidateDebtDependents(ref);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'archive', child: Text('Archive')),
                  ],
                ),
              ],
            ),
            if (progress.debt.personName != null &&
                progress.debt.personName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(progress.debt.personName!),
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
                  child: _DebtMetric(
                    label: 'Paid',
                    value: formatMoney(progress.paidAmount),
                  ),
                ),
                Expanded(
                  child: _DebtMetric(
                    label: 'Remaining',
                    value: formatMoney(progress.remainingAmount),
                  ),
                ),
                Expanded(
                  child: _DebtMetric(label: 'Progress', value: '$percent%'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Total ${formatMoney(progress.debt.totalAmount)}'),
            if (progress.debt.dueDate != null)
              Text(
                'Due ${_dateLabel(progress.debt.dueDate!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  static String _typeLabel(String type) {
    return switch (type) {
      'i_owe' => 'I owe',
      'owed_to_me' => 'Owed to me',
      'installment' => 'Installment',
      _ => type,
    };
  }

  static String _dateLabel(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  void _showPaymentSheet(BuildContext context, Debt debt) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: _AddDebtPaymentSheet(debt: debt),
      ),
    );
  }

  Future<bool?> _confirmArchive(BuildContext context, DebtProgress progress) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive debt?'),
        content: Text(
          'Archive ${progress.debt.name}? Payment history will remain saved.',
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

class _DebtMetric extends StatelessWidget {
  const _DebtMetric({required this.label, required this.value});

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

class _AddDebtSheet extends ConsumerStatefulWidget {
  const _AddDebtSheet();

  @override
  ConsumerState<_AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends ConsumerState<_AddDebtSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _personController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _type = 'i_owe';
  DateTime _startDate = DateTime.now();
  DateTime? _dueDate;

  @override
  void dispose() {
    _nameController.dispose();
    _personController.dispose();
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add Debt', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('I owe'),
                      selected: _type == 'i_owe',
                      onSelected: (_) => setState(() => _type = 'i_owe'),
                    ),
                    ChoiceChip(
                      label: const Text('Owed to me'),
                      selected: _type == 'owed_to_me',
                      onSelected: (_) => setState(() => _type = 'owed_to_me'),
                    ),
                    ChoiceChip(
                      label: const Text('Installment'),
                      selected: _type == 'installment',
                      onSelected: (_) => setState(() => _type = 'installment'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _typeDescription,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Debt name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _personController,
                  decoration: const InputDecoration(labelText: 'Person / shop'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Total amount'),
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Enter an amount greater than zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          initialDate: _startDate,
                        );
                        if (picked != null) {
                          setState(() => _startDate = picked);
                        }
                      },
                      icon: const Icon(Icons.event),
                      label: Text('Start ${_dateLabel(_startDate)}'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          initialDate: _dueDate ?? DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _dueDate = picked);
                        }
                      },
                      icon: const Icon(Icons.event_available),
                      label: Text(
                        _dueDate == null
                            ? 'Due date'
                            : 'Due ${_dateLabel(_dueDate!)}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(labelText: 'Note'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saveDebt,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Debt'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _dateLabel(DateTime date) => '${date.year}-${date.month}-${date.day}';

  String get _typeDescription {
    return switch (_type) {
      'i_owe' =>
        'Use this when you borrowed money or need to pay someone back. Payments are counted as expenses.',
      'owed_to_me' =>
        'Use this when someone borrowed from you. Payments received are counted as income.',
      'installment' =>
        'Use this for purchases paid over time. Each installment payment is counted as an expense.',
      _ => '',
    };
  }

  Future<void> _saveDebt() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(financeRepositoryProvider)
        .addDebt(
          type: _type,
          name: _nameController.text.trim(),
          personName: _personController.text.trim().isEmpty
              ? null
              : _personController.text.trim(),
          totalAmount: double.parse(_amountController.text),
          startDate: _startDate,
          dueDate: _dueDate,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );

    _invalidateDebtDependents(ref);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Debt saved')));
  }
}

class _AddDebtPaymentSheet extends ConsumerStatefulWidget {
  const _AddDebtPaymentSheet({required this.debt});

  final Debt debt;

  @override
  ConsumerState<_AddDebtPaymentSheet> createState() =>
      _AddDebtPaymentSheetState();
}

class _AddDebtPaymentSheetState extends ConsumerState<_AddDebtPaymentSheet> {
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
                    'Add Payment',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(widget.debt.name),
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
                    onPressed: _savePayment,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Payment'),
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

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(financeRepositoryProvider)
        .addDebtPayment(
          debtId: widget.debt.id,
          accountId: _accountId!,
          amount: double.parse(_amountController.text),
          paidAt: DateTime.now(),
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );

    _invalidateDebtDependents(ref);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Payment saved')));
  }
}

void _invalidateDebtDependents(WidgetRef ref) {
  ref.invalidate(debtsProvider);
  ref.invalidate(accountBalancesProvider);
  ref.invalidate(transactionsProvider);
  ref.invalidate(dashboardProvider);
  ref.invalidate(reportsDashboardProvider);
  ref.invalidate(budgetUsageProvider);
}
