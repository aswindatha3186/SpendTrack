import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendtrack/budgets/budget_calculator.dart';
import 'package:spendtrack/budgets/monthly_budget_screen.dart';
import 'package:spendtrack/models/monthly_budget.dart';
import 'package:spendtrack/models/transaction.dart';
import 'package:spendtrack/services/budget_storage.dart';
import 'package:spendtrack/services/transaction_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('monthly calculations count only expenses for that budget month', () {
    final budget = MonthlyBudget(
      year: 2026,
      month: 5,
      amount: 1000,
      categoryLimits: {'Food': 300, 'Travel': 200},
    );
    final progress = BudgetProgress.calculate(budget, [
      _transaction('food-1', DateTime(2026, 5, 2), 150, 'Food'),
      _transaction('food-2', DateTime(2026, 5, 8), 100, 'Food'),
      _transaction('travel', DateTime(2026, 5, 9), 120, 'Travel'),
      _transaction('income', DateTime(2026, 5, 10), 5000, 'Salary', true),
      _transaction('previous-month', DateTime(2026, 4, 30), 200, 'Food'),
      _transaction('next-month', DateTime(2026, 6, 1), 300, 'Food'),
    ]);

    expect(progress.spent, 370);
    expect(progress.remaining, 630);
    expect(progress.percentConsumed, 37);
    expect(progress.isApproaching, isFalse);
    expect(progress.isExceeded, isFalse);
    expect(progress.categorySpending, {'Food': 250, 'Travel': 120});
    expect(progress.categories.first.category, 'Food');
    expect(progress.categories.first.remaining, 50);
  });

  test(
    'budget status thresholds are safe at approach and overspend values',
    () {
      final budget = MonthlyBudget(
        year: 2026,
        month: 5,
        amount: 100,
        categoryLimits: {'Food': 50},
      );
      final approaching = BudgetProgress.calculate(budget, [
        _transaction('approaching', DateTime(2026, 5, 1), 70, 'Food'),
      ]);
      final exceeded = BudgetProgress.calculate(budget, [
        _transaction('exceeded', DateTime(2026, 5, 1), 110, 'Food'),
      ]);

      expect(approaching.isApproaching, isTrue);
      expect(approaching.isExceeded, isFalse);
      expect(exceeded.isApproaching, isFalse);
      expect(exceeded.isExceeded, isTrue);
      expect(exceeded.remaining, -10);
      expect(exceeded.categories.single.percentConsumed, closeTo(220, 0.0001));
    },
  );

  test(
    'budget storage creates, edits and deletes without touching transactions',
    () async {
      final storage = BudgetStorage();
      final firstBudget = MonthlyBudget(
        year: 2026,
        month: 5,
        amount: 1000,
        categoryLimits: {'Food': 250},
      );
      await storage.upsertBudget(firstBudget);
      final loadedFirst = await storage.loadBudgets();
      expect(loadedFirst, hasLength(1));
      expect(loadedFirst.single.id, firstBudget.id);
      expect(loadedFirst.single.amount, firstBudget.amount);
      expect(loadedFirst.single.categoryLimits, firstBudget.categoryLimits);

      final editedBudget = MonthlyBudget(
        id: firstBudget.id,
        year: 2026,
        month: 5,
        amount: 1200,
        categoryLimits: {'Food': 300, 'Travel': 200},
      );
      await storage.upsertBudget(editedBudget);
      final afterEdit = await storage.loadBudgets();
      expect(afterEdit, hasLength(1));
      expect(afterEdit.single.amount, 1200);
      expect(afterEdit.single.categoryLimits, {'Food': 300, 'Travel': 200});

      await storage.deleteBudget(editedBudget.id);
      expect(await storage.loadBudgets(), isEmpty);
    },
  );

  testWidgets('budget changes persist and the overview reflects transactions', (
    tester,
  ) async {
    final now = DateTime.now();
    final transactions = [
      _transaction(
        'food-expense',
        DateTime(now.year, now.month, 4),
        175,
        'Food',
      ),
      _transaction(
        'income',
        DateTime(now.year, now.month, 5),
        2000,
        'Income',
        true,
      ),
    ];
    final storage = BudgetStorage();
    var budgets = <MonthlyBudget>[];

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => MonthlyBudgetScreen(
            initialBudgets: budgets,
            transactions: transactions,
            onSaveBudgets: (updatedBudgets) async {
              await storage.saveBudgets(updatedBudgets);
              setState(() => budgets = updatedBudgets);
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('add-monthly-budget')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('budget-total-field')), '500');
    await tester.enterText(
      find.byKey(const Key('category-budget-field-Food')),
      '200',
    );
    final saveButton = find.byKey(const Key('save-monthly-budget'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('₹175.00 / ₹200.00'), findsOneWidget);
    expect(find.text('35.0% used'), findsOneWidget);
    expect(find.text('Food spending is approaching its limit'), findsOneWidget);
    expect(await storage.loadBudgets(), hasLength(1));

    final savedBudget = (await storage.loadBudgets()).single;
    await tester.tap(find.byKey(Key('budget-menu-${savedBudget.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('budget-total-field')), '600');
    await tester.enterText(
      find.byKey(const Key('category-budget-field-Food')),
      '400',
    );
    final editSaveButton = find.byKey(const Key('save-monthly-budget'));
    await tester.ensureVisible(editSaveButton);
    await tester.tap(editSaveButton);
    await tester.pumpAndSettle();

    expect(find.text('₹175.00 / ₹400.00'), findsOneWidget);
    expect((await storage.loadBudgets()).single.amount, 600);

    await tester.tap(find.byKey(Key('budget-menu-${savedBudget.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Delete monthly budget?'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('No budgets yet'), findsOneWidget);
    expect(await storage.loadBudgets(), isEmpty);
  });

  test(
    'budget reload after app restart preserves budgets and existing data',
    () async {
      final budget = MonthlyBudget(
        year: 2026,
        month: 5,
        amount: 4000,
        categoryLimits: {'Food': 1000, 'Health': 300},
      );
      final existingTransaction = _transaction(
        'existing-transaction',
        DateTime(2026, 5, 5),
        120,
        'Food',
      );
      SharedPreferences.setMockInitialValues({
        'spendtrack_transactions': jsonEncode([existingTransaction.toJson()]),
      });

      await BudgetStorage().upsertBudget(budget);
      final restartedBudgets = await BudgetStorage().loadBudgets();
      final restartedTransactions = await TransactionStorage()
          .loadTransactions();

      expect(restartedBudgets.single.amount, 4000);
      expect(restartedBudgets.single.categoryLimits['Health'], 300);
      expect(restartedTransactions, hasLength(1));
      expect(restartedTransactions!.single.id, existingTransaction.id);
    },
  );
}

Transaction _transaction(
  String id,
  DateTime date,
  double amount,
  String category, [
  bool isIncome = false,
]) => Transaction(
  id: id,
  title: id,
  category: category,
  amount: amount,
  date: date,
  isIncome: isIncome,
);
