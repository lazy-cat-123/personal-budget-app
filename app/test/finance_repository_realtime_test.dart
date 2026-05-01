import 'package:app/database/app_database.dart';
import 'package:app/features/finance/data/finance_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repository writes refresh aggregate streams in real time', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = FinanceRepository(database);
    final now = DateTime.now();

    final accountAdded = _waitFor(
      repository.watchAccountBalances(),
      (items) => items.any((item) => item.account.name == 'Realtime Wallet'),
    );
    await repository.addAccount(
      name: 'Realtime Wallet',
      type: 'cash',
      initialBalance: 100,
      startDate: now,
    );
    final accounts = await accountAdded;
    final account = accounts
        .where((item) => item.account.name == 'Realtime Wallet')
        .single
        .account;

    final categories = await repository.watchCategories(type: 'expense').first;
    final category = categories.first;

    final transactionSeen = _waitFor(
      repository.watchDashboard(),
      (summary) =>
          summary.recentTransactions.any(
            (entry) => entry.transaction.note == 'Realtime expense',
          ) &&
          summary.monthExpense >= 25,
    );
    final reportSeen = _waitFor(
      repository.watchReportsDashboard(),
      (report) => report.daily.transactions.any(
        (entry) => entry.transaction.note == 'Realtime expense',
      ),
    );
    final balanceUpdated = _waitFor(
      repository.watchAccountBalances(),
      (items) => items.any(
        (item) => item.account.id == account.id && item.balance == 75,
      ),
    );
    await repository.addTransaction(
      type: 'expense',
      amount: 25,
      occurredAt: now,
      accountId: account.id,
      categoryId: category.id,
      note: 'Realtime expense',
    );
    expect((await transactionSeen).monthExpense, greaterThanOrEqualTo(25));
    expect((await reportSeen).daily.expense, greaterThanOrEqualTo(25));
    expect(
      (await balanceUpdated)
          .where((item) => item.account.id == account.id)
          .single
          .balance,
      75,
    );

    final savingGoalSeen = _waitFor(
      repository.watchSavingGoals(),
      (items) => items.any((item) => item.goal.name == 'Realtime Goal'),
    );
    await repository.addSavingGoal(
      name: 'Realtime Goal',
      targetAmount: 200,
      countContributionAsExpense: false,
    );
    final savingGoal = (await savingGoalSeen)
        .where((item) => item.goal.name == 'Realtime Goal')
        .single
        .goal;

    final contributionSeen = _waitFor(
      repository.watchSavingGoals(),
      (items) => items.any(
        (item) => item.goal.id == savingGoal.id && item.currentAmount == 50,
      ),
    );
    await repository.addGoalContribution(
      goalId: savingGoal.id,
      accountId: account.id,
      amount: 50,
      contributedAt: now,
    );
    expect((await contributionSeen).single.currentAmount, 50);

    final debtSeen = _waitFor(
      repository.watchDebts(),
      (items) => items.any((item) => item.debt.name == 'Realtime Debt'),
    );
    await repository.addDebt(
      type: 'i_owe',
      name: 'Realtime Debt',
      totalAmount: 80,
      startDate: now,
    );
    final debt = (await debtSeen)
        .where((item) => item.debt.name == 'Realtime Debt')
        .single
        .debt;

    final debtPaymentSeen = _waitFor(
      repository.watchDebts(),
      (items) => items.any(
        (item) => item.debt.id == debt.id && item.paidAmount == 30,
      ),
    );
    await repository.addDebtPayment(
      debtId: debt.id,
      accountId: account.id,
      amount: 30,
      paidAt: now,
    );
    expect((await debtPaymentSeen).single.paidAmount, 30);

    final templateSeen = _waitFor(
      repository.watchQuickAddTemplates(),
      (items) => items.any((item) => item.template.name == 'Realtime Template'),
    );
    await repository.addQuickAddTemplate(
      name: 'Realtime Template',
      transactionType: 'expense',
      categoryId: category.id,
      accountId: account.id,
      defaultAmount: 12,
    );
    expect((await templateSeen).single.template.defaultAmount, 12);

    final recurringSeen = _waitFor(
      repository.watchRecurringTransactions(),
      (items) => items.any((item) => item.recurring.name == 'Realtime Rent'),
    );
    await repository.addRecurringTransaction(
      name: 'Realtime Rent',
      transactionType: 'expense',
      categoryId: category.id,
      accountId: account.id,
      defaultAmount: 40,
      frequency: 'monthly',
      nextDueDate: now,
      reminderBeforeDays: 1,
    );
    expect((await recurringSeen).single.recurring.defaultAmount, 40);
  });
}

Future<T> _waitFor<T>(Stream<T> stream, bool Function(T value) test) {
  return stream.firstWhere(test).timeout(const Duration(seconds: 3));
}
