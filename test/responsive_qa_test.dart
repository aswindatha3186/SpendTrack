import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendtrack/main.dart';
import 'package:spendtrack/models/monthly_budget.dart';
import 'package:spendtrack/models/transaction.dart';
import 'package:spendtrack/services/budget_storage.dart';
import 'package:spendtrack/services/transaction_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('dashboard and transaction controls fit small and wide layouts', (
    tester,
  ) async {
    final transactions = [
      Transaction(
        id: 'responsive-expense',
        title: 'Responsive grocery purchase',
        category: 'Food',
        amount: 125.5,
        date: DateTime.now(),
        isIncome: false,
      ),
      Transaction(
        id: 'responsive-income',
        title: 'Monthly salary',
        category: 'Salary',
        amount: 1200,
        date: DateTime.now(),
        isIncome: true,
      ),
    ];
    await TransactionStorage().saveTransactions(transactions);
    final now = DateTime.now();
    await BudgetStorage().saveBudgets([
      MonthlyBudget(
        year: now.year,
        month: now.month,
        amount: 500,
        categoryLimits: {'Food': 200},
      ),
    ]);

    for (final size in [
      const Size(320, 640),
      const Size(360, 800),
      const Size(600, 900),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const SpendTrackApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'dashboard at $size');

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'history at $size');

      await tester.tap(find.byKey(const Key('open-transaction-filters')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'filter sheet at $size');
      await tester.tap(find.byKey(const Key('apply-transaction-filters')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'insights at $size');

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'profile at $size');

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('open-monthly-budgets')));
      await tester.tap(find.byKey(const Key('open-monthly-budgets')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'budgets at $size');
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('open-recurring-transactions')),
      );
      await tester.tap(find.byKey(const Key('open-recurring-transactions')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'recurring at $size');
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('open-notifications')));
      await tester.tap(find.byKey(const Key('open-notifications')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'notifications at $size');
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
