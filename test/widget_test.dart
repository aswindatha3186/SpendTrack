import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendtrack/main.dart';
import 'package:spendtrack/models/monthly_budget.dart';
import 'package:spendtrack/models/transaction.dart';
import 'package:spendtrack/services/budget_storage.dart';
import 'package:spendtrack/services/notification_storage.dart';
import 'package:spendtrack/services/transaction_storage.dart';

void main() {
  const savedTransactionsKey = 'spendtrack_transactions';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('transaction JSON preserves all transaction fields', () {
    final transaction = Transaction(
      id: 'transaction-1',
      title: 'Monthly salary',
      category: 'Salary',
      amount: 1250.75,
      date: DateTime(2026, 11, 4, 9, 30),
      isIncome: true,
    );

    final restored = Transaction.fromJson(transaction.toJson());

    expect(restored.id, transaction.id);
    expect(restored.title, transaction.title);
    expect(restored.category, transaction.category);
    expect(restored.amount, transaction.amount);
    expect(restored.date, transaction.date);
    expect(restored.isIncome, transaction.isIncome);
  });

  test(
    'storage returns null for a first install and preserves empty data',
    () async {
      final storage = TransactionStorage();

      expect(await storage.loadTransactions(), isNull);

      await storage.saveTransactions([]);

      expect(await storage.loadTransactions(), isEmpty);
    },
  );

  test(
    'storage skips duplicate transaction IDs when loading and saving',
    () async {
      final storage = TransactionStorage();
      final transaction = Transaction(
        id: 'duplicate-id',
        title: 'Bus fare',
        category: 'Travel',
        amount: 25,
        date: DateTime(2026, 11, 4),
        isIncome: false,
      );

      await storage.saveTransactions([transaction, transaction]);
      final loaded = await storage.loadTransactions();

      expect(loaded, hasLength(1));
      expect(loaded!.single.id, transaction.id);

      SharedPreferences.setMockInitialValues({
        savedTransactionsKey: jsonEncode([
          transaction.toJson(),
          transaction.toJson(),
        ]),
      });
      expect(await storage.loadTransactions(), hasLength(1));
    },
  );

  testWidgets('app loads persisted transactions and retains all four tabs', (
    tester,
  ) async {
    final storedTransactions = [
      Transaction(
        id: 'salary',
        title: 'Salary',
        category: 'Salary',
        amount: 1200,
        date: DateTime(2026, 11, 4),
        isIncome: true,
      ),
      Transaction(
        id: 'rent',
        title: 'Rent',
        category: 'Housing',
        amount: 300,
        date: DateTime(2026, 11, 3),
        isIncome: false,
      ),
    ];
    SharedPreferences.setMockInitialValues({
      savedTransactionsKey: jsonEncode(
        storedTransactions.map((transaction) => transaction.toJson()).toList(),
      ),
    });

    await tester.pumpWidget(const SpendTrackApp());
    await tester.pumpAndSettle();

    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('₹900.00'), findsOneWidget);
    expect(find.text('₹1200.00'), findsOneWidget);
    expect(find.text('₹300.00'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
    expect(find.text('Housing'), findsWidgets);
  });

  testWidgets('first launch saves sample transactions only once', (
    tester,
  ) async {
    await tester.pumpWidget(const SpendTrackApp());
    await tester.pumpAndSettle();

    expect(find.text('Grocery Shopping'), findsOneWidget);

    final storage = TransactionStorage();
    final firstLoad = await storage.loadTransactions();
    expect(firstLoad, hasLength(4));

    await tester.pumpWidget(const SpendTrackApp());
    await tester.pumpAndSettle();

    expect(await storage.loadTransactions(), hasLength(4));
  });

  testWidgets('adding a transaction persists it and updates the dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(const SpendTrackApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'New groceries');
    await tester.enterText(find.byType(TextField).at(1), '45.50');
    await tester.ensureVisible(find.text('Save Transaction'));
    await tester.tap(find.text('Save Transaction'));
    await tester.pumpAndSettle();

    expect(find.text('New groceries'), findsOneWidget);
    expect(find.text('₹3534.50'), findsOneWidget);

    final loadedTransactions = await TransactionStorage().loadTransactions();
    expect(loadedTransactions, hasLength(5));
    expect(loadedTransactions!.first.title, 'New groceries');
    expect(loadedTransactions.first.amount, 45.5);
    final notifications = await NotificationStorage().loadNotifications();
    expect(notifications, hasLength(1));
    expect(notifications.single.title, 'Transaction added');

    await tester.tap(find.byKey(const Key('open-notifications')));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Transaction added'), findsOneWidget);
    expect(find.textContaining('New groceries'), findsOneWidget);
  });

  testWidgets('adding a transaction refreshes current budget alerts', (
    tester,
  ) async {
    final now = DateTime.now();
    await TransactionStorage().saveTransactions([
      Transaction(
        id: 'existing-expense',
        title: 'Existing expense',
        category: 'Food',
        amount: 69,
        date: now,
        isIncome: false,
      ),
    ]);
    await BudgetStorage().saveBudgets([
      MonthlyBudget(year: now.year, month: now.month, amount: 100),
    ]);

    await tester.pumpWidget(const SpendTrackApp());
    await tester.pumpAndSettle();
    expect(await NotificationStorage().loadNotifications(), isEmpty);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Threshold expense');
    await tester.enterText(find.byType(TextField).at(1), '1');
    await tester.ensureVisible(find.text('Save Transaction'));
    await tester.tap(find.text('Save Transaction'));
    await tester.pumpAndSettle();

    final notifications = await NotificationStorage().loadNotifications();
    expect(
      notifications.where((item) => item.title == 'Monthly budget reached 70%'),
      hasLength(1),
    );
    expect(notifications, hasLength(2));
  });

  testWidgets('transaction search and filters combine and clear together', (
    tester,
  ) async {
    final savedTransactions = [
      Transaction(
        id: 'filter-food-old',
        title: 'Market groceries',
        category: 'Food',
        amount: 70,
        date: DateTime(2026, 11, 1, 21),
        isIncome: false,
      ),
      Transaction(
        id: 'filter-food-new',
        title: 'Weekly groceries',
        category: 'Food',
        amount: 120,
        date: DateTime(2026, 11, 3),
        isIncome: false,
      ),
      Transaction(
        id: 'filter-travel',
        title: 'Bus pass',
        category: 'Travel',
        amount: 95,
        date: DateTime(2026, 11, 2),
        isIncome: false,
      ),
      Transaction(
        id: 'filter-salary',
        title: 'Monthly salary',
        category: 'Salary',
        amount: 120,
        date: DateTime(2026, 11, 4),
        isIncome: true,
      ),
    ];
    SharedPreferences.setMockInitialValues({
      savedTransactionsKey: jsonEncode(
        savedTransactions.map((transaction) => transaction.toJson()).toList(),
      ),
    });

    await tester.pumpWidget(const SpendTrackApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('transaction-tile-filter-food-old')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('open-transaction-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('transaction-type-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expense').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('transaction-category-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('transaction-minimum-amount-filter')),
      '50',
    );
    await tester.enterText(
      find.byKey(const Key('transaction-maximum-amount-filter')),
      '130',
    );
    await tester.tap(find.byKey(const Key('transaction-sort-order')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Highest amount').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('apply-transaction-filters')),
    );
    await tester.tap(find.byKey(const Key('apply-transaction-filters')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('transaction-tile-filter-food-new')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('transaction-tile-filter-food-old')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('transaction-tile-filter-travel')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('transaction-tile-filter-salary')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const Key('transaction-search-field')),
      'groceries',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('transaction-tile-filter-food-new')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('transaction-tile-filter-food-old')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('transaction-search-field')),
      'no matching transaction',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('transaction-results-empty-state')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('clear-all-transaction-filters')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('transaction-tile-filter-food-new')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('transaction-tile-filter-travel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('transaction-tile-filter-salary')),
      findsOneWidget,
    );
  });

  testWidgets(
    'editing persists every field and recalculates dashboard and insights',
    (tester) async {
      final expense = Transaction(
        id: 'editable-expense',
        title: 'Old purchase',
        category: 'Food',
        amount: 100,
        date: DateTime(2026, 11, 4),
        isIncome: false,
      );
      final income = Transaction(
        id: 'existing-income',
        title: 'Allowance',
        category: 'Allowance',
        amount: 500,
        date: DateTime(2026, 11, 1),
        isIncome: true,
      );
      SharedPreferences.setMockInitialValues({
        savedTransactionsKey: jsonEncode([expense.toJson(), income.toJson()]),
      });

      await tester.pumpWidget(const SpendTrackApp());
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('transaction-menu-editable-expense')),
      );
      await tester.tap(
        find.byKey(const Key('transaction-menu-editable-expense')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit').last);
      await tester.pumpAndSettle();

      expect(find.text('Edit Transaction'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), '');
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a valid description and amount.'),
        findsOneWidget,
      );
      expect(find.text('Edit Transaction'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'New allowance');
      await tester.enterText(find.byType(TextField).at(1), '200');
      final incomeSegment = find.descendant(
        of: find.byType(SegmentedButton<bool>),
        matching: find.text('Income'),
      );
      await tester.tap(incomeSegment);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allowance').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('transaction-date-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('New allowance'), findsOneWidget);
      expect(find.text('Allowance • 3/11/2026'), findsOneWidget);
      expect(find.text('₹700.00'), findsNWidgets(2));
      expect(find.text('₹0.00'), findsWidgets);

      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();
      expect(find.text('₹700.00'), findsWidgets);
      expect(find.text('₹0.00'), findsWidgets);
      expect(find.text('Food'), findsNothing);

      final savedTransactions = await TransactionStorage().loadTransactions();
      expect(savedTransactions, hasLength(2));
      final savedExpense = savedTransactions!.firstWhere(
        (transaction) => transaction.id == expense.id,
      );
      expect(savedExpense.title, 'New allowance');
      expect(savedExpense.amount, 200);
      expect(savedExpense.category, 'Allowance');
      expect(savedExpense.isIncome, isTrue);
      expect(savedExpense.date, DateTime(2026, 11, 3));
      final savedNotifications = await NotificationStorage()
          .loadNotifications();
      expect(savedNotifications, hasLength(1));
      expect(savedNotifications.single.title, 'Transaction updated');
    },
  );

  testWidgets('deletion requires confirmation and persists immediately', (
    tester,
  ) async {
    final expense = Transaction(
      id: 'deletable-expense',
      title: 'Remove me',
      category: 'Food',
      amount: 100,
      date: DateTime(2026, 11, 4),
      isIncome: false,
    );
    SharedPreferences.setMockInitialValues({
      savedTransactionsKey: jsonEncode([expense.toJson()]),
    });

    await tester.pumpWidget(const SpendTrackApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('transaction-menu-deletable-expense')),
    );
    await tester.tap(
      find.byKey(const Key('transaction-menu-deletable-expense')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Delete transaction?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Remove me'), findsOneWidget);
    expect(await TransactionStorage().loadTransactions(), hasLength(1));

    await tester.ensureVisible(
      find.byKey(const Key('transaction-menu-deletable-expense')),
    );
    await tester.tap(
      find.byKey(const Key('transaction-menu-deletable-expense')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Remove me'), findsNothing);
    expect(find.text('No transactions yet.'), findsOneWidget);
    expect(find.text('₹0.00'), findsNWidgets(3));
    expect(await TransactionStorage().loadTransactions(), isEmpty);
    final savedNotifications = await NotificationStorage().loadNotifications();
    expect(savedNotifications, hasLength(1));
    expect(savedNotifications.single.title, 'Transaction deleted');

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
    expect(find.text('No expenses in this date range.'), findsOneWidget);
  });
}
