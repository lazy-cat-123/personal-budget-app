# AGENT.md

## Project Overview

Build a **personal budget management mobile application** using:

- **Flutter** for the mobile app
- **Drift SQLite** for local relational data storage
- **CSV export** for backup and manual analysis
- Optional recommended packages: Riverpod, fl_chart, intl, flutter_local_notifications

The app is for **single-user personal use only**. Do not implement login, cloud sync, multi-user sharing, or server-side features in the first version.

---

## Main Goal

Create an offline-first personal finance app that helps the user manage:

- Income
- Expenses
- Transfers between accounts
- Credit card usage and payments
- Account balances
- Weekly and monthly category budgets
- Saving goals
- Debts, lending, and installments
- Recurring transactions with reminders
- Quick-add transaction templates
- Tags
- Daily, weekly, monthly, and yearly reports
- CSV export for backup and analysis

---

## Tech Stack Requirements

Use this stack unless explicitly instructed otherwise:

```text
Flutter
Drift SQLite
CSV export
Local device storage
```

Recommended libraries:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^latest
  drift: ^latest
  sqlite3_flutter_libs: ^latest
  path_provider: ^latest
  path: ^latest
  fl_chart: ^latest
  intl: ^latest
  flutter_local_notifications: ^latest
  csv: ^latest
```

Use exact package versions only after checking the current Flutter ecosystem. Do not assume old package versions.

---

## Architecture Guidelines

Use a maintainable feature-based structure.

Recommended structure:

```text
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants/
│   ├── errors/
│   ├── utils/
│   └── theme/
├── database/
│   ├── app_database.dart
│   ├── tables/
│   └── daos/
├── features/
│   ├── accounts/
│   ├── categories/
│   ├── transactions/
│   ├── budgets/
│   ├── saving_goals/
│   ├── debts/
│   ├── recurring/
│   ├── reports/
│   ├── templates/
│   └── settings/
└── shared/
    ├── widgets/
    └── providers/
```

Recommended internal flow:

```text
Flutter UI
  ↓
Riverpod Providers / State Notifiers
  ↓
Repository Layer
  ↓
Drift DAO Layer
  ↓
SQLite Database
```

---

## Development Principles

1. **Build offline-first.**
   - All data must be stored locally in SQLite.
   - The app must work without internet.

2. **Keep the app single-user.**
   - Do not add authentication.
   - Do not add roles or permissions.
   - Do not add cloud sync unless requested later.

3. **Use relational modeling properly.**
   - Do not store multiple tags as comma-separated text.
   - Use a join table for transaction tags.
   - Use references/foreign keys where appropriate.

4. **Separate calculated values from stored values.**
   - Store raw transaction data.
   - Calculate summaries, balances, and report values through queries or service methods.

5. **Avoid double-counting money.**
   - Transfers must affect account balances but not income/expense reports.
   - Credit card payments must affect account balances but not count as a second expense.
   - Credit card spending is counted when the card is used.

6. **Prefer simple MVP first.**
   - Do not build every feature at once.
   - Follow the roadmap in `requirement.md`.

7. **Make data exportable.**
   - CSV export is required.
   - Export should support transactions, full backup, and date range reports.

8. **Use clear naming.**
   - Database table names should use snake_case.
   - Dart classes should use PascalCase.
   - Variables and functions should use lowerCamelCase.

9. **Make it Maintainable**
   - Always make README.md about the project that new-commer can understand how the system works after read.
   - The document should have Overview, How the system works, Installation steps, and How to use. 

---

## Required Database Tables

Implement these Drift SQLite tables eventually:

```text
accounts
categories
transactions
budgets
saving_goals
goal_contributions
debts
debt_payments
recurring_transactions
quick_add_templates
tags
transaction_tags
settings
```

For Phase 1, start with:

```text
accounts
categories
transactions
tags
transaction_tags
settings
```

---

## Critical Business Rules

### Account Balance

Current balance must be calculated as:

```text
Current Balance =
Initial Balance
+ Income
- Expense
+ Transfer In
- Transfer Out
+ Manual Adjustment
```

For credit cards, spending increases card liability. Paying the credit card bill should reduce bank balance and reduce credit card liability without counting as another expense.

---

### Transaction Types

Supported transaction types:

```text
income
expense
transfer
credit_card_payment
```

Rules:

| Transaction Type | Count as Income | Count as Expense | Affects Account Balance |
|---|---:|---:|---:|
| income | Yes | No | Yes |
| expense | No | Yes | Yes |
| transfer | No | No | Yes |
| credit_card_payment | No | No | Yes |

---

### Transfer Rule

Transfers must appear in transaction history but must not be included in income, expense, budget usage, category spending, or monthly summaries.

Example:

```text
KBank → TrueMoney: 500 THB
```

This changes account balances only.

---

### Credit Card Rule

Credit card expense is counted when the credit card is used.

Credit card bill payment should be treated like a special transfer:

```text
Bank Account → Credit Card Account
```

It must not count as a second expense.

---

### Saving Goal Contribution Rule

Each saving goal must have a setting:

```text
count_contribution_as_expense
```

If true, contributions to that goal are included in expense reports. If false, contributions only affect goal progress and account balances.

---

### Debt Payment Rule

Debt payments must be interpreted based on debt type:

| Debt Type | Payment Meaning | Report Treatment |
|---|---|---|
| i_owe | User pays someone back | Expense |
| installment | User pays an installment | Expense |
| owed_to_me | Someone pays the user back | Income |

---

### Budget Rule

Budgets are not strict. The user may overspend.

Budget status:

```text
OK = spending is below alert threshold
Warning = spending reaches alert threshold but does not exceed budget amount
Over = spending exceeds budget amount
```

Budget usage should be calculated from expense transactions and relevant saving/debt records according to their business rules.

---

### Recurring Transaction Rule

Recurring transactions must not create transactions automatically in the first version.

Required behavior:

```text
Recurring item is near due date
→ App sends local notification
→ User opens app
→ User confirms or creates transaction manually
→ User can edit amount before saving
```

---

## Required Screens / Navigation

Use this bottom navigation:

```text
Home
Add
History
Budget
More
```

### Home

Show:

- Total balance
- Quick Add
- 7-day expense chart
- Remaining money this month
- Upcoming debt/installment due dates
- Budget warnings
- Saving goal progress
- Monthly summary

### Add

Provide actions for:

- Add income
- Add expense
- Add transfer
- Add credit card payment
- Add from template
- Add saving contribution
- Add debt payment

### History

Show transactions with filters:

- Date
- Month
- Type
- Category
- Account
- Tag
- Amount range

### Budget

Show:

- Category
- Period
- Budget amount
- Used amount
- Remaining amount
- Usage percentage
- Status

### More

Include links to:

- Accounts
- Categories
- Saving Goals
- Debts / Installments
- Recurring Transactions
- Quick Add Templates
- Reports
- Settings
- CSV Export

---

## MVP Roadmap

### Phase 1: Core Finance Tracker

Implement:

- Accounts
- Categories
- Transactions
- Tags
- Basic dashboard
- Transaction history
- CSV export for transactions

Goal:

```text
Record income, expenses, transfers, and see account balances.
```

### Phase 2: Budget

Implement:

- Budgets
- Budget usage percentage
- Budget warning status
- Weekly and monthly budget views

### Phase 3: Saving Goals + Debts

Implement:

- Saving goals
- Goal contributions
- Debts
- Debt payments
- Upcoming due dates

### Phase 4: Recurring + Templates

Implement:

- Recurring transactions
- Local reminders
- Quick-add templates
- Add transaction from template

### Phase 5: Advanced Reports + Full CSV Export

Implement:

- Yearly summary
- Tag reports
- Category trends
- Full database CSV export
- Date-range export

---

## What Not To Build Yet

Do not build these unless requested later:

- Login / authentication
- Cloud sync
- Supabase / Firebase integration
- Web dashboard
- Multi-user support
- Family sharing
- Paid subscription
- Bank API integration
- OCR receipt scanning
- AI finance advice

---

## Output Expectations for the Coding Agent

When generating code:

1. Start with Phase 1 unless explicitly told otherwise.
2. Keep files organized by feature.
3. Use Drift migrations properly.
4. Include basic sample seed data where helpful.
5. Write queries in DAO/repository classes, not directly in UI widgets.
6. Keep UI simple, mobile-friendly, and fast for daily use.
7. Avoid overengineering.
8. Explain important assumptions before making major structural changes.

