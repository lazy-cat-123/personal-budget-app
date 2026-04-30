import '../../../database/app_database.dart';

class AccountBalance {
  const AccountBalance({required this.account, required this.balance});

  final Account account;
  final double balance;
}

class TransactionEntry {
  const TransactionEntry({
    required this.transaction,
    this.category,
    this.account,
    this.fromAccount,
    this.toAccount,
    this.tags = const [],
  });

  final BudgetTransaction transaction;
  final Category? category;
  final Account? account;
  final Account? fromAccount;
  final Account? toAccount;
  final List<Tag> tags;
}

class DashboardSummary {
  const DashboardSummary({
    required this.totalBalance,
    required this.monthIncome,
    required this.monthExpense,
    required this.remainingThisMonth,
    required this.lastSevenDayExpenses,
    required this.accounts,
    required this.recentTransactions,
    required this.savingGoals,
    required this.upcomingDebts,
    required this.quickAddTemplates,
    required this.upcomingRecurring,
  });

  final double totalBalance;
  final double monthIncome;
  final double monthExpense;
  final double remainingThisMonth;
  final List<DailyExpense> lastSevenDayExpenses;
  final List<AccountBalance> accounts;
  final List<TransactionEntry> recentTransactions;
  final List<SavingGoalProgress> savingGoals;
  final List<DebtProgress> upcomingDebts;
  final List<QuickAddTemplateEntry> quickAddTemplates;
  final List<RecurringTransactionEntry> upcomingRecurring;
}

class DailyExpense {
  const DailyExpense({required this.day, required this.amount});

  final DateTime day;
  final double amount;
}

class ReportsDashboard {
  const ReportsDashboard({
    required this.daily,
    required this.lastSevenDays,
    required this.monthly,
    required this.yearly,
  });

  final PeriodReport daily;
  final SevenDayReport lastSevenDays;
  final PeriodReport monthly;
  final PeriodReport yearly;
}

class PeriodReport {
  const PeriodReport({
    required this.title,
    required this.start,
    required this.end,
    required this.income,
    required this.expense,
    required this.expenseTrend,
    required this.incomeCategoryBreakdown,
    required this.categoryBreakdown,
    required this.topCategories,
    required this.transactions,
    required this.budgetUsage,
    required this.savingGoals,
    required this.upcomingDebts,
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final double income;
  final double expense;
  final List<DailyExpense> expenseTrend;
  final List<CategorySpending> incomeCategoryBreakdown;
  final List<CategorySpending> categoryBreakdown;
  final List<CategorySpending> topCategories;
  final List<TransactionEntry> transactions;
  final List<BudgetUsage> budgetUsage;
  final List<SavingGoalProgress> savingGoals;
  final List<DebtProgress> upcomingDebts;

  double get netAmount => income - expense;
}

class SevenDayReport {
  const SevenDayReport({
    required this.days,
    required this.totalExpense,
    required this.incomeCategoryBreakdown,
    required this.expenseCategoryBreakdown,
    required this.averageExpensePerDay,
    required this.highestSpendingDay,
    required this.previousSevenDayExpense,
  });

  final List<DailyExpense> days;
  final double totalExpense;
  final List<CategorySpending> incomeCategoryBreakdown;
  final List<CategorySpending> expenseCategoryBreakdown;
  final double averageExpensePerDay;
  final DailyExpense? highestSpendingDay;
  final double previousSevenDayExpense;

  double get expenseChange => totalExpense - previousSevenDayExpense;
}

class CategorySpending {
  const CategorySpending({
    required this.categoryName,
    required this.amount,
    required this.percentage,
  });

  final String categoryName;
  final double amount;
  final double percentage;
}

class BudgetUsage {
  const BudgetUsage({
    required this.budget,
    required this.category,
    required this.usedAmount,
    required this.remainingAmount,
    required this.usagePercentage,
    required this.status,
  });

  final Budget budget;
  final Category category;
  final double usedAmount;
  final double remainingAmount;
  final double usagePercentage;
  final BudgetStatus status;
}

enum BudgetStatus {
  ok,
  warning,
  over;

  String get label {
    return switch (this) {
      BudgetStatus.ok => 'OK',
      BudgetStatus.warning => 'Warning',
      BudgetStatus.over => 'Over',
    };
  }
}

class SavingGoalProgress {
  const SavingGoalProgress({
    required this.goal,
    required this.currentAmount,
    required this.remainingAmount,
    required this.progressPercentage,
    required this.contributions,
  });

  final SavingGoal goal;
  final double currentAmount;
  final double remainingAmount;
  final double progressPercentage;
  final List<GoalContribution> contributions;

  bool get isComplete => currentAmount >= goal.targetAmount;
}

class DebtProgress {
  const DebtProgress({
    required this.debt,
    required this.paidAmount,
    required this.remainingAmount,
    required this.progressPercentage,
    required this.payments,
  });

  final Debt debt;
  final double paidAmount;
  final double remainingAmount;
  final double progressPercentage;
  final List<DebtPayment> payments;

  bool get isComplete => paidAmount >= debt.totalAmount;
}

class QuickAddTemplateEntry {
  const QuickAddTemplateEntry({
    required this.template,
    this.category,
    this.account,
  });

  final QuickAddTemplate template;
  final Category? category;
  final Account? account;
}

class RecurringTransactionEntry {
  const RecurringTransactionEntry({
    required this.recurring,
    required this.category,
    required this.account,
  });

  final RecurringTransaction recurring;
  final Category category;
  final Account account;

  bool get isDue {
    final today = DateTime.now();
    final currentDay = DateTime(today.year, today.month, today.day);
    final dueDay = DateTime(
      recurring.nextDueDate.year,
      recurring.nextDueDate.month,
      recurring.nextDueDate.day,
    );
    return !dueDay.isAfter(currentDay);
  }
}

class AppSettings {
  const AppSettings({
    required this.currencyCode,
    required this.defaultAccountId,
    required this.dailyReminderEnabled,
    required this.dailyReminderHour,
    required this.dailyReminderMinute,
    required this.themeMode,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      currencyCode: 'THB',
      defaultAccountId: null,
      dailyReminderEnabled: false,
      dailyReminderHour: 20,
      dailyReminderMinute: 0,
      themeMode: 'system',
    );
  }

  final String currencyCode;
  final int? defaultAccountId;
  final bool dailyReminderEnabled;
  final int dailyReminderHour;
  final int dailyReminderMinute;
  final String themeMode;

  AppSettings copyWith({
    String? currencyCode,
    int? defaultAccountId,
    bool clearDefaultAccount = false,
    bool? dailyReminderEnabled,
    int? dailyReminderHour,
    int? dailyReminderMinute,
    String? themeMode,
  }) {
    return AppSettings(
      currencyCode: currencyCode ?? this.currencyCode,
      defaultAccountId: clearDefaultAccount
          ? null
          : defaultAccountId ?? this.defaultAccountId,
      dailyReminderEnabled:
          dailyReminderEnabled ?? this.dailyReminderEnabled,
      dailyReminderHour: dailyReminderHour ?? this.dailyReminderHour,
      dailyReminderMinute: dailyReminderMinute ?? this.dailyReminderMinute,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class CsvExportFile {
  const CsvExportFile({required this.fileName, required this.content});

  final String fileName;
  final String content;
}
