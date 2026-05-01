import 'package:csv/csv.dart';
import 'package:drift/drift.dart';

import '../../../database/app_database.dart';
import '../domain/finance_models.dart';

class FinanceRepository {
  FinanceRepository(this._db);

  final AppDatabase _db;

  Stream<List<AccountBalance>> watchAccountBalances() {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {
            _db.accounts,
            _db.budgetTransactions,
            _db.goalContributions,
            _db.debtPayments,
          },
        )
        .watch()
        .asyncMap((_) async {
          final accounts = await _db.select(_db.accounts).get();
          final transactions = await _db.select(_db.budgetTransactions).get();
          final contributions = await _db.select(_db.goalContributions).get();
          final debtPayments = await _db.select(_db.debtPayments).get();
          return accounts
              .where((account) => !account.isArchived)
              .map(
                (account) => AccountBalance(
                  account: account,
                  balance: _calculateBalance(
                    account,
                    transactions,
                    contributions,
                    debtPayments,
                  ),
                ),
              )
              .toList();
        });
  }

  Stream<List<Category>> watchCategories({String? type}) {
    final query = _db.select(_db.categories)
      ..where((tbl) => tbl.isArchived.equals(false));
    if (type != null) {
      query.where((tbl) => tbl.type.equals(type));
    }
    return query.watch();
  }

  Stream<List<Tag>> watchTags() {
    return (_db.select(
      _db.tags,
    )..where((tbl) => tbl.isArchived.equals(false))).watch();
  }

  Stream<AppSettings> watchSettings() {
    return _db
        .customSelect('SELECT 1', readsFrom: {_db.settings})
        .watch()
        .asyncMap((_) async {
          final rows = await _db.select(_db.settings).get();
          final values = {for (final row in rows) row.key: row.value};
          return _settingsFromMap(values);
        });
  }

  Stream<List<TransactionEntry>> watchTransactions() {
    return (_db.select(_db.budgetTransactions)..orderBy([
          (tbl) =>
              OrderingTerm(expression: tbl.occurredAt, mode: OrderingMode.desc),
        ]))
        .watch()
        .asyncMap(_hydrateTransactions);
  }

  Stream<List<BudgetUsage>> watchBudgetUsage() {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {_db.budgets, _db.budgetTransactions, _db.categories},
        )
        .watch()
        .asyncMap((_) async {
          final budgets = await _db.select(_db.budgets).get();
          final activeBudgets = budgets.where((budget) => !budget.isArchived);
          final categories = await _db.select(_db.categories).get();
          final transactions = await _db.select(_db.budgetTransactions).get();

          return [
            for (final budget in activeBudgets)
              if (categories
                      .where((item) => item.id == budget.categoryId)
                      .firstOrNull
                  case final category?)
                _calculateBudgetUsage(
                  budget: budget,
                  category: category,
                  transactions: transactions,
                ),
          ];
        });
  }

  Stream<List<SavingGoalProgress>> watchSavingGoals() {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {_db.savingGoals, _db.goalContributions},
        )
        .watch()
        .asyncMap((_) async {
          final goals = await _db.select(_db.savingGoals).get();
          final contributions = await _db.select(_db.goalContributions).get();
          return [
            for (final goal in goals.where((goal) => goal.status != 'archived'))
              _calculateSavingGoalProgress(goal, contributions),
          ];
        });
  }

  Stream<List<DebtProgress>> watchDebts() {
    return _db
        .customSelect('SELECT 1', readsFrom: {_db.debts, _db.debtPayments})
        .watch()
        .asyncMap((_) async {
          final debts = await _db.select(_db.debts).get();
          final payments = await _db.select(_db.debtPayments).get();
          return [
            for (final debt in debts.where((debt) => debt.status != 'archived'))
              _calculateDebtProgress(debt, payments),
          ];
        });
  }

  Stream<List<QuickAddTemplateEntry>> watchQuickAddTemplates() {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {_db.quickAddTemplates, _db.categories, _db.accounts},
        )
        .watch()
        .asyncMap((_) async {
          final templates =
              await (_db.select(_db.quickAddTemplates)
                    ..where((tbl) => tbl.isArchived.equals(false))
                    ..orderBy([
                      (tbl) => OrderingTerm(
                        expression: tbl.useCount,
                        mode: OrderingMode.desc,
                      ),
                      (tbl) => OrderingTerm(
                        expression: tbl.createdAt,
                        mode: OrderingMode.desc,
                      ),
                    ]))
                  .get();
          return _hydrateTemplates(templates);
        });
  }

  Stream<List<RecurringTransactionEntry>> watchRecurringTransactions() {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {_db.recurringTransactions, _db.categories, _db.accounts},
        )
        .watch()
        .asyncMap((_) async {
          final recurring =
              await (_db.select(_db.recurringTransactions)
                    ..where((tbl) => tbl.status.isNotIn(['archived']))
                    ..orderBy([
                      (tbl) => OrderingTerm(expression: tbl.nextDueDate),
                    ]))
                  .get();
          return _hydrateRecurring(recurring);
        });
  }

  Stream<DashboardSummary> watchDashboard() {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {
            _db.accounts,
            _db.budgetTransactions,
            _db.categories,
            _db.tags,
            _db.transactionTags,
            _db.savingGoals,
            _db.goalContributions,
            _db.debts,
            _db.debtPayments,
            _db.quickAddTemplates,
            _db.recurringTransactions,
          },
        )
        .watch()
        .asyncMap((_) async {
          final transactions =
              await (_db.select(_db.budgetTransactions)..orderBy([
                    (tbl) => OrderingTerm(
                      expression: tbl.occurredAt,
                      mode: OrderingMode.desc,
                    ),
                  ]))
                  .get();
          final entries = await _hydrateTransactions(transactions);
          final rawAccounts = await _db.select(_db.accounts).get();
          final contributions = await _db.select(_db.goalContributions).get();
          final debtPayments = await _db.select(_db.debtPayments).get();
          final accounts = rawAccounts
              .where((account) => !account.isArchived)
              .map(
                (account) => AccountBalance(
                  account: account,
                  balance: _calculateBalance(
                    account,
                    transactions,
                    contributions,
                    debtPayments,
                  ),
                ),
              )
              .toList();
          final now = DateTime.now();
          final monthStart = DateTime(now.year, now.month);
          final nextMonth = DateTime(now.year, now.month + 1);

          double monthIncome = 0;
          double monthExpense = 0;
          final rawGoals = await _db.select(_db.savingGoals).get();
          final savingGoals = [
            for (final goal in rawGoals.where(
              (goal) => goal.status != 'archived',
            ))
              _calculateSavingGoalProgress(goal, contributions),
          ];
          final rawDebts = await _db.select(_db.debts).get();
          final debts = [
            for (final debt in rawDebts.where(
              (debt) => debt.status != 'archived',
            ))
              _calculateDebtProgress(debt, debtPayments),
          ];
          final rawTemplates =
              await (_db.select(_db.quickAddTemplates)
                    ..where((tbl) => tbl.isArchived.equals(false))
                    ..orderBy([
                      (tbl) => OrderingTerm(
                        expression: tbl.useCount,
                        mode: OrderingMode.desc,
                      ),
                      (tbl) => OrderingTerm(
                        expression: tbl.createdAt,
                        mode: OrderingMode.desc,
                      ),
                    ]))
                  .get();
          final quickAddTemplates = await _hydrateTemplates(rawTemplates);
          final rawRecurring =
              await (_db.select(_db.recurringTransactions)
                    ..where((tbl) => tbl.status.isNotIn(['archived']))
                    ..orderBy([
                      (tbl) => OrderingTerm(expression: tbl.nextDueDate),
                    ]))
                  .get();
          final recurring = await _hydrateRecurring(rawRecurring);
          final lastSeven = List.generate(7, (index) {
            final day = DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(Duration(days: 6 - index));
            return DailyExpense(day: day, amount: 0);
          });
          final expenseByDay = {
            for (final item in lastSeven)
              DateTime(item.day.year, item.day.month, item.day.day): 0.0,
          };

          for (final entry in entries) {
            final tx = entry.transaction;
            final inMonth =
                !tx.occurredAt.isBefore(monthStart) &&
                tx.occurredAt.isBefore(nextMonth);
            if (inMonth && tx.type == 'income') {
              monthIncome += tx.amount;
            }
            if (inMonth && tx.type == 'expense') {
              monthExpense += tx.amount;
            }
            if (tx.type == 'expense') {
              final day = DateTime(
                tx.occurredAt.year,
                tx.occurredAt.month,
                tx.occurredAt.day,
              );
              if (expenseByDay.containsKey(day)) {
                expenseByDay[day] = expenseByDay[day]! + tx.amount;
              }
            }
          }

          for (final goal in savingGoals) {
            if (!goal.goal.countContributionAsExpense) continue;
            for (final contribution in goal.contributions) {
              if (contribution.transactionId != null) continue;
              final inMonth =
                  !contribution.contributedAt.isBefore(monthStart) &&
                  contribution.contributedAt.isBefore(nextMonth);
              if (inMonth) {
                monthExpense += contribution.amount;
              }
              final day = DateTime(
                contribution.contributedAt.year,
                contribution.contributedAt.month,
                contribution.contributedAt.day,
              );
              if (expenseByDay.containsKey(day)) {
                expenseByDay[day] = expenseByDay[day]! + contribution.amount;
              }
            }
          }

          return DashboardSummary(
            totalBalance: accounts.fold(0, (sum, item) => sum + item.balance),
            monthIncome: monthIncome,
            monthExpense: monthExpense,
            remainingThisMonth: monthIncome - monthExpense,
            lastSevenDayExpenses: [
              for (final item in lastSeven)
                DailyExpense(
                  day: item.day,
                  amount:
                      expenseByDay[DateTime(
                        item.day.year,
                        item.day.month,
                        item.day.day,
                      )] ??
                      0,
                ),
            ],
            accounts: accounts,
            recentTransactions: entries.take(5).toList(),
            savingGoals: savingGoals.take(3).toList(),
            upcomingDebts: _upcomingDebts(debts).take(3).toList(),
            quickAddTemplates: quickAddTemplates.take(5).toList(),
            upcomingRecurring: _upcomingRecurring(recurring).take(3).toList(),
          );
        });
  }

  Stream<ReportsDashboard> watchReportsDashboard() {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {
            _db.budgetTransactions,
            _db.categories,
            _db.accounts,
            _db.tags,
            _db.transactionTags,
            _db.budgets,
            _db.savingGoals,
            _db.goalContributions,
            _db.debts,
            _db.debtPayments,
          },
        )
        .watch()
        .asyncMap((_) async {
          final transactions =
              await (_db.select(_db.budgetTransactions)..orderBy([
                    (tbl) => OrderingTerm(
                      expression: tbl.occurredAt,
                      mode: OrderingMode.desc,
                    ),
                  ]))
                  .get();
          final entries = await _hydrateTransactions(transactions);
          final budgets = await watchBudgetUsage().first;
          final savingGoals = await watchSavingGoals().first;
          final debts = await watchDebts().first;
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final tomorrow = today.add(const Duration(days: 1));
          final weekStart = today.subtract(const Duration(days: 6));
          final weekEnd = tomorrow;
          final previousWeekStart = weekStart.subtract(const Duration(days: 7));
          final monthStart = DateTime(now.year, now.month);
          final nextMonth = DateTime(now.year, now.month + 1);
          final yearStart = DateTime(now.year);
          final nextYear = DateTime(now.year + 1);

          final lastSevenDays = _calculateSevenDayReport(
            entries: entries,
            goals: savingGoals,
            start: weekStart,
            end: weekEnd,
            previousStart: previousWeekStart,
            previousEnd: weekStart,
          );
          final monthlyTrend = _calculateMonthlyExpenseTrend(
            entries: entries,
            goals: savingGoals,
            now: now,
          );
          final yearlyTrend = _calculateYearlyExpenseTrend(
            entries: entries,
            goals: savingGoals,
            now: now,
          );

          return ReportsDashboard(
            daily: _calculatePeriodReport(
              title: 'Today',
              start: today,
              end: tomorrow,
              expenseTrend: const [],
              entries: entries,
              goals: savingGoals,
              budgets: budgets,
              debts: debts,
            ),
            lastSevenDays: lastSevenDays,
            monthly: _calculatePeriodReport(
              title: 'This Month',
              start: monthStart,
              end: nextMonth,
              expenseTrend: monthlyTrend,
              entries: entries,
              goals: savingGoals,
              budgets: budgets,
              debts: debts,
            ),
            yearly: _calculatePeriodReport(
              title: 'This Year',
              start: yearStart,
              end: nextYear,
              expenseTrend: yearlyTrend,
              entries: entries,
              goals: savingGoals,
              budgets: budgets,
              debts: debts,
            ),
          );
        });
  }

  Future<void> addTransaction({
    required String type,
    required double amount,
    required DateTime occurredAt,
    int? accountId,
    int? fromAccountId,
    int? toAccountId,
    int? categoryId,
    String? paymentMethod,
    String? note,
    List<int> tagIds = const [],
  }) async {
    await _db.transaction(() async {
      final id = await _db
          .into(_db.budgetTransactions)
          .insert(
            BudgetTransactionsCompanion.insert(
              occurredAt: occurredAt,
              type: type,
              amount: amount,
              accountId: Value(accountId),
              fromAccountId: Value(fromAccountId),
              toAccountId: Value(toAccountId),
              categoryId: Value(categoryId),
              paymentMethod: Value(paymentMethod),
              note: Value(note),
            ),
          );

      for (final tagId in tagIds) {
        await _db
            .into(_db.transactionTags)
            .insert(
              TransactionTagsCompanion.insert(transactionId: id, tagId: tagId),
            );
      }
    });
    _db.markTablesUpdated([_db.budgetTransactions, _db.transactionTags]);
  }

  Future<void> addAccount({
    required String name,
    required String type,
    required double initialBalance,
    required DateTime startDate,
    String? colorHex,
    String? note,
  }) async {
    await _db.into(_db.accounts).insert(
          AccountsCompanion.insert(
            name: name,
            type: type,
            initialBalance: Value(initialBalance),
            startDate: startDate,
            colorHex: Value(colorHex),
            note: Value(note),
          ),
        );
    _db.markTablesUpdated([_db.accounts]);
  }

  Future<void> updateAccount({
    required int accountId,
    required String name,
    required String type,
    required double initialBalance,
    required DateTime startDate,
    String? colorHex,
    String? note,
  }) async {
    await (_db.update(_db.accounts)..where((tbl) => tbl.id.equals(accountId)))
        .write(
      AccountsCompanion(
        name: Value(name),
        type: Value(type),
        initialBalance: Value(initialBalance),
        startDate: Value(startDate),
        colorHex: Value(colorHex),
        note: Value(note),
        updatedAt: Value(DateTime.now()),
      ),
    );
    _db.markTablesUpdated([_db.accounts]);
  }

  Future<void> archiveAccount(int accountId) async {
    await (_db.update(_db.accounts)..where((tbl) => tbl.id.equals(accountId)))
        .write(
      AccountsCompanion(
        isArchived: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
    _db.markTablesUpdated([_db.accounts]);
  }

  Future<void> addAccountAdjustment({
    required int accountId,
    required double amount,
    required DateTime adjustedAt,
    String? note,
  }) async {
    await _db.into(_db.budgetTransactions).insert(
          BudgetTransactionsCompanion.insert(
            occurredAt: adjustedAt,
            type: 'adjustment',
            amount: amount,
            accountId: Value(accountId),
            note: Value(note),
          ),
        );
    _db.markTablesUpdated([_db.budgetTransactions]);
  }

  Future<void> addCategory({
    required String name,
    required String type,
    required double defaultMonthlyBudget,
    String? colorHex,
    String? note,
  }) async {
    await _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            name: name,
            type: type,
            defaultMonthlyBudget: Value(defaultMonthlyBudget),
            colorHex: Value(colorHex),
            note: Value(note),
          ),
        );
    _db.markTablesUpdated([_db.categories]);
  }

  Future<void> updateCategory({
    required int categoryId,
    required String name,
    required String type,
    required double defaultMonthlyBudget,
    String? colorHex,
    String? note,
  }) async {
    await (_db.update(_db.categories)..where((tbl) => tbl.id.equals(categoryId)))
        .write(
      CategoriesCompanion(
        name: Value(name),
        type: Value(type),
        defaultMonthlyBudget: Value(defaultMonthlyBudget),
        colorHex: Value(colorHex),
        note: Value(note),
      ),
    );
    _db.markTablesUpdated([_db.categories]);
  }

  Future<void> archiveCategory(int categoryId) async {
    await (_db.update(_db.categories)..where((tbl) => tbl.id.equals(categoryId)))
        .write(const CategoriesCompanion(isArchived: Value(true)));
    _db.markTablesUpdated([_db.categories]);
  }

  Future<void> addTag({required String name, String? description}) async {
    await _db.into(_db.tags).insert(
          TagsCompanion.insert(
            name: name,
            description: Value(description),
          ),
        );
    _db.markTablesUpdated([_db.tags]);
  }

  Future<void> updateTag({
    required int tagId,
    required String name,
    String? description,
  }) async {
    await (_db.update(_db.tags)..where((tbl) => tbl.id.equals(tagId))).write(
      TagsCompanion(
        name: Value(name),
        description: Value(description),
      ),
    );
    _db.markTablesUpdated([_db.tags]);
  }

  Future<void> archiveTag(int tagId) async {
    await (_db.update(_db.tags)..where((tbl) => tbl.id.equals(tagId))).write(
      const TagsCompanion(isArchived: Value(true)),
    );
    _db.markTablesUpdated([_db.tags, _db.transactionTags]);
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _db.transaction(() async {
      await _writeSetting('currency_code', settings.currencyCode);
      await _writeSetting(
        'default_account_id',
        settings.defaultAccountId?.toString() ?? '',
      );
      await _writeSetting(
        'daily_reminder_enabled',
        settings.dailyReminderEnabled ? 'true' : 'false',
      );
      await _writeSetting(
        'daily_reminder_hour',
        settings.dailyReminderHour.toString(),
      );
      await _writeSetting(
        'daily_reminder_minute',
        settings.dailyReminderMinute.toString(),
      );
      await _writeSetting('theme_mode', settings.themeMode);
    });
    _db.markTablesUpdated([_db.settings]);
  }

  Future<void> addBudget({
    required int categoryId,
    required String periodType,
    required double amount,
    required DateTime startDate,
    DateTime? endDate,
    required double alertThreshold,
  }) async {
    await _db
        .into(_db.budgets)
        .insert(
          BudgetsCompanion.insert(
            categoryId: categoryId,
            periodType: periodType,
            amount: amount,
            startDate: startDate,
            endDate: Value(endDate),
            alertThreshold: Value(alertThreshold),
          ),
        );
    _db.markTablesUpdated([_db.budgets]);
  }

  Future<void> archiveBudget(int budgetId) async {
    await (_db.update(
      _db.budgets,
    )..where((tbl) => tbl.id.equals(budgetId))).write(
      BudgetsCompanion(
        isArchived: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
    _db.markTablesUpdated([_db.budgets]);
  }

  Future<void> addSavingGoal({
    required String name,
    required double targetAmount,
    DateTime? targetDate,
    required bool countContributionAsExpense,
    String? note,
  }) async {
    await _db
        .into(_db.savingGoals)
        .insert(
          SavingGoalsCompanion.insert(
            name: name,
            targetAmount: targetAmount,
            targetDate: Value(targetDate),
            countContributionAsExpense: Value(countContributionAsExpense),
            note: Value(note),
          ),
        );
    _db.markTablesUpdated([_db.savingGoals]);
  }

  Future<void> addGoalContribution({
    required int goalId,
    required int accountId,
    required double amount,
    required DateTime contributedAt,
    String? note,
  }) async {
    await _db.transaction(() async {
      final goal = await (_db.select(
        _db.savingGoals,
      )..where((tbl) => tbl.id.equals(goalId))).getSingle();
      int? transactionId;

      if (goal.countContributionAsExpense) {
        final categoryId = await _savingExpenseCategoryId();
        transactionId = await _db
            .into(_db.budgetTransactions)
            .insert(
              BudgetTransactionsCompanion.insert(
                occurredAt: contributedAt,
                type: 'expense',
                amount: amount,
                accountId: Value(accountId),
                categoryId: Value(categoryId),
                paymentMethod: const Value('transfer'),
                note: Value(
                  note == null || note.trim().isEmpty
                      ? 'Saving goal: ${goal.name}'
                      : note.trim(),
                ),
              ),
            );
      }

      await _db
          .into(_db.goalContributions)
          .insert(
            GoalContributionsCompanion.insert(
              goalId: goalId,
              accountId: accountId,
              amount: amount,
              contributedAt: contributedAt,
              transactionId: Value(transactionId),
              note: Value(note),
            ),
          );
    });
    _db.markTablesUpdated([_db.goalContributions, _db.budgetTransactions]);
  }

  Future<void> archiveSavingGoal(int goalId) async {
    await (_db.update(
      _db.savingGoals,
    )..where((tbl) => tbl.id.equals(goalId))).write(
      SavingGoalsCompanion(
        status: const Value('archived'),
        updatedAt: Value(DateTime.now()),
      ),
    );
    _db.markTablesUpdated([_db.savingGoals]);
  }

  Future<void> addDebt({
    required String type,
    required String name,
    String? personName,
    required double totalAmount,
    required DateTime startDate,
    DateTime? dueDate,
    String? note,
  }) async {
    await _db
        .into(_db.debts)
        .insert(
          DebtsCompanion.insert(
            type: type,
            name: name,
            personName: Value(personName),
            totalAmount: totalAmount,
            startDate: startDate,
            dueDate: Value(dueDate),
            note: Value(note),
          ),
        );
    _db.markTablesUpdated([_db.debts]);
  }

  Future<void> addDebtPayment({
    required int debtId,
    required int accountId,
    required double amount,
    required DateTime paidAt,
    String? note,
  }) async {
    await _db.transaction(() async {
      final debt = await (_db.select(
        _db.debts,
      )..where((tbl) => tbl.id.equals(debtId))).getSingle();
      final isIncome = debt.type == 'owed_to_me';
      final categoryId = isIncome
          ? await _incomeCategoryId('Debt Repayment Received')
          : await _expenseCategoryId('Debt / Installment');
      final transactionId = await _db
          .into(_db.budgetTransactions)
          .insert(
            BudgetTransactionsCompanion.insert(
              occurredAt: paidAt,
              type: isIncome ? 'income' : 'expense',
              amount: amount,
              accountId: Value(accountId),
              categoryId: Value(categoryId),
              paymentMethod: const Value('transfer'),
              note: Value(
                note == null || note.trim().isEmpty
                    ? 'Debt payment: ${debt.name}'
                    : note.trim(),
              ),
            ),
          );

      await _db
          .into(_db.debtPayments)
          .insert(
            DebtPaymentsCompanion.insert(
              debtId: debtId,
              accountId: accountId,
              amount: amount,
              paidAt: paidAt,
              transactionId: Value(transactionId),
              note: Value(note),
            ),
          );

      final payments = await (_db.select(
        _db.debtPayments,
      )..where((tbl) => tbl.debtId.equals(debtId))).get();
      final paidAmount = payments.fold<double>(
        0,
        (sum, payment) => sum + payment.amount,
      );
      if (paidAmount >= debt.totalAmount) {
        await (_db.update(
          _db.debts,
        )..where((tbl) => tbl.id.equals(debtId))).write(
          DebtsCompanion(
            status: const Value('completed'),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
    _db.markTablesUpdated([_db.debts, _db.debtPayments, _db.budgetTransactions]);
  }

  Future<void> archiveDebt(int debtId) async {
    await (_db.update(_db.debts)..where((tbl) => tbl.id.equals(debtId))).write(
      DebtsCompanion(
        status: const Value('archived'),
        updatedAt: Value(DateTime.now()),
      ),
    );
    _db.markTablesUpdated([_db.debts]);
  }

  Future<void> addQuickAddTemplate({
    required String name,
    required String transactionType,
    required int categoryId,
    required int accountId,
    required double defaultAmount,
    String? defaultNote,
  }) async {
    await _db
        .into(_db.quickAddTemplates)
        .insert(
          QuickAddTemplatesCompanion.insert(
            name: name,
            transactionType: transactionType,
            categoryId: Value(categoryId),
            accountId: Value(accountId),
            defaultAmount: Value(defaultAmount),
            defaultNote: Value(defaultNote),
          ),
        );
    _db.markTablesUpdated([_db.quickAddTemplates]);
  }

  Future<void> updateQuickAddTemplate({
    required int templateId,
    required String name,
    required String transactionType,
    required int categoryId,
    required int accountId,
    required double defaultAmount,
    String? defaultNote,
  }) async {
    await (_db.update(
      _db.quickAddTemplates,
    )..where((tbl) => tbl.id.equals(templateId))).write(
      QuickAddTemplatesCompanion(
        name: Value(name),
        transactionType: Value(transactionType),
        categoryId: Value(categoryId),
        accountId: Value(accountId),
        defaultAmount: Value(defaultAmount),
        defaultNote: Value(defaultNote),
        updatedAt: Value(DateTime.now()),
      ),
    );
    _db.markTablesUpdated([_db.quickAddTemplates]);
  }

  Future<void> useQuickAddTemplate({
    required int templateId,
    required double amount,
    String? note,
  }) async {
    await _db.transaction(() async {
      final template = await (_db.select(
        _db.quickAddTemplates,
      )..where((tbl) => tbl.id.equals(templateId))).getSingle();
      await _db
          .into(_db.budgetTransactions)
          .insert(
            BudgetTransactionsCompanion.insert(
              occurredAt: DateTime.now(),
              type: template.transactionType,
              amount: amount,
              accountId: Value(template.accountId),
              categoryId: Value(template.categoryId),
              paymentMethod: const Value('cash'),
              note: Value(
                note == null || note.trim().isEmpty
                    ? template.defaultNote
                    : note.trim(),
              ),
            ),
          );
      await (_db.update(
        _db.quickAddTemplates,
      )..where((tbl) => tbl.id.equals(templateId))).write(
        QuickAddTemplatesCompanion(
          useCount: Value(template.useCount + 1),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
    _db.markTablesUpdated([_db.quickAddTemplates, _db.budgetTransactions]);
  }

  Future<void> archiveQuickAddTemplate(int templateId) async {
    await (_db.update(
      _db.quickAddTemplates,
    )..where((tbl) => tbl.id.equals(templateId))).write(
      QuickAddTemplatesCompanion(
        isArchived: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
    _db.markTablesUpdated([_db.quickAddTemplates]);
  }

  Future<int> addRecurringTransaction({
    required String name,
    required String transactionType,
    required int categoryId,
    required int accountId,
    required double defaultAmount,
    required String frequency,
    required DateTime nextDueDate,
    DateTime? endDate,
    required int reminderBeforeDays,
    String? note,
  }) async {
    final id = await _db
        .into(_db.recurringTransactions)
        .insert(
          RecurringTransactionsCompanion.insert(
            name: name,
            transactionType: transactionType,
            categoryId: categoryId,
            accountId: accountId,
            defaultAmount: defaultAmount,
            frequency: frequency,
            nextDueDate: nextDueDate,
            endDate: Value(endDate),
            reminderBeforeDays: Value(reminderBeforeDays),
            note: Value(note),
          ),
        );
    _db.markTablesUpdated([_db.recurringTransactions]);
    return id;
  }

  Future<void> updateRecurringTransaction({
    required int recurringId,
    required String name,
    required String transactionType,
    required int categoryId,
    required int accountId,
    required double defaultAmount,
    required String frequency,
    required DateTime nextDueDate,
    DateTime? endDate,
    required int reminderBeforeDays,
    String? note,
  }) async {
    await (_db.update(
      _db.recurringTransactions,
    )..where((tbl) => tbl.id.equals(recurringId))).write(
      RecurringTransactionsCompanion(
        name: Value(name),
        transactionType: Value(transactionType),
        categoryId: Value(categoryId),
        accountId: Value(accountId),
        defaultAmount: Value(defaultAmount),
        frequency: Value(frequency),
        nextDueDate: Value(nextDueDate),
        endDate: Value(endDate),
        reminderBeforeDays: Value(reminderBeforeDays),
        note: Value(note),
        status: const Value('active'),
        updatedAt: Value(DateTime.now()),
      ),
    );
    _db.markTablesUpdated([_db.recurringTransactions]);
  }

  Future<void> confirmRecurringTransaction({
    required int recurringId,
    required double amount,
    String? note,
  }) async {
    await _db.transaction(() async {
      final recurring = await (_db.select(
        _db.recurringTransactions,
      )..where((tbl) => tbl.id.equals(recurringId))).getSingle();
      await _db
          .into(_db.budgetTransactions)
          .insert(
            BudgetTransactionsCompanion.insert(
              occurredAt: DateTime.now(),
              type: recurring.transactionType,
              amount: amount,
              accountId: Value(recurring.accountId),
              categoryId: Value(recurring.categoryId),
              paymentMethod: const Value('transfer'),
              note: Value(
                note == null || note.trim().isEmpty
                    ? recurring.note
                    : note.trim(),
              ),
            ),
          );

      final nextDueDate = _nextDueDate(
        recurring.nextDueDate,
        recurring.frequency,
      );
      final endDate = recurring.endDate;
      final nextStatus = endDate != null && nextDueDate.isAfter(endDate)
          ? 'completed'
          : 'active';

      await (_db.update(
        _db.recurringTransactions,
      )..where((tbl) => tbl.id.equals(recurringId))).write(
        RecurringTransactionsCompanion(
          nextDueDate: Value(nextDueDate),
          status: Value(nextStatus),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
    _db.markTablesUpdated([_db.recurringTransactions, _db.budgetTransactions]);
  }

  Future<void> pauseRecurringTransaction(int recurringId) async {
    await (_db.update(
      _db.recurringTransactions,
    )..where((tbl) => tbl.id.equals(recurringId))).write(
      RecurringTransactionsCompanion(
        status: const Value('paused'),
        updatedAt: Value(DateTime.now()),
      ),
    );
    _db.markTablesUpdated([_db.recurringTransactions]);
  }

  Future<void> resumeRecurringTransaction(int recurringId) async {
    await (_db.update(
      _db.recurringTransactions,
    )..where((tbl) => tbl.id.equals(recurringId))).write(
      RecurringTransactionsCompanion(
        status: const Value('active'),
        updatedAt: Value(DateTime.now()),
      ),
    );
    _db.markTablesUpdated([_db.recurringTransactions]);
  }

  Future<void> archiveRecurringTransaction(int recurringId) async {
    await (_db.update(
      _db.recurringTransactions,
    )..where((tbl) => tbl.id.equals(recurringId))).write(
      RecurringTransactionsCompanion(
        status: const Value('archived'),
        updatedAt: Value(DateTime.now()),
      ),
    );
    _db.markTablesUpdated([_db.recurringTransactions]);
  }

  Future<String> exportTransactionsCsv({DateTime? from, DateTime? to}) async {
    final entries = await watchTransactions().first;
    final filtered = entries.where((entry) {
      final day = DateTime(
        entry.transaction.occurredAt.year,
        entry.transaction.occurredAt.month,
        entry.transaction.occurredAt.day,
      );
      final matchesFrom = from == null || !day.isBefore(from);
      final matchesTo = to == null || !day.isAfter(to);
      return matchesFrom && matchesTo;
    }).toList();
    final rows = <List<Object?>>[
      [
        'id',
        'occurred_at',
        'type',
        'amount',
        'category',
        'account',
        'from_account',
        'to_account',
        'payment_method',
        'tags',
        'note',
      ],
      for (final entry in filtered)
        [
          entry.transaction.id,
          entry.transaction.occurredAt.toIso8601String(),
          entry.transaction.type,
          entry.transaction.amount,
          entry.category?.name ?? '',
          entry.account?.name ?? '',
          entry.fromAccount?.name ?? '',
          entry.toAccount?.name ?? '',
          entry.transaction.paymentMethod ?? '',
          entry.tags.map((tag) => tag.name).join('|'),
          entry.transaction.note ?? '',
        ],
    ];
    return csv.encode(rows);
  }

  Future<List<CsvExportFile>> exportAllCsvFiles() async {
    final transactions = await exportTransactionsCsv();
    final accounts = await _db.select(_db.accounts).get();
    final categories = await _db.select(_db.categories).get();
    final budgets = await _db.select(_db.budgets).get();
    final goals = await _db.select(_db.savingGoals).get();
    final goalContributions = await _db.select(_db.goalContributions).get();
    final debts = await _db.select(_db.debts).get();
    final debtPayments = await _db.select(_db.debtPayments).get();
    final templates = await _db.select(_db.quickAddTemplates).get();
    final recurring = await _db.select(_db.recurringTransactions).get();
    final tags = await _db.select(_db.tags).get();
    final transactionTags = await _db.select(_db.transactionTags).get();
    final settings = await _db.select(_db.settings).get();

    return [
      CsvExportFile(fileName: 'transactions.csv', content: transactions),
      CsvExportFile(
        fileName: 'accounts.csv',
        content: csv.encode([
          [
            'id',
            'name',
            'type',
            'initial_balance',
            'start_date',
            'is_archived',
            'color_hex',
            'note',
            'created_at',
            'updated_at',
          ],
          for (final item in accounts)
            [
              item.id,
              item.name,
              item.type,
              item.initialBalance,
              item.startDate.toIso8601String(),
              item.isArchived,
              item.colorHex ?? '',
              item.note ?? '',
              item.createdAt.toIso8601String(),
              item.updatedAt.toIso8601String(),
            ],
        ]),
      ),
      CsvExportFile(
        fileName: 'categories.csv',
        content: csv.encode([
          [
            'id',
            'name',
            'type',
            'default_monthly_budget',
            'is_archived',
            'color_hex',
            'note',
          ],
          for (final item in categories)
            [
              item.id,
              item.name,
              item.type,
              item.defaultMonthlyBudget,
              item.isArchived,
              item.colorHex ?? '',
              item.note ?? '',
            ],
        ]),
      ),
      CsvExportFile(
        fileName: 'budgets.csv',
        content: csv.encode([
          [
            'id',
            'category_id',
            'period_type',
            'amount',
            'start_date',
            'end_date',
            'alert_threshold',
            'is_archived',
            'created_at',
            'updated_at',
          ],
          for (final item in budgets)
            [
              item.id,
              item.categoryId,
              item.periodType,
              item.amount,
              item.startDate.toIso8601String(),
              item.endDate?.toIso8601String() ?? '',
              item.alertThreshold,
              item.isArchived,
              item.createdAt.toIso8601String(),
              item.updatedAt.toIso8601String(),
            ],
        ]),
      ),
      CsvExportFile(
        fileName: 'saving_goals.csv',
        content: csv.encode([
          [
            'id',
            'name',
            'target_amount',
            'target_date',
            'status',
            'count_contribution_as_expense',
            'note',
            'created_at',
            'updated_at',
          ],
          for (final item in goals)
            [
              item.id,
              item.name,
              item.targetAmount,
              item.targetDate?.toIso8601String() ?? '',
              item.status,
              item.countContributionAsExpense,
              item.note ?? '',
              item.createdAt.toIso8601String(),
              item.updatedAt.toIso8601String(),
            ],
        ]),
      ),
      CsvExportFile(
        fileName: 'goal_contributions.csv',
        content: csv.encode([
          [
            'id',
            'goal_id',
            'contributed_at',
            'amount',
            'account_id',
            'transaction_id',
            'note',
            'created_at',
          ],
          for (final item in goalContributions)
            [
              item.id,
              item.goalId,
              item.contributedAt.toIso8601String(),
              item.amount,
              item.accountId,
              item.transactionId ?? '',
              item.note ?? '',
              item.createdAt.toIso8601String(),
            ],
        ]),
      ),
      CsvExportFile(
        fileName: 'debts.csv',
        content: csv.encode([
          [
            'id',
            'type',
            'name',
            'person_name',
            'total_amount',
            'start_date',
            'due_date',
            'status',
            'note',
            'created_at',
            'updated_at',
          ],
          for (final item in debts)
            [
              item.id,
              item.type,
              item.name,
              item.personName ?? '',
              item.totalAmount,
              item.startDate.toIso8601String(),
              item.dueDate?.toIso8601String() ?? '',
              item.status,
              item.note ?? '',
              item.createdAt.toIso8601String(),
              item.updatedAt.toIso8601String(),
            ],
        ]),
      ),
      CsvExportFile(
        fileName: 'debt_payments.csv',
        content: csv.encode([
          [
            'id',
            'debt_id',
            'paid_at',
            'amount',
            'account_id',
            'transaction_id',
            'note',
            'created_at',
          ],
          for (final item in debtPayments)
            [
              item.id,
              item.debtId,
              item.paidAt.toIso8601String(),
              item.amount,
              item.accountId,
              item.transactionId ?? '',
              item.note ?? '',
              item.createdAt.toIso8601String(),
            ],
        ]),
      ),
      CsvExportFile(
        fileName: 'quick_add_templates.csv',
        content: csv.encode([
          [
            'id',
            'name',
            'transaction_type',
            'category_id',
            'account_id',
            'default_amount',
            'default_note',
            'use_count',
            'is_archived',
            'created_at',
            'updated_at',
          ],
          for (final item in templates)
            [
              item.id,
              item.name,
              item.transactionType,
              item.categoryId ?? '',
              item.accountId ?? '',
              item.defaultAmount,
              item.defaultNote ?? '',
              item.useCount,
              item.isArchived,
              item.createdAt.toIso8601String(),
              item.updatedAt.toIso8601String(),
            ],
        ]),
      ),
      CsvExportFile(
        fileName: 'recurring_transactions.csv',
        content: csv.encode([
          [
            'id',
            'name',
            'transaction_type',
            'category_id',
            'account_id',
            'default_amount',
            'frequency',
            'next_due_date',
            'end_date',
            'status',
            'reminder_before_days',
            'note',
            'created_at',
            'updated_at',
          ],
          for (final item in recurring)
            [
              item.id,
              item.name,
              item.transactionType,
              item.categoryId,
              item.accountId,
              item.defaultAmount,
              item.frequency,
              item.nextDueDate.toIso8601String(),
              item.endDate?.toIso8601String() ?? '',
              item.status,
              item.reminderBeforeDays,
              item.note ?? '',
              item.createdAt.toIso8601String(),
              item.updatedAt.toIso8601String(),
            ],
        ]),
      ),
      CsvExportFile(
        fileName: 'tags.csv',
        content: csv.encode([
          ['id', 'name', 'description', 'is_archived'],
          for (final item in tags)
            [item.id, item.name, item.description ?? '', item.isArchived],
        ]),
      ),
      CsvExportFile(
        fileName: 'transaction_tags.csv',
        content: csv.encode([
          ['transaction_id', 'tag_id'],
          for (final item in transactionTags) [item.transactionId, item.tagId],
        ]),
      ),
      CsvExportFile(
        fileName: 'settings.csv',
        content: csv.encode([
          ['key', 'value'],
          for (final item in settings) [item.key, item.value],
        ]),
      ),
    ];
  }

  Future<String> exportAllCsvBundle() async {
    final files = await exportAllCsvFiles();
    return files
        .map((file) => '--- ${file.fileName} ---\n${file.content.trim()}')
        .join('\n\n');
  }

  double _calculateBalance(
    Account account,
    List<BudgetTransaction> transactions,
    List<GoalContribution> contributions,
    List<DebtPayment> debtPayments,
  ) {
    var balance = account.initialBalance;
    for (final tx in transactions) {
      if (tx.type == 'income' && tx.accountId == account.id) {
        balance += tx.amount;
      } else if (tx.type == 'expense' && tx.accountId == account.id) {
        balance -= tx.amount;
      } else if (tx.type == 'adjustment' && tx.accountId == account.id) {
        balance += tx.amount;
      } else if (tx.type == 'transfer') {
        if (tx.fromAccountId == account.id) balance -= tx.amount;
        if (tx.toAccountId == account.id) balance += tx.amount;
      } else if (tx.type == 'credit_card_payment') {
        if (tx.fromAccountId == account.id) balance -= tx.amount;
        if (tx.toAccountId == account.id) balance += tx.amount;
      }
    }
    for (final contribution in contributions) {
      if (contribution.accountId == account.id &&
          contribution.transactionId == null) {
        balance -= contribution.amount;
      }
    }
    for (final payment in debtPayments) {
      if (payment.accountId == account.id && payment.transactionId == null) {
        balance -= payment.amount;
      }
    }
    return balance;
  }

  BudgetUsage _calculateBudgetUsage({
    required Budget budget,
    required Category category,
    required List<BudgetTransaction> transactions,
  }) {
    final range = _budgetRange(budget);
    final usedAmount = transactions
        .where(
          (tx) =>
              tx.type == 'expense' &&
              tx.categoryId == budget.categoryId &&
              !tx.occurredAt.isBefore(range.start) &&
              tx.occurredAt.isBefore(range.end),
        )
        .fold<double>(0, (sum, tx) => sum + tx.amount);
    final usagePercentage = budget.amount <= 0
        ? 0.0
        : usedAmount / budget.amount;
    final status = usedAmount > budget.amount
        ? BudgetStatus.over
        : usagePercentage >= budget.alertThreshold
        ? BudgetStatus.warning
        : BudgetStatus.ok;

    return BudgetUsage(
      budget: budget,
      category: category,
      usedAmount: usedAmount,
      remainingAmount: budget.amount - usedAmount,
      usagePercentage: usagePercentage,
      status: status,
    );
  }

  ({DateTime start, DateTime end}) _budgetRange(Budget budget) {
    final now = DateTime.now();
    final explicitEnd = budget.endDate;
    if (explicitEnd != null) {
      return (
        start: budget.startDate,
        end: explicitEnd.add(const Duration(days: 1)),
      );
    }

    if (budget.periodType == 'weekly') {
      final today = DateTime(now.year, now.month, now.day);
      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      return (start: weekStart, end: weekStart.add(const Duration(days: 7)));
    }

    final monthStart = DateTime(now.year, now.month);
    return (start: monthStart, end: DateTime(now.year, now.month + 1));
  }

  SavingGoalProgress _calculateSavingGoalProgress(
    SavingGoal goal,
    List<GoalContribution> allContributions,
  ) {
    final contributions =
        allContributions
            .where((contribution) => contribution.goalId == goal.id)
            .toList()
          ..sort((a, b) => b.contributedAt.compareTo(a.contributedAt));
    final currentAmount = contributions.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final progressPercentage = goal.targetAmount <= 0
        ? 0.0
        : currentAmount / goal.targetAmount;

    return SavingGoalProgress(
      goal: goal,
      currentAmount: currentAmount,
      remainingAmount: goal.targetAmount - currentAmount,
      progressPercentage: progressPercentage,
      contributions: contributions,
    );
  }

  DebtProgress _calculateDebtProgress(
    Debt debt,
    List<DebtPayment> allPayments,
  ) {
    final payments =
        allPayments.where((payment) => payment.debtId == debt.id).toList()
          ..sort((a, b) => b.paidAt.compareTo(a.paidAt));
    final paidAmount = payments.fold<double>(
      0,
      (sum, payment) => sum + payment.amount,
    );
    final progressPercentage = debt.totalAmount <= 0
        ? 0.0
        : paidAmount / debt.totalAmount;

    return DebtProgress(
      debt: debt,
      paidAmount: paidAmount,
      remainingAmount: debt.totalAmount - paidAmount,
      progressPercentage: progressPercentage,
      payments: payments,
    );
  }

  List<DebtProgress> _upcomingDebts(List<DebtProgress> debts) {
    final now = DateTime.now();
    final upcoming =
        debts
            .where(
              (debt) =>
                  !debt.isComplete &&
                  debt.debt.dueDate != null &&
                  !debt.debt.dueDate!.isBefore(
                    DateTime(now.year, now.month, now.day),
                  ),
            )
            .toList()
          ..sort((a, b) => a.debt.dueDate!.compareTo(b.debt.dueDate!));
    return upcoming;
  }

  List<RecurringTransactionEntry> _upcomingRecurring(
    List<RecurringTransactionEntry> recurring,
  ) {
    final now = DateTime.now();
    final threshold = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 7));
    final upcoming =
        recurring
            .where(
              (entry) =>
                  entry.recurring.status == 'active' &&
                  !entry.recurring.nextDueDate.isAfter(threshold),
            )
            .toList()
          ..sort(
            (a, b) =>
                a.recurring.nextDueDate.compareTo(b.recurring.nextDueDate),
          );
    return upcoming;
  }

  PeriodReport _calculatePeriodReport({
    required String title,
    required DateTime start,
    required DateTime end,
    required List<DailyExpense> expenseTrend,
    required List<TransactionEntry> entries,
    required List<SavingGoalProgress> goals,
    required List<BudgetUsage> budgets,
    required List<DebtProgress> debts,
  }) {
    final periodEntries = entries
        .where((entry) => _isInRange(entry.transaction.occurredAt, start, end))
        .toList();
    final incomeByCategory = <String, double>{};
    final expenseByCategory = <String, double>{};
    var income = 0.0;
    var expense = 0.0;

    for (final entry in periodEntries) {
      final tx = entry.transaction;
      if (tx.type == 'income') {
        income += tx.amount;
        final name = entry.category?.name ?? 'Uncategorized';
        incomeByCategory[name] = (incomeByCategory[name] ?? 0) + tx.amount;
      } else if (tx.type == 'expense') {
        expense += tx.amount;
        final name = entry.category?.name ?? 'Uncategorized';
        expenseByCategory[name] = (expenseByCategory[name] ?? 0) + tx.amount;
      }
    }

    for (final goal in goals) {
      if (!goal.goal.countContributionAsExpense) continue;
      for (final contribution in goal.contributions) {
        if (contribution.transactionId != null) continue;
        if (!_isInRange(contribution.contributedAt, start, end)) continue;
        expense += contribution.amount;
        expenseByCategory['Saving'] =
            (expenseByCategory['Saving'] ?? 0) + contribution.amount;
      }
    }

    final incomeCategoryBreakdown = _categorySpending(
      incomeByCategory,
      income,
    );
    final categoryBreakdown = _categorySpending(expenseByCategory, expense);
    return PeriodReport(
      title: title,
      start: start,
      end: end,
      income: income,
      expense: expense,
      expenseTrend: expenseTrend,
      incomeCategoryBreakdown: incomeCategoryBreakdown,
      categoryBreakdown: categoryBreakdown,
      topCategories: categoryBreakdown.take(5).toList(),
      transactions: periodEntries.take(8).toList(),
      budgetUsage: budgets.take(5).toList(),
      savingGoals: goals.take(5).toList(),
      upcomingDebts: _upcomingDebts(debts).take(5).toList(),
    );
  }

  SevenDayReport _calculateSevenDayReport({
    required List<TransactionEntry> entries,
    required List<SavingGoalProgress> goals,
    required DateTime start,
    required DateTime end,
    required DateTime previousStart,
    required DateTime previousEnd,
  }) {
    final days = List.generate(7, (index) {
      final day = start.add(Duration(days: index));
      return DailyExpense(day: day, amount: 0);
    });
    final byDay = {
      for (final item in days)
        DateTime(item.day.year, item.day.month, item.day.day): 0.0,
    };
    final incomeByCategory = <String, double>{};
    final expenseByCategory = <String, double>{};
    var income = 0.0;
    var expense = 0.0;
    var previousExpense = 0.0;

    for (final entry in entries) {
      final tx = entry.transaction;
      if (_isInRange(tx.occurredAt, start, end)) {
        if (tx.type == 'income') {
          income += tx.amount;
          final name = entry.category?.name ?? 'Uncategorized';
          incomeByCategory[name] = (incomeByCategory[name] ?? 0) + tx.amount;
        } else if (tx.type == 'expense') {
          expense += tx.amount;
          final name = entry.category?.name ?? 'Uncategorized';
          expenseByCategory[name] =
              (expenseByCategory[name] ?? 0) + tx.amount;
          final day = DateTime(
            tx.occurredAt.year,
            tx.occurredAt.month,
            tx.occurredAt.day,
          );
          byDay[day] = (byDay[day] ?? 0) + tx.amount;
        }
      } else if (tx.type == 'expense' &&
          _isInRange(tx.occurredAt, previousStart, previousEnd)) {
        previousExpense += tx.amount;
      }
    }

    for (final goal in goals) {
      if (!goal.goal.countContributionAsExpense) continue;
      for (final contribution in goal.contributions) {
        if (contribution.transactionId != null) continue;
        if (_isInRange(contribution.contributedAt, start, end)) {
          expense += contribution.amount;
          expenseByCategory['Saving'] =
              (expenseByCategory['Saving'] ?? 0) + contribution.amount;
          final day = DateTime(
            contribution.contributedAt.year,
            contribution.contributedAt.month,
            contribution.contributedAt.day,
          );
          byDay[day] = (byDay[day] ?? 0) + contribution.amount;
        } else if (_isInRange(
          contribution.contributedAt,
          previousStart,
          previousEnd,
        )) {
          previousExpense += contribution.amount;
        }
      }
    }

    final dailyExpenses = [
      for (final item in days)
        DailyExpense(
          day: item.day,
          amount: byDay[DateTime(item.day.year, item.day.month, item.day.day)]!,
        ),
    ];
    final total = dailyExpenses.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final highest = dailyExpenses.isEmpty
        ? null
        : dailyExpenses.reduce((a, b) => a.amount >= b.amount ? a : b);

    return SevenDayReport(
      days: dailyExpenses,
      totalExpense: total,
      incomeCategoryBreakdown: _categorySpending(incomeByCategory, income),
      expenseCategoryBreakdown: _categorySpending(expenseByCategory, expense),
      averageExpensePerDay: total / 7,
      highestSpendingDay: highest,
      previousSevenDayExpense: previousExpense,
    );
  }

  List<DailyExpense> _calculateMonthlyExpenseTrend({
    required List<TransactionEntry> entries,
    required List<SavingGoalProgress> goals,
    required DateTime now,
  }) {
    final months = List.generate(6, (index) {
      final offset = 5 - index;
      return DateTime(now.year, now.month - offset);
    });
    final byMonth = {for (final month in months) month: 0.0};

    for (final entry in entries) {
      final tx = entry.transaction;
      if (tx.type != 'expense') continue;
      final month = DateTime(tx.occurredAt.year, tx.occurredAt.month);
      if (byMonth.containsKey(month)) {
        byMonth[month] = byMonth[month]! + tx.amount;
      }
    }

    for (final goal in goals) {
      if (!goal.goal.countContributionAsExpense) continue;
      for (final contribution in goal.contributions) {
        if (contribution.transactionId != null) continue;
        final month = DateTime(
          contribution.contributedAt.year,
          contribution.contributedAt.month,
        );
        if (byMonth.containsKey(month)) {
          byMonth[month] = byMonth[month]! + contribution.amount;
        }
      }
    }

    return [
      for (final month in months) DailyExpense(day: month, amount: byMonth[month]!),
    ];
  }

  List<DailyExpense> _calculateYearlyExpenseTrend({
    required List<TransactionEntry> entries,
    required List<SavingGoalProgress> goals,
    required DateTime now,
  }) {
    final years = List.generate(6, (index) => DateTime(now.year - (5 - index)));
    final byYear = {for (final year in years) year: 0.0};

    for (final entry in entries) {
      final tx = entry.transaction;
      if (tx.type != 'expense') continue;
      final year = DateTime(tx.occurredAt.year);
      if (byYear.containsKey(year)) {
        byYear[year] = byYear[year]! + tx.amount;
      }
    }

    for (final goal in goals) {
      if (!goal.goal.countContributionAsExpense) continue;
      for (final contribution in goal.contributions) {
        if (contribution.transactionId != null) continue;
        final year = DateTime(contribution.contributedAt.year);
        if (byYear.containsKey(year)) {
          byYear[year] = byYear[year]! + contribution.amount;
        }
      }
    }

    return [for (final year in years) DailyExpense(day: year, amount: byYear[year]!)];
  }

  List<CategorySpending> _categorySpending(
    Map<String, double> amounts,
    double totalExpense,
  ) {
    final items =
        amounts.entries
            .map(
              (entry) => CategorySpending(
                categoryName: entry.key,
                amount: entry.value,
                percentage: totalExpense <= 0 ? 0 : entry.value / totalExpense,
              ),
            )
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));
    return items;
  }

  bool _isInRange(DateTime value, DateTime start, DateTime end) {
    return !value.isBefore(start) && value.isBefore(end);
  }

  AppSettings _settingsFromMap(Map<String, String> values) {
    final defaults = AppSettings.defaults();
    return AppSettings(
      currencyCode: values['currency_code'] ?? defaults.currencyCode,
      defaultAccountId: int.tryParse(values['default_account_id'] ?? ''),
      dailyReminderEnabled:
          values['daily_reminder_enabled'] == 'true',
      dailyReminderHour:
          int.tryParse(values['daily_reminder_hour'] ?? '') ??
          defaults.dailyReminderHour,
      dailyReminderMinute:
          int.tryParse(values['daily_reminder_minute'] ?? '') ??
          defaults.dailyReminderMinute,
      themeMode: values['theme_mode'] ?? defaults.themeMode,
    );
  }

  Future<void> _writeSetting(String key, String value) async {
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
  }

  DateTime _nextDueDate(DateTime current, String frequency) {
    return switch (frequency) {
      'weekly' => current.add(const Duration(days: 7)),
      'yearly' => DateTime(current.year + 1, current.month, current.day),
      _ => DateTime(current.year, current.month + 1, current.day),
    };
  }

  Future<int?> _savingExpenseCategoryId() async {
    return _expenseCategoryId('Saving');
  }

  Future<int?> _expenseCategoryId(String name) async {
    final category =
        await (_db.select(_db.categories)..where(
              (tbl) => tbl.type.equals('expense') & tbl.name.equals(name),
            ))
            .getSingleOrNull();
    return category?.id;
  }

  Future<int?> _incomeCategoryId(String name) async {
    final category =
        await (_db.select(_db.categories)..where(
              (tbl) => tbl.type.equals('income') & tbl.name.equals(name),
            ))
            .getSingleOrNull();
    return category?.id;
  }

  Future<List<TransactionEntry>> _hydrateTransactions(
    List<BudgetTransaction> transactions,
  ) async {
    final accounts = await _db.select(_db.accounts).get();
    final categories = await _db.select(_db.categories).get();
    final tags = await _db.select(_db.tags).get();
    final links = await _db.select(_db.transactionTags).get();

    Account? accountById(int? id) =>
        id == null ? null : accounts.where((item) => item.id == id).firstOrNull;
    Category? categoryById(int? id) => id == null
        ? null
        : categories.where((item) => item.id == id).firstOrNull;

    return [
      for (final tx in transactions)
        TransactionEntry(
          transaction: tx,
          category: categoryById(tx.categoryId),
          account: accountById(tx.accountId),
          fromAccount: accountById(tx.fromAccountId),
          toAccount: accountById(tx.toAccountId),
          tags: [
            for (final link in links.where(
              (link) => link.transactionId == tx.id,
            ))
              tags.where((tag) => tag.id == link.tagId).firstOrNull,
          ].whereType<Tag>().toList(),
        ),
    ];
  }

  Future<List<QuickAddTemplateEntry>> _hydrateTemplates(
    List<QuickAddTemplate> templates,
  ) async {
    final accounts = await _db.select(_db.accounts).get();
    final categories = await _db.select(_db.categories).get();

    Account? accountById(int? id) =>
        id == null ? null : accounts.where((item) => item.id == id).firstOrNull;
    Category? categoryById(int? id) => id == null
        ? null
        : categories.where((item) => item.id == id).firstOrNull;

    return [
      for (final template in templates)
        QuickAddTemplateEntry(
          template: template,
          account: accountById(template.accountId),
          category: categoryById(template.categoryId),
        ),
    ];
  }

  Future<List<RecurringTransactionEntry>> _hydrateRecurring(
    List<RecurringTransaction> recurringItems,
  ) async {
    final accounts = await _db.select(_db.accounts).get();
    final categories = await _db.select(_db.categories).get();

    return [
      for (final item in recurringItems)
        if (accounts
                .where((account) => account.id == item.accountId)
                .firstOrNull
            case final account?)
          if (categories
                  .where((category) => category.id == item.categoryId)
                  .firstOrNull
              case final category?)
            RecurringTransactionEntry(
              recurring: item,
              account: account,
              category: category,
            ),
    ];
  }
}
