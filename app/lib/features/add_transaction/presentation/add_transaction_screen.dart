import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../shared/providers/app_providers.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _type = 'expense';
  String _paymentMethod = 'cash';
  DateTime _date = DateTime.now();
  int? _accountId;
  int? _fromAccountId;
  int? _toAccountId;
  int? _categoryId;
  final Set<int> _tagIds = {};

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountBalancesProvider);
    final appSettings = ref.watch(appSettingsProvider).value;
    final categories = ref.watch(
      _type == 'income' ? incomeCategoriesProvider : expenseCategoriesProvider,
    );
    final tags = ref.watch(tagsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Transaction')),
      body: accounts.when(
        data: (accountBalances) => categories.when(
          data: (categoryItems) => tags.when(
            data: (tagItems) {
              final accountItems = accountBalances
                  .map((item) => item.account)
                  .toList();
              final defaultAccountId = accountItems.any(
                (account) => account.id == appSettings?.defaultAccountId,
              )
                  ? appSettings?.defaultAccountId
                  : null;
              return _TransactionForm(
                formKey: _formKey,
                amountController: _amountController,
                noteController: _noteController,
                type: _type,
                paymentMethod: _paymentMethod,
                date: _date,
                accounts: accountItems,
                categories: categoryItems,
                tags: tagItems,
                accountId: _accountId ?? defaultAccountId,
                fromAccountId: _fromAccountId,
                toAccountId: _toAccountId,
                categoryId: _categoryId,
                tagIds: _tagIds,
                onTypeChanged: (value) => setState(() {
                  _type = value;
                  _categoryId = null;
                }),
                onPaymentMethodChanged: (value) =>
                    setState(() => _paymentMethod = value),
                onDateChanged: (value) => setState(() => _date = value),
                onAccountChanged: (value) => setState(() => _accountId = value),
                onFromAccountChanged: (value) =>
                    setState(() => _fromAccountId = value),
                onToAccountChanged: (value) =>
                    setState(() => _toAccountId = value),
                onCategoryChanged: (value) =>
                    setState(() => _categoryId = value),
                onTagToggled: (id, selected) => setState(() {
                  selected ? _tagIds.add(id) : _tagIds.remove(id);
                }),
                onSubmit: _save,
              );
            },
            error: (error, stackTrace) => Center(child: Text('$error')),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => Center(child: Text('$error')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => Center(child: Text('$error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text);
    final isTransfer = _type == 'transfer' || _type == 'credit_card_payment';
    final settings = ref.read(appSettingsProvider).value;
    final accountId = _accountId ?? settings?.defaultAccountId;

    await ref
        .read(financeRepositoryProvider)
        .addTransaction(
          type: _type,
          amount: amount,
          occurredAt: _date,
          accountId: isTransfer ? null : accountId,
          fromAccountId: isTransfer ? _fromAccountId : null,
          toAccountId: isTransfer ? _toAccountId : null,
          categoryId: isTransfer ? null : _categoryId,
          paymentMethod: isTransfer ? null : _paymentMethod,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          tagIds: _tagIds.toList(),
        );

    ref.invalidate(dashboardProvider);
    if (!mounted) return;
    _amountController.clear();
    _noteController.clear();
    setState(() => _tagIds.clear());
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Transaction saved')));
  }
}

class _TransactionForm extends StatelessWidget {
  const _TransactionForm({
    required this.formKey,
    required this.amountController,
    required this.noteController,
    required this.type,
    required this.paymentMethod,
    required this.date,
    required this.accounts,
    required this.categories,
    required this.tags,
    required this.accountId,
    required this.fromAccountId,
    required this.toAccountId,
    required this.categoryId,
    required this.tagIds,
    required this.onTypeChanged,
    required this.onPaymentMethodChanged,
    required this.onDateChanged,
    required this.onAccountChanged,
    required this.onFromAccountChanged,
    required this.onToAccountChanged,
    required this.onCategoryChanged,
    required this.onTagToggled,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController amountController;
  final TextEditingController noteController;
  final String type;
  final String paymentMethod;
  final DateTime date;
  final List<Account> accounts;
  final List<Category> categories;
  final List<Tag> tags;
  final int? accountId;
  final int? fromAccountId;
  final int? toAccountId;
  final int? categoryId;
  final Set<int> tagIds;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onPaymentMethodChanged;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<int?> onAccountChanged;
  final ValueChanged<int?> onFromAccountChanged;
  final ValueChanged<int?> onToAccountChanged;
  final ValueChanged<int?> onCategoryChanged;
  final void Function(int id, bool selected) onTagToggled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isTransfer = type == 'transfer' || type == 'credit_card_payment';

    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TypeChoice(
                value: 'income',
                label: 'Income',
                icon: Icons.south_west,
                selectedType: type,
                onSelected: onTypeChanged,
              ),
              _TypeChoice(
                value: 'expense',
                label: 'Expense',
                icon: Icons.north_east,
                selectedType: type,
                onSelected: onTypeChanged,
              ),
              _TypeChoice(
                value: 'transfer',
                label: 'Transfer',
                icon: Icons.swap_horiz,
                selectedType: type,
                onSelected: onTypeChanged,
              ),
              _TypeChoice(
                value: 'credit_card_payment',
                label: 'Card Pay',
                icon: Icons.credit_card,
                selectedType: type,
                onSelected: onTypeChanged,
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          if (isTransfer) ...[
            _AccountPicker(
              label: 'From account',
              accounts: accounts,
              value: fromAccountId,
              onChanged: onFromAccountChanged,
            ),
            const SizedBox(height: 12),
            _AccountPicker(
              label: 'To account',
              accounts: accounts,
              value: toAccountId,
              onChanged: onToAccountChanged,
            ),
          ] else ...[
            _AccountPicker(
              label: 'Account',
              accounts: accounts,
              value: accountId,
              onChanged: onAccountChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final category in categories)
                  DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  ),
              ],
              onChanged: onCategoryChanged,
              validator: (value) => value == null ? 'Choose a category' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: paymentMethod,
              decoration: const InputDecoration(labelText: 'Payment method'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                DropdownMenuItem(
                  value: 'debit_card',
                  child: Text('Debit card'),
                ),
                DropdownMenuItem(
                  value: 'credit_card',
                  child: Text('Credit card'),
                ),
                DropdownMenuItem(value: 'e_wallet', child: Text('E-wallet')),
              ],
              onChanged: (value) {
                if (value != null) {
                  onPaymentMethodChanged(value);
                }
              },
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                initialDate: date,
              );
              if (picked != null) {
                onDateChanged(
                  DateTime(
                    picked.year,
                    picked.month,
                    picked.day,
                    date.hour,
                    date.minute,
                  ),
                );
              }
            },
            icon: const Icon(Icons.calendar_today),
            label: Text('${date.year}-${date.month}-${date.day}'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: noteController,
            decoration: const InputDecoration(labelText: 'Note'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final tag in tags)
                FilterChip(
                  label: Text(tag.name),
                  selected: tagIds.contains(tag.id),
                  onSelected: (selected) => onTagToggled(tag.id, selected),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.save),
            label: const Text('Save Transaction'),
          ),
        ],
      ),
    );
  }
}

class _TypeChoice extends StatelessWidget {
  const _TypeChoice({
    required this.value,
    required this.label,
    required this.icon,
    required this.selectedType,
    required this.onSelected,
  });

  final String value;
  final String label;
  final IconData icon;
  final String selectedType;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      selected: selectedType == value,
      onSelected: (_) => onSelected(value),
    );
  }
}

class _AccountPicker extends StatelessWidget {
  const _AccountPicker({
    required this.label,
    required this.accounts,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<Account> accounts;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final account in accounts)
          DropdownMenuItem(value: account.id, child: Text(account.name)),
      ],
      onChanged: onChanged,
      validator: (value) => value == null ? 'Choose an account' : null,
    );
  }
}
