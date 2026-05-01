import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/finance/domain/finance_models.dart';
import '../../../shared/providers/app_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  AppSettings? _loadedSettings;
  String _currencyCode = 'THB';
  int? _defaultAccountId;
  bool _dailyReminderEnabled = false;
  TimeOfDay _dailyReminderTime = const TimeOfDay(hour: 20, minute: 0);
  String _themeMode = 'system';

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final accounts = ref.watch(accountBalancesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settings.when(
        data: (data) {
          _syncFromSettings(data);
          return accounts.when(
            data: (accountItems) {
              final validDefaultAccountId = accountItems.any(
                (account) => account.account.id == _defaultAccountId,
              )
                  ? _defaultAccountId
                  : null;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SectionCard(
                    title: 'Display',
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _currencyCode,
                          decoration: const InputDecoration(
                            labelText: 'Currency',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'THB', child: Text('THB')),
                            DropdownMenuItem(value: 'USD', child: Text('USD')),
                            DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                            DropdownMenuItem(value: 'JPY', child: Text('JPY')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _currencyCode = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _themeMode,
                          decoration: const InputDecoration(labelText: 'Theme'),
                          items: const [
                            DropdownMenuItem(
                              value: 'system',
                              child: Text('System'),
                            ),
                            DropdownMenuItem(
                              value: 'light',
                              child: Text('Light'),
                            ),
                            DropdownMenuItem(
                              value: 'dark',
                              child: Text('Dark'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _themeMode = value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Defaults',
                    child: DropdownButtonFormField<int?>(
                      initialValue: validDefaultAccountId,
                      decoration: const InputDecoration(
                        labelText: 'Default account',
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('No default'),
                        ),
                        for (final account in accountItems)
                          DropdownMenuItem<int?>(
                            value: account.account.id,
                            child: Text(account.account.name),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _defaultAccountId = value),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Daily Reminder',
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Record expenses reminder'),
                          subtitle: Text(_dailyReminderTime.format(context)),
                          value: _dailyReminderEnabled,
                          onChanged: (value) =>
                              setState(() => _dailyReminderEnabled = value),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _pickReminderTime,
                            icon: const Icon(Icons.schedule),
                            label: const Text('Reminder time'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Settings'),
                  ),
                ],
              );
            },
            error: (error, stackTrace) => Center(child: Text('$error')),
            loading: () => const Center(child: CircularProgressIndicator()),
          );
        },
        error: (error, stackTrace) => Center(child: Text('$error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _syncFromSettings(AppSettings settings) {
    if (_loadedSettings == settings) return;
    _loadedSettings = settings;
    _currencyCode = settings.currencyCode;
    _defaultAccountId = settings.defaultAccountId;
    _dailyReminderEnabled = settings.dailyReminderEnabled;
    _dailyReminderTime = TimeOfDay(
      hour: settings.dailyReminderHour,
      minute: settings.dailyReminderMinute,
    );
    _themeMode = settings.themeMode;
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dailyReminderTime,
    );
    if (picked != null) {
      setState(() => _dailyReminderTime = picked);
    }
  }

  Future<void> _saveSettings() async {
    final settings = AppSettings(
      currencyCode: _currencyCode,
      defaultAccountId: _defaultAccountId,
      dailyReminderEnabled: _dailyReminderEnabled,
      dailyReminderHour: _dailyReminderTime.hour,
      dailyReminderMinute: _dailyReminderTime.minute,
      themeMode: _themeMode,
    );

    try {
      if (_dailyReminderEnabled) {
        await ref.read(notificationServiceProvider).scheduleDailyExpenseReminder(
            hour: _dailyReminderTime.hour,
            minute: _dailyReminderTime.minute,
          );
      } else {
        await ref.read(notificationServiceProvider).cancelDailyExpenseReminder();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not schedule reminder: $error')),
      );
      return;
    }

    await ref.read(financeRepositoryProvider).saveSettings(settings);

    ref.invalidate(appSettingsProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Settings saved')));
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
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
