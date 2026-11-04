import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendtrack/insights/advanced_insights_dashboard.dart';
import 'package:spendtrack/models/transaction.dart';

void main() {
  final now = DateTime(2026, 3, 15, 12);

  testWidgets('dashboard charts and metrics use the selected period data', (
    tester,
  ) async {
    final transactions = [
      _transaction(
        'current-income',
        DateTime(2026, 3, 2),
        2000,
        isIncome: true,
      ),
      _transaction('current-food', DateTime(2026, 3, 4), 100),
      _transaction(
        'current-travel',
        DateTime(2026, 3, 5),
        300,
        category: 'Travel',
      ),
      _transaction('last-month', DateTime(2026, 2, 5), 800),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdvancedInsightsDashboard(transactions: transactions, now: now),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Top category: Travel · ₹300.00'), findsOneWidget);
    expect(find.text('75.0%'), findsOneWidget);
    expect(find.text('25.0%'), findsOneWidget);
    expect(find.byKey(const Key('category-donut-chart')), findsOneWidget);
    expect(
      find.byKey(const Key('income-expense-monthly-chart')),
      findsOneWidget,
    );
    expect(find.text('₹2000.00'), findsWidgets);
    expect(find.text('₹400.00'), findsWidgets);
    expect(find.text('₹1600.00'), findsWidgets);

    final donutFinder = find.byKey(const Key('category-donut-chart'));
    await tester.ensureVisible(donutFinder);
    final donutRect = tester.getRect(donutFinder);
    const angle = 5.5;
    await tester.tapAt(
      Offset(
        donutRect.center.dx + math.sin(angle) * donutRect.width * 0.39,
        donutRect.center.dy - math.cos(angle) * donutRect.height * 0.39,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const Key('category-chart-center-label')))
          .data,
      'Food',
    );

    final filterFinder = find.byKey(const Key('insights-period-filter'));
    await tester.ensureVisible(filterFinder);
    await tester.tap(filterFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last month').last);
    await tester.pumpAndSettle();

    expect(find.text('₹800.00'), findsWidgets);
    expect(find.text('Top category: Food · ₹800.00'), findsOneWidget);
    expect(find.text('Top category: Travel · ₹300.00'), findsNothing);
  });

  testWidgets('dashboard shows clear empty state for an empty period', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdvancedInsightsDashboard(transactions: const [], now: now),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No expenses in this date range.'), findsOneWidget);
    expect(
      find.textContaining('No transactions match this date range.'),
      findsOneWidget,
    );
    expect(find.text('0.0%'), findsWidgets);
    expect(
      find.byKey(const Key('income-expense-monthly-chart')),
      findsOneWidget,
    );
  });
}

Transaction _transaction(
  String id,
  DateTime date,
  double amount, {
  bool isIncome = false,
  String category = 'Food',
}) => Transaction(
  id: id,
  title: id,
  category: category,
  amount: amount,
  date: date,
  isIncome: isIncome,
);
