import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/money_format.dart';
import '../../finance/domain/finance_models.dart';
import '../../../shared/providers/app_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Personal Budget')),
      body: summary.when(
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _BalanceCard(
              total: data.totalBalance,
              income: data.monthIncome,
              expense: data.monthExpense,
              remaining: data.remainingThisMonth,
            ),
            const SizedBox(height: 12),
            _QuickAddPreview(templates: data.quickAddTemplates),
            const SizedBox(height: 12),
            _ExpenseChart(data: data.lastSevenDayExpenses),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Accounts',
              child: Column(
                children: [
                  for (final account in data.accounts)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(account.account.name),
                      subtitle: Text(account.account.type.replaceAll('_', ' ')),
                      trailing: Text(formatMoney(account.balance)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Recent Transactions',
              child: Column(
                children: [
                  if (data.recentTransactions.isEmpty)
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('No transactions yet'),
                    ),
                  for (final entry in data.recentTransactions)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        entry.category?.name ?? entry.transaction.type,
                      ),
                      subtitle: Text(
                        DateFormat.yMMMd().format(entry.transaction.occurredAt),
                      ),
                      trailing: Text(formatMoney(entry.transaction.amount)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SavingGoalPreview(goals: data.savingGoals),
            const SizedBox(height: 12),
            _DebtPreview(debts: data.upcomingDebts),
            const SizedBox(height: 12),
            _RecurringPreview(items: data.upcomingRecurring),
            const SizedBox(height: 12),
            const _RequirementPreview(),
          ],
        ),
        error: (error, stackTrace) =>
            Center(child: Text('Could not load dashboard: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.total,
    required this.income,
    required this.expense,
    required this.remaining,
  });

  final double total;
  final double income;
  final double expense;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Balance',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Text(
              formatMoney(total),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Metric(label: 'Income', value: income),
                ),
                Expanded(
                  child: _Metric(label: 'Expense', value: expense),
                ),
                Expanded(
                  child: _Metric(label: 'Remaining', value: remaining),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(formatMoney(value), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _ExpenseChart extends StatelessWidget {
  const _ExpenseChart({required this.data});

  final List data;

  @override
  Widget build(BuildContext context) {
    final maxAmount = data.fold<double>(
      1,
      (max, item) => item.amount > max ? item.amount : max,
    );

    return _SectionCard(
      title: '7-Day Expenses',
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => const Color(0xFFF4FBF7),
                tooltipBorder: const BorderSide(color: Color(0xFFB8D7CB)),
                tooltipBorderRadius: BorderRadius.circular(8),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    formatMoney(rod.toY),
                    const TextStyle(
                      color: Color(0xFF0F5D4F),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  );
                },
              ),
            ),
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= data.length) {
                      return const SizedBox.shrink();
                    }
                    return Text(DateFormat.E().format(data[index].day));
                  },
                ),
              ),
            ),
            maxY: maxAmount * 1.2,
            barGroups: [
              for (var i = 0; i < data.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: data[i].amount,
                      width: 14,
                      color: const Color(0xFF0F5D4F),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAddPreview extends ConsumerWidget {
  const _QuickAddPreview({required this.templates});

  final List<QuickAddTemplateEntry> templates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SectionCard(
      title: 'Quick Add',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (templates.isEmpty)
            const Text('No templates yet. Add templates from More.'),
          for (final entry in templates)
            ActionChip(
              avatar: Icon(
                entry.template.transactionType == 'income'
                    ? Icons.south_west
                    : Icons.north_east,
                size: 18,
              ),
              label: Text(entry.template.name),
              onPressed: () async {
                await ref
                    .read(financeRepositoryProvider)
                    .useQuickAddTemplate(
                      templateId: entry.template.id,
                      amount: entry.template.defaultAmount,
                    );
                ref.invalidate(dashboardProvider);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${entry.template.name} added')),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _SavingGoalPreview extends StatelessWidget {
  const _SavingGoalPreview({required this.goals});

  final List<SavingGoalProgress> goals;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Saving Goals',
      child: Column(
        children: [
          if (goals.isEmpty)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('No saving goals yet'),
            ),
          for (final goal in goals)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(goal.goal.name),
              subtitle: LinearProgressIndicator(
                value: goal.progressPercentage.clamp(0, 1).toDouble(),
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              ),
              trailing: Text(formatMoney(goal.currentAmount)),
            ),
        ],
      ),
    );
  }
}

class _DebtPreview extends StatelessWidget {
  const _DebtPreview({required this.debts});

  final List<DebtProgress> debts;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Upcoming Debts',
      child: Column(
        children: [
          if (debts.isEmpty)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('No upcoming debt due dates'),
            ),
          for (final debt in debts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(debt.debt.name),
              subtitle: Text(
                debt.debt.dueDate == null
                    ? ''
                    : 'Due ${debt.debt.dueDate!.year}-${debt.debt.dueDate!.month}-${debt.debt.dueDate!.day}',
              ),
              trailing: Text(formatMoney(debt.remainingAmount)),
            ),
        ],
      ),
    );
  }
}

class _RecurringPreview extends StatelessWidget {
  const _RecurringPreview({required this.items});

  final List<RecurringTransactionEntry> items;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Recurring Due Soon',
      child: Column(
        children: [
          if (items.isEmpty)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('No recurring items due soon'),
            ),
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                item.recurring.transactionType == 'income'
                    ? Icons.south_west
                    : Icons.north_east,
              ),
              title: Text(item.recurring.name),
              subtitle: Text(
                'Due ${item.recurring.nextDueDate.year}-${item.recurring.nextDueDate.month}-${item.recurring.nextDueDate.day}',
              ),
              trailing: Text(formatMoney(item.recurring.defaultAmount)),
            ),
        ],
      ),
    );
  }
}

class _RequirementPreview extends StatelessWidget {
  const _RequirementPreview();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
      title: 'Next Phase Placeholders',
      child: Text(
        'Full CSV export and settings are prepared in navigation for later roadmap phases.',
      ),
    );
  }
}
