import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/money_format.dart';
import '../../../database/app_database.dart';
import '../../../features/finance/domain/finance_models.dart';
import '../../../shared/providers/app_providers.dart';

const _accountTypes = [
  ('cash', 'Cash'),
  ('bank_account', 'Bank account'),
  ('e_wallet', 'E-wallet'),
  ('debit_card', 'Debit card'),
  ('credit_card', 'Credit card'),
  ('saving_account', 'Saving account'),
  ('investment_account', 'Investment account'),
  ('other', 'Other'),
];

const _accountColors = [
  ('246B5F', 'Green'),
  ('0F5D4F', 'Dark green'),
  ('2F5F98', 'Blue'),
  ('8A6F2A', 'Gold'),
  ('8B3A3A', 'Red'),
  ('5A4B8B', 'Purple'),
  ('475569', 'Slate'),
];

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountBalancesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAccountSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Account'),
      ),
      body: accounts.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No active accounts. Add an account to begin.'),
              ),
            );
          }

          final total = items.fold<double>(
            0,
            (sum, item) => sum + item.balance,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _TotalBalanceCard(total: total, count: items.length),
              const SizedBox(height: 12),
              for (final item in items) ...[
                _AccountCard(
                  item: item,
                  onEdit: () => _showAccountSheet(context, item.account),
                  onAdjust: () => _showAdjustmentSheet(context, item.account),
                  onArchive: () => _confirmArchive(context, ref, item.account),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
        error: (error, stackTrace) => Center(child: Text('$error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _showAccountSheet(BuildContext context, [Account? account]) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: _AccountSheet(account: account),
      ),
    );
  }

  void _showAdjustmentSheet(BuildContext context, Account account) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: _AdjustmentSheet(account: account),
      ),
    );
  }

  Future<void> _confirmArchive(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive account?'),
        content: Text(
          'Archive ${account.name}? Existing transactions will remain.',
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
    await ref.read(financeRepositoryProvider).archiveAccount(account.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Account archived')));
  }
}

class _TotalBalanceCard extends StatelessWidget {
  const _TotalBalanceCard({required this.total, required this.count});

  final double total;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Account Balance',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    '$count active accounts',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              formatMoney(total),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.item,
    required this.onEdit,
    required this.onAdjust,
    required this.onArchive,
  });

  final AccountBalance item;
  final VoidCallback onEdit;
  final VoidCallback onAdjust;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final account = item.account;
    final color = _parseColor(account.colorHex);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color,
                  child: Icon(_iconForType(account.type), color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(_labelForType(account.type)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'adjust') onAdjust();
                    if (value == 'archive') onArchive();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                      value: 'adjust',
                      child: Text('Manual adjustment'),
                    ),
                    PopupMenuItem(value: 'archive', child: Text('Archive')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _AccountMetric(
                    label: 'Current',
                    value: formatMoney(item.balance),
                  ),
                ),
                Expanded(
                  child: _AccountMetric(
                    label: 'Initial',
                    value: formatMoney(account.initialBalance),
                  ),
                ),
                Expanded(
                  child: _AccountMetric(
                    label: 'Start',
                    value: DateFormat.yMMMd().format(account.startDate),
                  ),
                ),
              ],
            ),
            if (account.note != null && account.note!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(account.note!),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountMetric extends StatelessWidget {
  const _AccountMetric({required this.label, required this.value});

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

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet({this.account});

  final Account? account;

  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _noteController = TextEditingController();
  String _type = 'cash';
  String _colorHex = '246B5F';
  DateTime _startDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    if (account != null) {
      _nameController.text = account.name;
      _balanceController.text = account.initialBalance.toStringAsFixed(2);
      _noteController.text = account.note ?? '';
      _type = account.type;
      _colorHex = account.colorHex ?? '246B5F';
      _startDate = account.startDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
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
                  widget.account == null ? 'Add Account' : 'Edit Account',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Account name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter an account name'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Account type'),
                  items: [
                    for (final item in _accountTypes)
                      DropdownMenuItem(value: item.$1, child: Text(item.$2)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _type = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _balanceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Initial balance',
                  ),
                  validator: (value) =>
                      double.tryParse(value ?? '') == null
                      ? 'Enter a valid amount'
                      : null,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickStartDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat.yMMMd().format(_startDate)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _colorHex,
                  decoration: const InputDecoration(labelText: 'Color'),
                  items: [
                    for (final item in _accountColors)
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
                    widget.account == null ? 'Save Account' : 'Update Account',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _startDate,
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final note = _noteController.text.trim();
    final repository = ref.read(financeRepositoryProvider);
    final account = widget.account;

    if (account == null) {
      await repository.addAccount(
        name: _nameController.text.trim(),
        type: _type,
        initialBalance: double.parse(_balanceController.text),
        startDate: _startDate,
        colorHex: _colorHex,
        note: note.isEmpty ? null : note,
      );
    } else {
      await repository.updateAccount(
        accountId: account.id,
        name: _nameController.text.trim(),
        type: _type,
        initialBalance: double.parse(_balanceController.text),
        startDate: _startDate,
        colorHex: _colorHex,
        note: note.isEmpty ? null : note,
      );
    }

    ref.invalidate(dashboardProvider);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(account == null ? 'Account saved' : 'Account updated')),
    );
  }
}

class _AdjustmentSheet extends ConsumerStatefulWidget {
  const _AdjustmentSheet({required this.account});

  final Account account;

  @override
  ConsumerState<_AdjustmentSheet> createState() => _AdjustmentSheetState();
}

class _AdjustmentSheetState extends ConsumerState<_AdjustmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _date = DateTime.now();
  String _direction = 'increase';

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adjust ${widget.account.name}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'increase',
                      label: Text('Increase'),
                      icon: Icon(Icons.add),
                    ),
                    ButtonSegment(
                      value: 'decrease',
                      label: Text('Decrease'),
                      icon: Icon(Icons.remove),
                    ),
                  ],
                  selected: {_direction},
                  onSelectionChanged: (values) =>
                      setState(() => _direction = values.first),
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
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat.yMMMd().format(_date)),
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
                  icon: const Icon(Icons.tune),
                  label: const Text('Save Adjustment'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _date,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final rawAmount = double.parse(_amountController.text);
    final amount = _direction == 'increase' ? rawAmount : -rawAmount;
    final note = _noteController.text.trim();

    await ref.read(financeRepositoryProvider).addAccountAdjustment(
          accountId: widget.account.id,
          amount: amount,
          adjustedAt: _date,
          note: note.isEmpty ? null : note,
        );

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Balance adjustment saved')),
    );
  }
}

Color _parseColor(String? hex) {
  final value = hex == null || hex.isEmpty ? '246B5F' : hex;
  return Color(int.parse('FF$value', radix: 16));
}

String _labelForType(String type) {
  return _accountTypes
      .where((item) => item.$1 == type)
      .map((item) => item.$2)
      .firstOrNull ?? type.replaceAll('_', ' ');
}

IconData _iconForType(String type) {
  return switch (type) {
    'cash' => Icons.payments,
    'bank_account' => Icons.account_balance,
    'e_wallet' => Icons.account_balance_wallet,
    'debit_card' => Icons.credit_card,
    'credit_card' => Icons.credit_card,
    'saving_account' => Icons.savings,
    'investment_account' => Icons.trending_up,
    _ => Icons.wallet,
  };
}
