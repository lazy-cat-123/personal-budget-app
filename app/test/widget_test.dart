import 'package:app/app.dart';
import 'package:app/database/app_database.dart';
import 'package:app/shared/providers/app_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('shows the budget dashboard', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const BudgetApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Personal Budget'), findsOneWidget);
    expect(find.text('Total Balance'), findsOneWidget);
    expect(find.text('Quick Add'), findsOneWidget);
  });
}
