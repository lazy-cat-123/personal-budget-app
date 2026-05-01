# Personal Budget App

## Overview

This is an offline-first Flutter app for single-user personal budget tracking.
The current implementation covers the core tracker, budget tracking, saving goals, debt tracking, quick-add templates, and recurring reminders:

- Accounts with add, edit, archive, manual adjustment, and calculated balances
- Income and expense categories with add, edit, archive, colors, notes, and default monthly budgets
- Tags with add, edit, archive, descriptions, and multi-tag transaction assignment
- Settings for currency preference, default account, theme mode, and daily expense reminder
- Full CSV export for all local data plus transaction date-range export
- Income, expense, transfer, and credit card payment transactions
- Default income and expense categories
- Tags through a relational join table
- Dashboard with total balance, monthly summary, account balances, and a 7-day expense chart
- Transaction history with type filtering
- Weekly and monthly category budget tracking
- Saving goals with contributions and progress tracking
- Debts, lending, and installment tracking with payment progress
- Quick-add templates for repeated income and expense entries
- Recurring transaction reminders with manual confirmation
- Reports dashboard with daily, 7-day, monthly, and yearly summaries
- Transactions CSV export copied to the clipboard

No login, cloud sync, server API, or multi-user behavior is included.

## How The System Works

The app uses this flow:

```text
Flutter UI
  -> Riverpod providers
  -> FinanceRepository
  -> Drift SQLite database
```

Important folders:

- `lib/database/app_database.dart` defines the Drift tables and local SQLite connection.
- `lib/features/finance/data/finance_repository.dart` contains balance, dashboard, transaction, and CSV logic.
- `lib/shared/providers/app_providers.dart` wires Drift and repositories into Riverpod.
- `lib/features/home`, `lib/features/add_transaction`, `lib/features/history`, `lib/features/budget`, `lib/features/saving_goals`, `lib/features/debts`, `lib/features/templates`, `lib/features/recurring`, and `lib/features/more` contain the main navigation screens.

The current database tables are:

- `accounts`
- `categories`
- `transactions`
- `budgets`
- `saving_goals`
- `goal_contributions`
- `debts`
- `debt_payments`
- `quick_add_templates`
- `recurring_transactions`
- `tags`
- `transaction_tags`
- `settings`

Transfers and credit card payments affect balances but are excluded from income and expense summaries.
Budget usage is calculated from expense transactions in the budget category only.
Saving goal contributions reduce the selected account balance. Each goal can choose whether contributions count as monthly expenses.
Debt payments create income or expense transactions based on debt type, so account balances and reports stay consistent.
Quick-add templates create normal income or expense transactions, so balances, history, budgets, and reports update through the same transaction flow.
Recurring transactions schedule local reminders only. They do not create transactions automatically; the user confirms and can edit the amount before saving.

## Installation Steps

1. Install Flutter and platform tooling for your target device.
2. On Windows, enable Developer Mode if Flutter reports that plugin symlinks are blocked.
3. Install dependencies:

```bash
flutter pub get
```

4. Generate Drift code after table changes:

```bash
dart run build_runner build --delete-conflicting-outputs
```

5. Run static analysis:

```bash
dart analyze lib test
```

6. Run the app:

```bash
flutter run
```

## How To Use

Use the bottom navigation:

- **Home**: View total balance, monthly income and expense, 7-day expense chart, accounts, and recent transactions.
- **Add**: Record income, expense, transfer, or credit card payment transactions.
- **History**: Review and filter transaction history by transaction type.
- **Budget**: Add weekly or monthly category budgets and track used amount, remaining amount, usage percentage, and OK/Warning/Over status.
- **More**: Open Accounts, Categories, Tags, Saving Goals, Debts / Installments, Quick Add Templates, Recurring Transactions, Reports, Settings, CSV Export, and access roadmap modules.

Accounts:

- Open **More > Accounts**.
- Add or edit cash, bank, e-wallet, debit card, credit card, saving, investment, or other accounts.
- Use manual adjustment to increase or decrease an account balance without counting it as income or expense.
- Archive accounts that should no longer appear in active account pickers and balances.

Categories:

- Open **More > Categories**.
- Manage expense and income categories in separate tabs.
- Add or edit category name, color, note, and default monthly budget for expense categories.
- Archive categories that should no longer appear in active category pickers.
- Budget creation prefills the amount from the selected expense category default monthly budget when available.

Tags:

- Open **More > Tags**.
- Add or edit tag name and description.
- Archive tags that should no longer appear in transaction tag chips.
- Assign multiple active tags while adding a transaction.

Settings:

- Open **More > Settings**.
- Save currency preference, default account, app theme mode, and daily expense reminder.
- The default account is used to preselect the account when adding a normal income or expense transaction.
- Daily expense reminders use local notifications only and are restored on app startup.

CSV Export:

- Open **More > CSV Export**.
- Download all local data as CSV files for backup.
- Download transactions only, with optional from-day and to-day filters.
- Individual exported CSV sections can be copied again from the latest export list.

Persistent Backup:

- On Android, the app keeps an automatic SQLite backup in **Downloads > PersonalBudgetBackups**.
- The backup is refreshed when the database opens and after data changes.
- If the app is uninstalled and reinstalled, it restores from that phone backup when the private database is missing.

Saving Goals:

- Open **More > Saving Goals**.
- Add a goal with target amount, optional target date, and expense-counting preference.
- Add contributions from an account to update progress and account balance.

Debts / Installments:

- Open **More > Debts / Installments**.
- Add an item as I owe, Owed to me, or Installment.
- Add payments from an account to update paid amount, remaining amount, and status.
- Payments for I owe and Installment count as expenses. Payments for Owed to me count as income.

Quick Add Templates:

- Open **More > Quick Add Templates**.
- Create templates for repeated income or expense entries.
- Tap a template to edit the amount before adding the transaction.
- Home shows frequently used templates as quick-add chips.

Recurring Transactions:

- Open **More > Recurring Transactions**.
- Add repeated income or expense reminders with weekly, monthly, or yearly frequency.
- The app schedules a local notification before the due date.
- Use **Create transaction** from a recurring item to confirm and save the actual transaction.
- The next due date advances only after confirmation.

Reports:

- Open **More > Reports**.
- Use the tabs to review today, last 7 days, this month, and this year.
- Reports show income, expense, net amount, spending by category, top categories, budget usage, saving goal progress, upcoming debts, and recent activity.

The app seeds default accounts, categories, and tags the first time the local database is opened.
