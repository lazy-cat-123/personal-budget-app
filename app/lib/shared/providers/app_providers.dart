import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_service.dart';
import '../../database/app_database.dart';
import '../../features/finance/data/finance_repository.dart';
import '../../features/finance/domain/finance_models.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(ref.watch(databaseProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final dashboardProvider = StreamProvider<DashboardSummary>((ref) {
  return ref.watch(financeRepositoryProvider).watchDashboard();
});

final reportsDashboardProvider = StreamProvider<ReportsDashboard>((ref) {
  return ref.watch(financeRepositoryProvider).watchReportsDashboard();
});

final accountBalancesProvider = StreamProvider<List<AccountBalance>>((ref) {
  return ref.watch(financeRepositoryProvider).watchAccountBalances();
});

final incomeCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(financeRepositoryProvider).watchCategories(type: 'income');
});

final expenseCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(financeRepositoryProvider).watchCategories(type: 'expense');
});

final tagsProvider = StreamProvider<List<Tag>>((ref) {
  return ref.watch(financeRepositoryProvider).watchTags();
});

final appSettingsProvider = StreamProvider<AppSettings>((ref) {
  return ref.watch(financeRepositoryProvider).watchSettings();
});

final transactionsProvider = StreamProvider<List<TransactionEntry>>((ref) {
  return ref.watch(financeRepositoryProvider).watchTransactions();
});

final budgetUsageProvider = StreamProvider<List<BudgetUsage>>((ref) {
  return ref.watch(financeRepositoryProvider).watchBudgetUsage();
});

final savingGoalsProvider = StreamProvider<List<SavingGoalProgress>>((ref) {
  return ref.watch(financeRepositoryProvider).watchSavingGoals();
});

final debtsProvider = StreamProvider<List<DebtProgress>>((ref) {
  return ref.watch(financeRepositoryProvider).watchDebts();
});

final quickAddTemplatesProvider = StreamProvider<List<QuickAddTemplateEntry>>((
  ref,
) {
  return ref.watch(financeRepositoryProvider).watchQuickAddTemplates();
});

final recurringTransactionsProvider =
    StreamProvider<List<RecurringTransactionEntry>>((ref) {
      return ref.watch(financeRepositoryProvider).watchRecurringTransactions();
    });
