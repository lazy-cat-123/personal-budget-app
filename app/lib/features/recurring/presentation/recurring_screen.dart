import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/finance/domain/finance_models.dart';
import '../../../shared/providers/app_providers.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurring = ref.watch(recurringTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Transactions')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRecurringSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Recurring'),
      ),
      body: recurring.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No recurring transactions yet. Add reminders for repeated bills or income.',
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _RecurringCard(entry: items[index]),
          );
        },
        error: (error, stackTrace) => Center(child: Text('$error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _showRecurringSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: const _AddRecurringSheet(),
      ),
    );
  }
}

class _RecurringCard extends ConsumerWidget {
  const _RecurringCard({required this.entry});

  final RecurringTransactionEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPaused = entry.recurring.status == 'paused';

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          entry.recurring.transactionType == 'income'
              ? Icons.south_west
              : Icons.north_east,
        ),
        title: Text(entry.recurring.name),
        subtitle: Text(
          [
            entry.category.name,
            entry.account.name,
            '${entry.recurring.frequency} - due ${_dateLabel(entry.recurring.nextDueDate)}',
            if (isPaused) 'Paused',
          ].join(' - '),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            final repository = ref.read(financeRepositoryProvider);
            final notifications = ref.read(notificationServiceProvider);
            if (value == 'confirm') {
              _showConfirmSheet(context, entry);
            } else if (value == 'edit') {
              _showEditSheet(context, entry);
            } else if (value == 'pause') {
              await repository.pauseRecurringTransaction(entry.recurring.id);
              await notifications.cancelRecurringReminder(entry.recurring.id);
              _invalidateRecurringDependents(ref);
            } else if (value == 'resume') {
              await repository.resumeRecurringTransaction(entry.recurring.id);
              await notifications.scheduleRecurringReminder(
                id: entry.recurring.id,
                title: entry.recurring.name,
                body:
                    'Recurring ${entry.recurring.transactionType} is due soon',
                dueDate: entry.recurring.nextDueDate,
                reminderBeforeDays: entry.recurring.reminderBeforeDays,
              );
              _invalidateRecurringDependents(ref);
            } else if (value == 'delete') {
              final confirmed = await _confirmDelete(context);
              if (confirmed != true) return;
              await repository.archiveRecurringTransaction(entry.recurring.id);
              await notifications.cancelRecurringReminder(entry.recurring.id);
              _invalidateRecurringDependents(ref);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'confirm',
              child: Text('Create transaction'),
            ),
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(
              value: isPaused ? 'resume' : 'pause',
              child: Text(isPaused ? 'Resume' : 'Pause'),
            ),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  static String _dateLabel(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  void _showEditSheet(BuildContext context, RecurringTransactionEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: _AddRecurringSheet(entry: entry),
      ),
    );
  }

  void _showConfirmSheet(
    BuildContext context,
    RecurringTransactionEntry entry,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: _ConfirmRecurringSheet(entry: entry),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete recurring item?'),
        content: Text('Delete ${entry.recurring.name}?'),
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
  }
}

class _AddRecurringSheet extends ConsumerStatefulWidget {
  const _AddRecurringSheet({this.entry});

  final RecurringTransactionEntry? entry;

  @override
  ConsumerState<_AddRecurringSheet> createState() => _AddRecurringSheetState();
}

class _AddRecurringSheetState extends ConsumerState<_AddRecurringSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _type = 'expense';
  String _frequency = 'monthly';
  int _reminderBeforeDays = 1;
  int? _categoryId;
  int? _accountId;
  DateTime _nextDueDate = DateTime.now();
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    if (entry == null) return;
    _nameController.text = entry.recurring.name;
    _amountController.text = entry.recurring.defaultAmount.toStringAsFixed(2);
    _noteController.text = entry.recurring.note ?? '';
    _type = entry.recurring.transactionType;
    _frequency = entry.recurring.frequency;
    _reminderBeforeDays = entry.recurring.reminderBeforeDays;
    _categoryId = entry.recurring.categoryId;
    _accountId = entry.recurring.accountId;
    _nextDueDate = entry.recurring.nextDueDate;
    _endDate = entry.recurring.endDate;
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
                      widget.entry == null ? 'Add Recurring' : 'Edit Recurring',
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
                      decoration: const InputDecoration(labelText: 'Name'),
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
                    DropdownButtonFormField<String>(
                      initialValue: _frequency,
                      decoration: const InputDecoration(labelText: 'Frequency'),
                      items: const [
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text('Weekly'),
                        ),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('Monthly'),
                        ),
                        DropdownMenuItem(
                          value: 'yearly',
                          child: Text('Yearly'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _frequency = value);
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
                              initialDate: _nextDueDate,
                            );
                            if (picked != null) {
                              setState(() => _nextDueDate = picked);
                            }
                          },
                          icon: const Icon(Icons.event),
                          label: Text('Due ${_dateLabel(_nextDueDate)}'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              initialDate: _endDate ?? _nextDueDate,
                            );
                            if (picked != null) {
                              setState(() => _endDate = picked);
                            }
                          },
                          icon: const Icon(Icons.event_available),
                          label: Text(
                            _endDate == null
                                ? 'End date'
                                : 'End ${_dateLabel(_endDate!)}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Remind $_reminderBeforeDays day(s) before'),
                    Slider(
                      value: _reminderBeforeDays.toDouble(),
                      min: 0,
                      max: 14,
                      divisions: 14,
                      label: '$_reminderBeforeDays',
                      onChanged: (value) =>
                          setState(() => _reminderBeforeDays = value.round()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteController,
                      decoration: const InputDecoration(labelText: 'Note'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saveRecurring,
                      icon: const Icon(Icons.save),
                      label: Text(
                        widget.entry == null
                            ? 'Save Recurring'
                            : 'Update Recurring',
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

  String _dateLabel(DateTime date) => '${date.year}-${date.month}-${date.day}';

  Future<void> _saveRecurring() async {
    if (!_formKey.currentState!.validate()) return;
    final repository = ref.read(financeRepositoryProvider);
    final notifications = ref.read(notificationServiceProvider);
    final entry = widget.entry;

    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();
    final id = entry == null
        ? await repository.addRecurringTransaction(
            name: _nameController.text.trim(),
            transactionType: _type,
            categoryId: _categoryId!,
            accountId: _accountId!,
            defaultAmount: double.parse(_amountController.text),
            frequency: _frequency,
            nextDueDate: _nextDueDate,
            endDate: _endDate,
            reminderBeforeDays: _reminderBeforeDays,
            note: note,
          )
        : entry.recurring.id;

    if (entry != null) {
      await repository.updateRecurringTransaction(
        recurringId: entry.recurring.id,
        name: _nameController.text.trim(),
        transactionType: _type,
        categoryId: _categoryId!,
        accountId: _accountId!,
        defaultAmount: double.parse(_amountController.text),
        frequency: _frequency,
        nextDueDate: _nextDueDate,
        endDate: _endDate,
        reminderBeforeDays: _reminderBeforeDays,
        note: note,
      );
    }

    await notifications.scheduleRecurringReminder(
      id: id,
      title: _nameController.text.trim(),
      body: 'Recurring $_type is due soon',
      dueDate: _nextDueDate,
      reminderBeforeDays: _reminderBeforeDays,
    );

    _invalidateRecurringDependents(ref);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          entry == null ? 'Recurring item saved' : 'Recurring item updated',
        ),
      ),
    );
  }
}

class _ConfirmRecurringSheet extends ConsumerStatefulWidget {
  const _ConfirmRecurringSheet({required this.entry});

  final RecurringTransactionEntry entry;

  @override
  ConsumerState<_ConfirmRecurringSheet> createState() =>
      _ConfirmRecurringSheetState();
}

class _ConfirmRecurringSheetState
    extends ConsumerState<_ConfirmRecurringSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.entry.recurring.defaultAmount.toStringAsFixed(2),
    );
    _noteController = TextEditingController(
      text: widget.entry.recurring.note ?? '',
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
                widget.entry.recurring.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.entry.category.name} - ${widget.entry.account.name}',
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
                onPressed: _confirm,
                icon: const Icon(Icons.check),
                label: const Text('Create Transaction'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) return;
    final repository = ref.read(financeRepositoryProvider);
    final notifications = ref.read(notificationServiceProvider);
    await repository.confirmRecurringTransaction(
      recurringId: widget.entry.recurring.id,
      amount: double.parse(_amountController.text),
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    final updated = (await repository.watchRecurringTransactions().first)
        .where((item) => item.recurring.id == widget.entry.recurring.id)
        .firstOrNull;
    if (updated != null && updated.recurring.status == 'active') {
      await notifications.scheduleRecurringReminder(
        id: updated.recurring.id,
        title: updated.recurring.name,
        body: 'Recurring ${updated.recurring.transactionType} is due soon',
        dueDate: updated.recurring.nextDueDate,
        reminderBeforeDays: updated.recurring.reminderBeforeDays,
      );
    } else {
      await notifications.cancelRecurringReminder(widget.entry.recurring.id);
    }

    _invalidateRecurringDependents(ref);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Transaction created')));
  }
}

void _invalidateRecurringDependents(WidgetRef ref) {
  ref.invalidate(recurringTransactionsProvider);
  ref.invalidate(transactionsProvider);
  ref.invalidate(accountBalancesProvider);
  ref.invalidate(dashboardProvider);
  ref.invalidate(reportsDashboardProvider);
  ref.invalidate(budgetUsageProvider);
}
