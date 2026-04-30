# Personal Budget Management App — Feature Requirements

## 1. App Goal

Build a **mobile personal finance app** for one user to manage:

- Income
- Expenses
- Account balances
- Category budgets
- Saving goals
- Debts, borrowed money, lending, and installments
- Recurring transactions
- Quick-add templates
- Reports and summaries
- CSV export for backup and manual analysis

The app is for **personal use only**, so it does not need login, multi-user access, cloud sync, or server-side features in the first version.

---

## 2. Tech Stack

| Area | Tool |
|---|---|
| Mobile app | Flutter |
| Local database | Drift SQLite |
| State management | Riverpod, recommended |
| Charts | fl_chart, recommended |
| Date/number formatting | intl |
| Local reminders | flutter_local_notifications |
| Export | CSV export |
| Storage | Local device storage |

Recommended architecture:

```text
Flutter App
   ↓
Riverpod Providers
   ↓
Repository Layer
   ↓
Drift SQLite
   ↓
CSV Export / Backup
```

---

## 3. Core Modules

### 3.1 Dashboard / Home

The home screen should show the most important financial overview first.

Required dashboard items:

- Total balance across all active accounts
- Quick Add button
- 7-day expense chart
- Remaining money this month
- Upcoming debt / installment due dates
- Budget warning
- Saving goal progress
- Monthly summary

Priority order:

1. Total balance
2. Quick Add
3. 7-day expense chart
4. Remaining money this month
5. Upcoming debt / installment

---

### 3.2 Accounts / Wallets

The app must support multiple account types.

Account types:

- Cash
- Bank account
- E-wallet
- Debit card
- Credit card
- Saving account
- Investment account
- Other

Each account should support:

- Account name
- Account type
- Initial balance
- Start date
- Manual balance adjustment
- Calculated balance
- Current balance
- Active / archived status
- Color or icon
- Note

Balance rule:

```text
Current Balance =
Initial Balance
+ Income
- Expense
+ Transfer In
- Transfer Out
+ Manual Adjustment
```

---

### 3.3 Credit Card Tracking

Credit cards should be supported as an account type.

Credit card fields:

- Credit limit
- Billing cycle start day
- Billing cycle end day
- Payment due day
- Amount due
- Payment status: paid / unpaid / partial

Credit card rule:

- Credit card expenses should be counted in reports **when the card is used**.
- Credit card bill payment should affect account balances but should **not** count as a second expense.

Example:

```text
Bank Account → Credit Card Account
```

This reduces the bank account balance and reduces credit card liability, but it does not increase monthly expense again.

---

### 3.4 Categories

The app should support income and expense categories.

Required category fields:

- Category name
- Category type: income / expense
- Default monthly budget
- Color or icon
- Active / archived status
- Note

Default expense categories:

```text
Food
Transport
Rent / Dorm
Utilities
Internet / Phone
Education
Books / Courses
Games / Entertainment
Personal Items
Health
Clothes
Computer / Technology
Saving
Debt / Installment
Other
```

Default income categories:

```text
Family Support
Salary / Part-time
Freelance
Selling
Interest / Dividend
Refund
Debt Repayment Received
Other
```

---

## 4. Transaction Management

### 4.1 Transaction Types

The app must support:

- Income
- Expense
- Transfer
- Credit card payment

---

### 4.2 Transaction Fields

Each transaction should support:

- Date
- Time
- Transaction type
- Category
- Amount
- Payment method
- Account
- From account
- To account
- Tags
- Note
- Created at
- Updated at

---

### 4.3 Transfer Rule

Transfers should be shown in transaction history, but should not count in income or expense summaries.

Example:

```text
KBank → TrueMoney: 500 THB
```

This should affect account balances but not monthly income/expense.

---

### 4.4 Payment Methods

Supported payment methods:

- Cash
- Transfer
- Debit card
- Credit card
- E-wallet

---

## 5. Quick Add & Templates

### 5.1 Quick Add

Quick Add should allow the user to quickly record a transaction with minimal fields:

- Amount
- Category
- Account
- Note, optional

---

### 5.2 Detailed Add

Detailed Add should allow full transaction input:

- Date
- Time
- Transaction type
- Category
- Amount
- Payment method
- Account
- Tags
- Note

---

### 5.3 Templates

The app should support reusable transaction templates.

Template fields:

- Template name
- Transaction type
- Default category
- Default account
- Default amount
- Default note
- Use count
- Active / archived status

Templates should allow the user to edit the amount before saving.

Example templates:

```text
Lunch
Coffee
Bus fare
Phone bill
Game purchase
```

---

## 6. Budget Management

### 6.1 Budget Types

Budgets should be set by category.

Supported budget periods:

- Weekly
- Monthly

---

### 6.2 Budget Fields

Each budget should support:

- Category
- Period type: weekly / monthly
- Budget amount
- Start date
- End date
- Alert threshold
- Used amount
- Remaining amount
- Usage percentage
- Status

---

### 6.3 Budget Behavior

Budgets are **not strict**. The user can spend over the budget, but the app should show:

- Warning
- Status
- Usage percentage

Budget status:

```text
OK = spending is below alert threshold
Warning = spending reaches alert threshold but does not exceed budget amount
Over = spending exceeds budget amount
```

Example:

```text
Food budget: 3,000 THB
Used: 2,500 THB
Usage: 83%
Status: Warning
```

---

## 7. Saving Goals

The app should support multiple saving goals.

### 7.1 Saving Goal Fields

Each saving goal should support:

- Goal name
- Target amount
- Target date
- Current amount
- Progress percentage
- Status: active / completed / paused
- Note
- Whether contribution counts as expense

---

### 7.2 Goal Contributions

Saving contributions should be stored separately.

Contribution fields:

- Goal
- Date
- Amount
- Account
- Note
- Created at

---

### 7.3 Saving Contribution Rule

Each saving goal can choose whether contributions count as expenses.

Example:

| Goal | Count as Expense? |
|---|---:|
| New laptop | Yes |
| Emergency fund | No |

---

## 8. Debt / Lending / Installment Tracking

The app should support:

- Money the user owes
- Money other people owe the user
- Installment purchases

### 8.1 Debt Types

Supported debt types:

- I Owe
- Owed To Me
- Installment

---

### 8.2 Debt Fields

Each debt item should support:

- Debt type
- Debt name
- Person name / shop / lender
- Total amount
- Start date
- Due date
- Paid amount
- Remaining amount
- Status: active / completed
- Note

---

### 8.3 Debt Payments

Debt payments should be stored separately.

Payment fields:

- Debt
- Date
- Amount
- Account
- Note
- Created at

---

### 8.4 Debt Report Rule

| Debt Type | Payment Meaning | Report Treatment |
|---|---|---|
| I Owe | User pays someone back | Expense |
| Installment | User pays installment | Expense |
| Owed To Me | Someone pays user back | Income |

---

## 9. Recurring Transactions

The app should support recurring transactions with reminder only.

### 9.1 Recurring Transaction Fields

Each recurring transaction should support:

- Recurring name
- Transaction type: income / expense
- Category
- Account
- Default amount
- Frequency: weekly / monthly / yearly
- Next due date
- End date, optional
- Status: active / paused
- Reminder before days
- Note

---

### 9.2 Recurring Behavior

Recurring transactions should **not** create transactions automatically.

Workflow:

```text
Recurring item is near due date
→ App sends local notification
→ User opens app
→ User confirms/adds transaction manually
→ User can edit amount before saving
```

This is important because the amount of income or expense can change each cycle.

---

## 10. Tags

Tags should be used for:

- Separating contexts
- Searching transactions
- Extra reports

Example tags:

```text
school
game
health
study
personal
project
food
transport
urgent
```

Tag features:

- Tag name
- Description
- Active / archived status

Transactions can have multiple tags.

---

## 11. Reports & Summary

The app should include daily, weekly, monthly, and yearly summaries.

### 11.1 Daily Summary

Show:

- Today’s income
- Today’s expense
- Today’s net amount
- Recent transactions

---

### 11.2 Last 7 Days Summary

Show:

- 7-day expense chart
- Average expense per day
- Highest spending day
- Comparison with previous 7 days

---

### 11.3 Monthly Summary

Show:

- Total income this month
- Total expense this month
- Remaining money this month
- Spending by category
- Budget usage
- Top spending categories
- Saving goal progress
- Debt / installment due soon

---

### 11.4 Yearly Summary

Show:

- Total yearly income
- Total yearly expense
- Yearly net amount
- Average expense per month
- Highest spending month
- Top spending category of the year

---

## 12. CSV Export

The app should support CSV export for backup and analysis.

### 12.1 Export Scope

The app should allow exporting:

- Transactions
- Accounts
- Categories
- Budgets
- Saving goals
- Goal contributions
- Debts
- Debt payments
- Recurring transactions
- Quick add templates
- Tags

---

### 12.2 Export Options

Recommended export options:

- Export all data
- Export transactions only
- Export by date range
- Export monthly report
- Export yearly report

---

### 12.3 CSV Use Cases

CSV export should support:

- Backup
- Opening in Excel / Google Sheets
- Manual analysis
- Moving data to another system later

---

## 13. Notifications

The app should support local notifications.

Required notifications:

- Daily reminder to record expenses
- Saving goal reminder
- Recurring transaction reminder

Notification behavior:

- Notifications should be local-only.
- Notifications should work without cloud.

---

## 14. App Navigation

Recommended bottom navigation:

```text
Home
Add
History
Budget
More
```

### Home

Shows dashboard.

### Add

Shows:

- Add income
- Add expense
- Add transfer
- Add credit card payment
- Add from template
- Add saving contribution
- Add debt payment

### History

Shows transactions with filters:

- Date
- Month
- Type
- Category
- Account
- Tag
- Amount range

### Budget

Shows budget list and usage status.

### More

Contains:

- Accounts
- Categories
- Saving goals
- Debts / installments
- Recurring
- Templates
- Reports
- Settings
- CSV export

---

## 15. Data Tables for Drift SQLite

Recommended tables:

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

Because SQLite is relational, tags should use a join table:

```text
transactions
tags
transaction_tags
```

---

## 16. MVP Roadmap

Even though the full feature set is clear, the app should be built in phases.

### Phase 1: Core Finance Tracker

Build first:

- Accounts
- Categories
- Transactions
- Tags
- Basic dashboard
- Transaction history
- CSV export for transactions

Goal:

```text
Record income/expenses and see account balances.
```

---

### Phase 2: Budget

Add:

- Budgets
- Budget usage
- Warning status
- Monthly and weekly budget views

Goal:

```text
Track category spending against budget.
```

---

### Phase 3: Saving Goals + Debts

Add:

- Saving goals
- Goal contributions
- Debts
- Debt payments
- Upcoming due dates

Goal:

```text
Track savings, debts, lending, and installments.
```

---

### Phase 4: Recurring + Templates

Add:

- Recurring transactions
- Local reminders
- Quick-add templates
- Add transaction from template

Goal:

```text
Make data entry faster and reduce repeated input.
```

---

### Phase 5: Advanced Reports + Full CSV Export

Add:

- Yearly summary
- Tag reports
- Category trends
- Full database CSV export
- Date-range export

Goal:

```text
Analyze spending patterns and back up all data.
```

---

## 17. Final Simplified Requirement Statement

```text
Build a personal budget management mobile app using Flutter and Drift SQLite.
The app stores all data locally on the user’s device and supports CSV export for backup and analysis.

The app must manage accounts, income, expenses, transfers, credit card payments, budgets, saving goals, debts, recurring transactions, quick-add templates, tags, notifications, dashboards, and reports.

The app is for single-user personal use only, with no cloud sync, no login, and no multi-user features required in the first version.
```

