import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/money_format.dart';
import '../../../shared/providers/app_providers.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _typeFilter = 'all';
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _typeFilter,
                  decoration: const InputDecoration(
                    labelText: 'Transaction type',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'income', child: Text('Income')),
                    DropdownMenuItem(value: 'expense', child: Text('Expense')),
                    DropdownMenuItem(
                      value: 'transfer',
                      child: Text('Transfer'),
                    ),
                    DropdownMenuItem(
                      value: 'credit_card_payment',
                      child: Text('Card Pay'),
                    ),
                    DropdownMenuItem(
                      value: 'adjustment',
                      child: Text('Adjustment'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _typeFilter = value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(isFromDate: true),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _fromDate == null
                              ? 'From day'
                              : DateFormat.yMMMd().format(_fromDate!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(isFromDate: false),
                        icon: const Icon(Icons.event),
                        label: Text(
                          _toDate == null
                              ? 'To day'
                              : DateFormat.yMMMd().format(_toDate!),
                        ),
                      ),
                    ),
                    if (_fromDate != null || _toDate != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Clear date filter',
                        onPressed: () => setState(() {
                          _fromDate = null;
                          _toDate = null;
                        }),
                        icon: const Icon(Icons.clear),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: transactions.when(
              data: (items) {
                final filtered = items.where((entry) {
                  final tx = entry.transaction;
                  final txDay = DateTime(
                    tx.occurredAt.year,
                    tx.occurredAt.month,
                    tx.occurredAt.day,
                  );
                  final matchesType =
                      _typeFilter == 'all' || tx.type == _typeFilter;
                  final matchesFrom =
                      _fromDate == null || !txDay.isBefore(_fromDate!);
                  final matchesTo = _toDate == null || !txDay.isAfter(_toDate!);
                  return matchesType && matchesFrom && matchesTo;
                }).toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No matching transactions'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    final tx = entry.transaction;
                    final title =
                        tx.type == 'transfer' ||
                            tx.type == 'credit_card_payment'
                        ? '${entry.fromAccount?.name ?? 'Account'} to ${entry.toAccount?.name ?? 'Account'}'
                        : entry.category?.name ?? tx.type;
                    final subtitle = [
                      DateFormat.yMMMd().format(tx.occurredAt),
                      tx.paymentMethod?.replaceAll('_', ' '),
                      if (entry.tags.isNotEmpty)
                        entry.tags.map((tag) => '#${tag.name}').join(' '),
                    ].whereType<String>().join(' - ');

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Icon(_iconForType(tx.type))),
                      title: Text(title),
                      subtitle: Text(subtitle),
                      trailing: Text(formatMoney(tx.amount)),
                    );
                  },
                );
              },
              error: (error, stackTrace) => Center(child: Text('$error')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool isFromDate}) async {
    final currentValue = isFromDate ? _fromDate : _toDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = DateTime(2000);
    final lastDate = isFromDate ? (_toDate ?? today) : today;
    final earliestDate = isFromDate ? firstDate : (_fromDate ?? firstDate);
    final fallbackInitial = currentValue ?? (isFromDate ? (_toDate ?? today) : today);
    final initialDate = fallbackInitial.isBefore(earliestDate)
        ? earliestDate
        : fallbackInitial.isAfter(lastDate)
        ? lastDate
        : fallbackInitial;
    final picked = await showDatePicker(
      context: context,
      firstDate: earliestDate,
      lastDate: lastDate,
      initialDate: initialDate,
    );
    if (picked == null) return;

    final pickedDay = DateTime(picked.year, picked.month, picked.day);
    setState(() {
      if (isFromDate) {
        _fromDate = pickedDay;
        if (_toDate != null && _toDate!.isBefore(pickedDay)) {
          _toDate = pickedDay;
        }
      } else {
        _toDate = pickedDay;
        if (_fromDate != null && _fromDate!.isAfter(pickedDay)) {
          _fromDate = pickedDay;
        }
      }
    });
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'income' => Icons.south_west,
      'expense' => Icons.north_east,
      'transfer' => Icons.swap_horiz,
      'credit_card_payment' => Icons.credit_card,
      _ => Icons.receipt_long,
    };
  }
}
