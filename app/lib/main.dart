import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'shared/providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  await _restoreSavedNotifications(container);
  runApp(UncontrolledProviderScope(container: container, child: const BudgetApp()));
}

Future<void> _restoreSavedNotifications(ProviderContainer container) async {
  final notificationService = container.read(notificationServiceProvider);
  await notificationService.initialize();
  final settings = await container.read(financeRepositoryProvider).watchSettings().first;
  if (settings.dailyReminderEnabled) {
    await notificationService.scheduleDailyExpenseReminder(
      hour: settings.dailyReminderHour,
      minute: settings.dailyReminderMinute,
    );
  } else {
    await notificationService.cancelDailyExpenseReminder();
  }
}
