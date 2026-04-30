import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/presentation/accounts_screen.dart';
import '../../categories/presentation/categories_screen.dart';
import '../../debts/presentation/debts_screen.dart';
import '../../export/presentation/csv_export_screen.dart';
import '../../recurring/presentation/recurring_screen.dart';
import '../../reports/presentation/reports_screen.dart';
import '../../saving_goals/presentation/saving_goals_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../tags/presentation/tags_screen.dart';
import '../../templates/presentation/templates_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          _Tile(
            icon: Icons.account_balance_wallet,
            title: 'Accounts',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AccountsScreen()),
            ),
          ),
          _Tile(
            icon: Icons.category,
            title: 'Categories',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CategoriesScreen()),
            ),
          ),
          _Tile(
            icon: Icons.tag,
            title: 'Tags',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TagsScreen()),
            ),
          ),
          _Tile(
            icon: Icons.savings,
            title: 'Saving Goals',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SavingGoalsScreen(),
              ),
            ),
          ),
          _Tile(
            icon: Icons.payments,
            title: 'Debts / Installments',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DebtsScreen()),
            ),
          ),
          _Tile(
            icon: Icons.repeat,
            title: 'Recurring Transactions',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RecurringScreen()),
            ),
          ),
          _Tile(
            icon: Icons.bolt,
            title: 'Quick Add Templates',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TemplatesScreen()),
            ),
          ),
          _Tile(
            icon: Icons.analytics,
            title: 'Reports',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ReportsScreen()),
            ),
          ),
          _Tile(
            icon: Icons.settings,
            title: 'Settings',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('CSV Export'),
            subtitle: const Text('Export transactions or all local data'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CsvExportScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(onTap == null ? 'Roadmap module' : 'Open'),
      onTap: onTap,
    );
  }
}
