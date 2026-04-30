import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/money_format.dart';
import '../../finance/domain/finance_models.dart';
import '../../../shared/providers/app_providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsDashboardProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reports'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Today'),
              Tab(text: '7 Days'),
              Tab(text: 'Month'),
              Tab(text: 'Year'),
            ],
          ),
        ),
        body: reports.when(
          data: (data) => TabBarView(
            children: [
              _PeriodReportView(report: data.daily),
              _SevenDayReportView(report: data.lastSevenDays),
              _PeriodReportView(report: data.monthly),
              _PeriodReportView(report: data.yearly),
            ],
          ),
          error: (error, stackTrace) =>
              Center(child: Text('Could not load reports: $error')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _PeriodReportView extends StatelessWidget {
  const _PeriodReportView({required this.report});

  final PeriodReport report;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCard(report: report),
        if (report.expenseTrend.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ExpenseTrendChart(
            title: report.title == 'This Year'
                ? 'Yearly Expense Trend'
                : 'Monthly Expense Trend',
            items: report.expenseTrend,
            labelType: report.title == 'This Year'
                ? _TrendLabelType.year
                : _TrendLabelType.month,
          ),
        ],
        const SizedBox(height: 12),
        _CategoryChart(
          title: 'Spending by Category',
          emptyText: 'No expense data for this period',
          items: report.categoryBreakdown,
        ),
        const SizedBox(height: 12),
        _CategoryChart(
          title: 'Receiving by Category',
          emptyText: 'No income data for this period',
          items: report.incomeCategoryBreakdown,
        ),
        const SizedBox(height: 12),
        _TopCategories(items: report.topCategories),
        const SizedBox(height: 12),
        _BudgetUsagePreview(items: report.budgetUsage),
        const SizedBox(height: 12),
        _SavingGoalPreview(goals: report.savingGoals),
        const SizedBox(height: 12),
        _UpcomingDebtPreview(debts: report.upcomingDebts),
        const SizedBox(height: 12),
        _RecentTransactions(entries: report.transactions),
      ],
    );
  }
}

class _SevenDayReportView extends StatelessWidget {
  const _SevenDayReportView({required this.report});

  final SevenDayReport report;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Last 7 Days',
          child: Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Expense',
                  value: formatMoney(report.totalExpense),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Daily Avg',
                  value: formatMoney(report.averageExpensePerDay),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Vs Previous',
                  value: formatMoney(report.expenseChange),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ExpenseTrendChart(
          title: 'Expense Trend',
          items: report.days,
          labelType: _TrendLabelType.weekday,
        ),
        const SizedBox(height: 12),
        _CategoryChart(
          title: 'Spending by Category',
          emptyText: 'No expense data for this period',
          items: report.expenseCategoryBreakdown,
        ),
        const SizedBox(height: 12),
        _CategoryChart(
          title: 'Receiving by Category',
          emptyText: 'No income data for this period',
          items: report.incomeCategoryBreakdown,
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Highest Spending Day',
          child: report.highestSpendingDay == null
              ? const Text('No expense data yet')
              : ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.trending_up),
                  title: Text(
                    DateFormat.yMMMd().format(report.highestSpendingDay!.day),
                  ),
                  trailing: Text(formatMoney(report.highestSpendingDay!.amount)),
                ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.report});

  final PeriodReport report;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: report.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${DateFormat.yMMMd().format(report.start)} - ${DateFormat.yMMMd().format(report.end.subtract(const Duration(days: 1)))}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Metric(label: 'Income', value: formatMoney(report.income)),
              ),
              Expanded(
                child: _Metric(
                  label: 'Expense',
                  value: formatMoney(report.expense),
                ),
              ),
              Expanded(
                child: _Metric(label: 'Net', value: formatMoney(report.netAmount)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryChart extends StatefulWidget {
  const _CategoryChart({
    required this.title,
    required this.emptyText,
    required this.items,
  });

  final String title;
  final String emptyText;
  final List<CategorySpending> items;

  @override
  State<_CategoryChart> createState() => _CategoryChartState();
}

class _CategoryChartState extends State<_CategoryChart> {
  static const _sliceColors = [
    Color(0xFF0F5D4F),
    Color(0xFF2E8B57),
    Color(0xFF78A083),
    Color(0xFF1F7A8C),
    Color(0xFFD8A23A),
    Color(0xFFB85C38),
    Color(0xFF6F5FA8),
    Color(0xFF475569),
  ];

  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return _SectionCard(
        title: widget.title,
        child: Text(widget.emptyText),
      );
    }

    final visibleItems = widget.items.take(6).toList();
    final selectedItem =
        _touchedIndex >= 0 && _touchedIndex < visibleItems.length
        ? visibleItems[_touchedIndex]
        : visibleItems.first;
    final selectedColor = _sliceColors[
        (_touchedIndex >= 0 ? _touchedIndex : 0) % _sliceColors.length];

    return _SectionCard(
      title: widget.title,
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    final section = response?.touchedSection;
                    if (!event.isInterestedForInteractions ||
                        section == null ||
                        section.touchedSectionIndex < 0) {
                      return;
                    }

                    final index = section.touchedSectionIndex;
                    if (index < visibleItems.length) {
                      setState(() => _touchedIndex = index);
                    }
                  },
                ),
                sectionsSpace: 2,
                centerSpaceRadius: 38,
                sections: [
                  for (var i = 0; i < visibleItems.length; i++)
                    PieChartSectionData(
                      color: _sliceColors[i % _sliceColors.length],
                      value: visibleItems[i].amount,
                      title: '${(visibleItems[i].percentage * 100).round()}%',
                      radius: i == _touchedIndex ? 82 : 72,
                      titleStyle: TextStyle(
                        fontSize: i == _touchedIndex ? 14 : 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: selectedColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.pie_chart, color: selectedColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedItem.categoryName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        '${formatMoney(selectedItem.amount)} • ${(selectedItem.percentage * 100).toStringAsFixed(1)}%',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < visibleItems.length; i++)
            _CategoryLegendRow(
              item: visibleItems[i],
              color: _sliceColors[i % _sliceColors.length],
              isSelected: i == _touchedIndex,
              onTap: () => setState(() => _touchedIndex = i),
            ),
        ],
      ),
    );
  }
}

class _CategoryLegendRow extends StatelessWidget {
  const _CategoryLegendRow({
    required this.item,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final CategorySpending item;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.categoryName,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            Text(
              '${formatMoney(item.amount)}  ${(item.percentage * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

enum _TrendLabelType { weekday, month, year }

class _ExpenseTrendChart extends StatelessWidget {
  const _ExpenseTrendChart({
    required this.title,
    required this.items,
    required this.labelType,
  });

  final String title;
  final List<DailyExpense> items;
  final _TrendLabelType labelType;

  @override
  Widget build(BuildContext context) {
    final maxAmount = items.fold<double>(
      1,
      (max, item) => item.amount > max ? item.amount : max,
    );

    return _SectionCard(
      title: title,
      child: SizedBox(
        height: 190,
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
            maxY: maxAmount * 1.2,
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
                    if (index < 0 || index >= items.length) {
                      return const SizedBox.shrink();
                    }
                    return Text(_formatTrendLabel(items[index].day));
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < items.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: items[i].amount,
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

  String _formatTrendLabel(DateTime value) {
    return switch (labelType) {
      _TrendLabelType.weekday => DateFormat.E().format(value),
      _TrendLabelType.month => DateFormat.MMM().format(value),
      _TrendLabelType.year => DateFormat.y().format(value),
    };
  }
}

class _TopCategories extends StatelessWidget {
  const _TopCategories({required this.items});

  final List<CategorySpending> items;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Top Categories',
      child: Column(
        children: [
          if (items.isEmpty)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('No category spending yet'),
            ),
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.categoryName),
              subtitle: LinearProgressIndicator(
                value: item.percentage.clamp(0, 1),
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              ),
              trailing: Text(formatMoney(item.amount)),
            ),
        ],
      ),
    );
  }
}

class _BudgetUsagePreview extends StatelessWidget {
  const _BudgetUsagePreview({required this.items});

  final List<BudgetUsage> items;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Budget Usage',
      child: Column(
        children: [
          if (items.isEmpty)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('No active budgets'),
            ),
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.category.name),
              subtitle: Text(item.status.label),
              trailing: Text(formatMoney(item.remainingAmount)),
            ),
        ],
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
      title: 'Saving Goal Progress',
      child: Column(
        children: [
          if (goals.isEmpty)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('No saving goals'),
            ),
          for (final goal in goals)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(goal.goal.name),
              subtitle: LinearProgressIndicator(
                value: goal.progressPercentage.clamp(0, 1),
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

class _UpcomingDebtPreview extends StatelessWidget {
  const _UpcomingDebtPreview({required this.debts});

  final List<DebtProgress> debts;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Debt Due Soon',
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
                    : DateFormat.yMMMd().format(debt.debt.dueDate!),
              ),
              trailing: Text(formatMoney(debt.remainingAmount)),
            ),
        ],
      ),
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({required this.entries});

  final List<TransactionEntry> entries;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Recent Activity',
      child: Column(
        children: [
          if (entries.isEmpty)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('No transactions in this period'),
            ),
          for (final entry in entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                entry.transaction.type == 'income'
                    ? Icons.south_west
                    : Icons.north_east,
              ),
              title: Text(entry.category?.name ?? entry.transaction.type),
              subtitle: Text(DateFormat.yMMMd().format(entry.transaction.occurredAt)),
              trailing: Text(formatMoney(entry.transaction.amount)),
            ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

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
