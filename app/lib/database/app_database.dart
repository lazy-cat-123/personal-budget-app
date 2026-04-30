import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Accounts extends Table {
  @override
  String get tableName => 'accounts';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  RealColumn get initialBalance => real().withDefault(const Constant(0))();
  DateTimeColumn get startDate => dateTime()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  TextColumn get colorHex => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Categories extends Table {
  @override
  String get tableName => 'categories';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  RealColumn get defaultMonthlyBudget =>
      real().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  TextColumn get colorHex => text().nullable()();
  TextColumn get note => text().nullable()();
}

class BudgetTransactions extends Table {
  @override
  String get tableName => 'transactions';

  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get type => text()();
  RealColumn get amount => real()();
  TextColumn get paymentMethod => text().nullable()();
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
  IntColumn get fromAccountId =>
      integer().nullable().references(Accounts, #id)();
  IntColumn get toAccountId => integer().nullable().references(Accounts, #id)();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Tags extends Table {
  @override
  String get tableName => 'tags';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get description => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

class TransactionTags extends Table {
  @override
  String get tableName => 'transaction_tags';

  IntColumn get transactionId =>
      integer().references(BudgetTransactions, #id)();
  IntColumn get tagId => integer().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {transactionId, tagId};
}

class Budgets extends Table {
  @override
  String get tableName => 'budgets';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get periodType => text()();
  RealColumn get amount => real()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  RealColumn get alertThreshold => real().withDefault(const Constant(0.8))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class SavingGoals extends Table {
  @override
  String get tableName => 'saving_goals';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get targetAmount => real()();
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  BoolColumn get countContributionAsExpense =>
      boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class GoalContributions extends Table {
  @override
  String get tableName => 'goal_contributions';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get goalId => integer().references(SavingGoals, #id)();
  DateTimeColumn get contributedAt => dateTime()();
  RealColumn get amount => real()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get transactionId =>
      integer().nullable().references(BudgetTransactions, #id)();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Debts extends Table {
  @override
  String get tableName => 'debts';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  TextColumn get name => text()();
  TextColumn get personName => text().nullable()();
  RealColumn get totalAmount => real()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class DebtPayments extends Table {
  @override
  String get tableName => 'debt_payments';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get debtId => integer().references(Debts, #id)();
  DateTimeColumn get paidAt => dateTime()();
  RealColumn get amount => real()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get transactionId =>
      integer().nullable().references(BudgetTransactions, #id)();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class QuickAddTemplates extends Table {
  @override
  String get tableName => 'quick_add_templates';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get transactionType => text()();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
  RealColumn get defaultAmount => real().withDefault(const Constant(0))();
  TextColumn get defaultNote => text().nullable()();
  IntColumn get useCount => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class RecurringTransactions extends Table {
  @override
  String get tableName => 'recurring_transactions';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get transactionType => text()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get accountId => integer().references(Accounts, #id)();
  RealColumn get defaultAmount => real()();
  TextColumn get frequency => text()();
  DateTimeColumn get nextDueDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  IntColumn get reminderBeforeDays =>
      integer().withDefault(const Constant(1))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Settings extends Table {
  @override
  String get tableName => 'settings';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    BudgetTransactions,
    Budgets,
    SavingGoals,
    GoalContributions,
    Debts,
    DebtPayments,
    QuickAddTemplates,
    RecurringTransactions,
    Tags,
    TransactionTags,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(budgets);
      }
      if (from < 3) {
        await m.createTable(savingGoals);
        await m.createTable(goalContributions);
      }
      if (from >= 3 && from < 4) {
        await m.addColumn(goalContributions, goalContributions.transactionId);
      }
      if (from < 5) {
        await m.createTable(debts);
        await m.createTable(debtPayments);
      }
      if (from < 6) {
        await m.createTable(quickAddTemplates);
      }
      if (from < 7) {
        await m.createTable(recurringTransactions);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _seedDefaults();
    },
  );

  Future<void> _seedDefaults() async {
    final accountCount = await customSelect(
      'SELECT COUNT(*) AS c FROM accounts',
      readsFrom: {accounts},
    ).map((row) => row.read<int>('c')).getSingle();
    if (accountCount == 0) {
      await into(accounts).insert(
        AccountsCompanion.insert(
          name: 'Cash',
          type: 'cash',
          initialBalance: const Value(0),
          startDate: DateTime.now(),
          colorHex: const Value('246B5F'),
        ),
      );
      await into(accounts).insert(
        AccountsCompanion.insert(
          name: 'Bank Account',
          type: 'bank_account',
          initialBalance: const Value(0),
          startDate: DateTime.now(),
          colorHex: const Value('2F5F98'),
        ),
      );
    }

    final categoryCount = await customSelect(
      'SELECT COUNT(*) AS c FROM categories',
      readsFrom: {categories},
    ).map((row) => row.read<int>('c')).getSingle();
    if (categoryCount == 0) {
      const expenseNames = [
        'Food',
        'Transport',
        'Rent / Dorm',
        'Utilities',
        'Internet / Phone',
        'Education',
        'Books / Courses',
        'Games / Entertainment',
        'Personal Items',
        'Health',
        'Clothes',
        'Computer / Technology',
        'Saving',
        'Debt / Installment',
        'Other',
      ];
      const incomeNames = [
        'Family Support',
        'Salary / Part-time',
        'Freelance',
        'Selling',
        'Interest / Dividend',
        'Refund',
        'Debt Repayment Received',
        'Other',
      ];

      for (final name in expenseNames) {
        await into(
          categories,
        ).insert(CategoriesCompanion.insert(name: name, type: 'expense'));
      }
      for (final name in incomeNames) {
        await into(
          categories,
        ).insert(CategoriesCompanion.insert(name: name, type: 'income'));
      }
    }

    final tagCount = await customSelect(
      'SELECT COUNT(*) AS c FROM tags',
      readsFrom: {tags},
    ).map((row) => row.read<int>('c')).getSingle();
    if (tagCount == 0) {
      for (final name in const ['food', 'transport', 'urgent', 'personal']) {
        await into(tags).insert(TagsCompanion.insert(name: name));
      }
    }
  }

  Future<void> backupToPhoneStorage() async {
    if (!Platform.isAndroid) return;
    await customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    final file = await _databaseFile();
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    try {
      await _backupChannel.invokeMethod<String>('saveDatabaseBackup', {
        'bytes': bytes,
      });
    } catch (_) {
      // Android can block replacing public backup files created by an older install.
      // Data changes should still succeed; Settings exposes manual cleanup.
    }
  }

  Future<bool> restoreFromPhoneBackupPicker() async {
    if (!Platform.isAndroid) return false;
    final bytes = await _backupChannel.invokeMethod<Uint8List>(
      'pickDatabaseBackup',
    );
    return _replaceDatabaseWithBackup(bytes);
  }

  Future<bool> restoreFromPhoneBackupFolder() async {
    if (!Platform.isAndroid) return false;
    final bytes = await _backupChannel.invokeMethod<Uint8List>(
      'readDatabaseBackup',
    );
    return _replaceDatabaseWithBackup(bytes);
  }

  Future<bool> cleanPhoneBackupFolder() async {
    if (!Platform.isAndroid) return false;
    final cleaned = await _backupChannel.invokeMethod<bool>(
      'cleanDatabaseBackups',
    );
    return cleaned ?? false;
  }

  Future<bool> _replaceDatabaseWithBackup(Uint8List? bytes) async {
    if (bytes == null || bytes.isEmpty || !_looksLikeSqliteDatabase(bytes)) {
      return false;
    }

    await customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    await close();

    final file = await _databaseFile();
    await file.parent.create(recursive: true);
    await _deleteIfExists(File('${file.path}-wal'));
    await _deleteIfExists(File('${file.path}-shm'));
    await file.writeAsBytes(bytes, flush: true);
    return true;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = await _databaseFile();
    await _restoreDatabaseBackupIfNeeded(file);
    return NativeDatabase.createInBackground(file);
  });
}

const _backupChannel = MethodChannel('personal_budget_app/downloads');

Future<File> _databaseFile() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  return File(p.join(dbFolder.path, 'personal_budget.sqlite'));
}

Future<void> _restoreDatabaseBackupIfNeeded(File file) async {
  if (!Platform.isAndroid || await file.exists()) return;
  final bytes = await _backupChannel.invokeMethod<Uint8List>(
    'readDatabaseBackup',
  );
  if (bytes == null || bytes.isEmpty || !_looksLikeSqliteDatabase(bytes)) {
    return;
  }
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}

bool _looksLikeSqliteDatabase(Uint8List bytes) {
  const sqliteHeader = 'SQLite format 3\u0000';
  if (bytes.length < sqliteHeader.length) return false;
  for (var i = 0; i < sqliteHeader.length; i++) {
    if (bytes[i] != sqliteHeader.codeUnitAt(i)) return false;
  }
  return true;
}

Future<void> _deleteIfExists(File file) async {
  try {
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    // A missing or locked sidecar file should not block restoring the main DB.
  }
}
