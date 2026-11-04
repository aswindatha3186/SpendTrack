import 'package:flutter_test/flutter_test.dart';
import 'package:spendtrack/insights/insights_calculator.dart';
import 'package:spendtrack/models/transaction.dart';

void main() {
  final now = DateTime(2026, 3, 15, 12);

  test('date filters resolve to correct inclusive calendar ranges', () {
    final week = InsightsDateRange.forPeriod(InsightsPeriod.thisWeek, now)!;
    expect(week.start, DateTime(2026, 3, 9));
    expect(week.endExclusive, DateTime(2026, 3, 16));

    final thisMonth = InsightsDateRange.forPeriod(
      InsightsPeriod.thisMonth,
      now,
    )!;
    expect(thisMonth.start, DateTime(2026, 3, 1));
    expect(thisMonth.endExclusive, DateTime(2026, 3, 16));

    final lastMonth = InsightsDateRange.forPeriod(
      InsightsPeriod.lastMonth,
      now,
    )!;
    expect(lastMonth.start, DateTime(2026, 2, 1));
    expect(lastMonth.endExclusive, DateTime(2026, 3, 1));

    final lastThreeMonths = InsightsDateRange.forPeriod(
      InsightsPeriod.last3Months,
      now,
    )!;
    expect(lastThreeMonths.start, DateTime(2026, 1, 1));
    expect(lastThreeMonths.endExclusive, DateTime(2026, 3, 16));

    final lastSixMonths = InsightsDateRange.forPeriod(
      InsightsPeriod.last6Months,
      now,
    )!;
    expect(lastSixMonths.start, DateTime(2025, 10, 1));
    expect(lastSixMonths.endExclusive, DateTime(2026, 3, 16));

    final custom = InsightsDateRange.forPeriod(
      InsightsPeriod.custom,
      now,
      customStart: DateTime(2026, 2, 10, 15),
      customEnd: DateTime(2026, 2, 12, 9),
    )!;
    expect(custom.start, DateTime(2026, 2, 10));
    expect(custom.endExclusive, DateTime(2026, 2, 13));
    expect(
      InsightsDateRange.forPeriod(
        InsightsPeriod.custom,
        now,
        customStart: DateTime(2026, 2, 13),
        customEnd: DateTime(2026, 2, 12),
      ),
      isNull,
    );
  });

  test('filters transactions at the start and end boundaries', () {
    final range = InsightsDateRange(
      start: DateTime(2026, 3, 1),
      endExclusive: DateTime(2026, 4, 1),
    );
    final transactions = [
      _transaction('before', DateTime(2026, 2, 28, 23), 12),
      _transaction('start', DateTime(2026, 3, 1), 15),
      _transaction('end-day', DateTime(2026, 3, 31, 23, 59), 25),
      _transaction('after', DateTime(2026, 4, 1), 30),
    ];

    expect(
      InsightsCalculator.filterTransactions(
        transactions,
        range,
      ).map((transaction) => transaction.id),
      ['start', 'end-day'],
    );
  });

  test(
    'summary separates income and expenses and calculates category shares',
    () {
      final summary = InsightsCalculator.summarize([
        _transaction('income', DateTime(2026, 3, 1), 1000, isIncome: true),
        _transaction('food', DateTime(2026, 3, 2), 100, category: 'Food'),
        _transaction('travel', DateTime(2026, 3, 3), 300, category: 'Travel'),
      ], daysInRange: 10);

      expect(summary.totalIncome, 1000);
      expect(summary.totalExpenses, 400);
      expect(summary.netSavings, 600);
      expect(summary.savingsRate, 60);
      expect(summary.averageDailyExpenses, 40);
      expect(summary.highestSpendingCategory, 'Travel');
      expect(summary.categoryPercentages['Food'], 25);
      expect(summary.categoryPercentages['Travel'], 75);
    },
  );

  test('empty and zero-income summaries remain finite and safe', () {
    final summary = InsightsCalculator.summarize([
      _transaction('expense', DateTime(2026, 3, 1), 20),
    ], daysInRange: 0);

    expect(summary.totalIncome, 0);
    expect(summary.netSavings, -20);
    expect(summary.savingsRate, 0);
    expect(summary.averageDailyExpenses, 0);
    expect(summary.categoryPercentages.values.single, 100);

    final empty = InsightsCalculator.summarize([], daysInRange: 30);
    expect(empty.totalExpenses, 0);
    expect(empty.highestSpendingCategory, isNull);
    expect(empty.categoryPercentages, isEmpty);
  });

  test('six-month totals and current-versus-previous month comparison are accurate', () {
    final transactions = [
      _transaction('old', DateTime(2025, 9, 30), 999),
      _transaction('oct-income', DateTime(2025, 10, 1), 100, isIncome: true),
      _transaction('feb-income', DateTime(2026, 2, 1), 500, isIncome: true),
      _transaction('feb-expense', DateTime(2026, 2, 2), 50),
      _transaction('mar-income', DateTime(2026, 3, 1), 200, isIncome: true),
      _transaction('mar-expense', DateTime(2026, 3, 2), 100),
      _transaction('future', DateTime(2026, 4, 1), 777),
    ];

    final sixMonths = InsightsCalculator.lastSixMonths(transactions, now);
    expect(sixMonths, hasLength(6));
    expect(sixMonths.first.month, 10);
    expect(sixMonths.first.income, 100);
    expect(sixMonths[4].month, 2);
    expect(sixMonths[4].expenses, 50);
    expect(sixMonths.last.month, 3);
    expect(sixMonths.last.income, 200);
    expect(sixMonths.last.expenses, 100);

    final comparison = InsightsCalculator.compareCurrentAndPreviousMonth(
      transactions,
      now,
    );
    expect(comparison.current.income, 200);
    expect(comparison.current.expenses, 100);
    expect(comparison.current.savings, 100);
    expect(comparison.previous.income, 500);
    expect(comparison.previous.expenses, 50);
    expect(comparison.expenseChangePercentage, 100);
    expect(comparison.incomeChangePercentage, -60);
  });

  test('month comparisons handle months with no previous transactions', () {
    final comparison = InsightsCalculator.compareCurrentAndPreviousMonth([
      _transaction('income', DateTime(2026, 3, 2), 500, isIncome: true),
    ], now);

    expect(comparison.expenseChangePercentage, 0);
    expect(comparison.incomeChangePercentage, isNull);
  });
}

Transaction _transaction(
  String id,
  DateTime date,
  double amount, {
  String category = 'Food',
  bool isIncome = false,
}) => Transaction(
  id: id,
  title: id,
  category: category,
  amount: amount,
  date: date,
  isIncome: isIncome,
);
