import '../models/transaction.dart';

enum InsightsPeriod {
  thisWeek,
  thisMonth,
  lastMonth,
  last3Months,
  last6Months,
  custom,
}

class InsightsDateRange {
  const InsightsDateRange({required this.start, required this.endExclusive});

  final DateTime start;
  final DateTime endExclusive;

  int get dayCount => endExclusive.difference(start).inDays;

  bool contains(DateTime date) =>
      !date.isBefore(start) && date.isBefore(endExclusive);

  static InsightsDateRange? forPeriod(
    InsightsPeriod period,
    DateTime now, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    switch (period) {
      case InsightsPeriod.thisWeek:
        final start = DateTime(
          today.year,
          today.month,
          today.day - today.weekday + 1,
        );
        return InsightsDateRange(start: start, endExclusive: tomorrow);
      case InsightsPeriod.thisMonth:
        return InsightsDateRange(
          start: DateTime(today.year, today.month),
          endExclusive: tomorrow,
        );
      case InsightsPeriod.lastMonth:
        final start = DateTime(today.year, today.month - 1);
        return InsightsDateRange(
          start: start,
          endExclusive: DateTime(today.year, today.month),
        );
      case InsightsPeriod.last3Months:
        return InsightsDateRange(
          start: DateTime(today.year, today.month - 2),
          endExclusive: tomorrow,
        );
      case InsightsPeriod.last6Months:
        return InsightsDateRange(
          start: DateTime(today.year, today.month - 5),
          endExclusive: tomorrow,
        );
      case InsightsPeriod.custom:
        if (customStart == null ||
            customEnd == null ||
            customEnd.isBefore(customStart)) {
          return null;
        }
        final start = DateTime(
          customStart.year,
          customStart.month,
          customStart.day,
        );
        final end = DateTime(
          customEnd.year,
          customEnd.month,
          customEnd.day + 1,
        );
        return InsightsDateRange(start: start, endExclusive: end);
    }
  }
}

class InsightsSummary {
  const InsightsSummary({
    required this.totalIncome,
    required this.totalExpenses,
    required this.netSavings,
    required this.savingsRate,
    required this.averageDailyExpenses,
    required this.expensesByCategory,
  });

  final double totalIncome;
  final double totalExpenses;
  final double netSavings;
  final double savingsRate;
  final double averageDailyExpenses;
  final Map<String, double> expensesByCategory;

  String? get highestSpendingCategory {
    if (expensesByCategory.isEmpty) return null;
    return expensesByCategory.keys.first;
  }

  Map<String, double> get categoryPercentages {
    if (totalExpenses <= 0) return const {};
    return {
      for (final entry in expensesByCategory.entries)
        entry.key: entry.value / totalExpenses * 100,
    };
  }
}

class MonthlyFinancialSummary {
  const MonthlyFinancialSummary({
    required this.year,
    required this.month,
    required this.income,
    required this.expenses,
  });

  final int year;
  final int month;
  final double income;
  final double expenses;

  double get savings => income - expenses;
}

class MonthlyComparison {
  const MonthlyComparison({required this.current, required this.previous});

  final MonthlyFinancialSummary current;
  final MonthlyFinancialSummary previous;

  double? get expenseChangePercentage =>
      percentageChange(current.expenses, previous.expenses);

  double? get incomeChangePercentage =>
      percentageChange(current.income, previous.income);

  static double? percentageChange(double current, double previous) {
    if (previous == 0) return current == 0 ? 0 : null;
    return (current - previous) / previous * 100;
  }
}

class InsightsCalculator {
  static List<Transaction> filterTransactions(
    Iterable<Transaction> transactions,
    InsightsDateRange range,
  ) => transactions
      .where((transaction) => range.contains(transaction.date))
      .toList();

  static InsightsSummary summarize(
    Iterable<Transaction> transactions, {
    required int daysInRange,
  }) {
    var income = 0.0;
    var expenses = 0.0;
    final categoryTotals = <String, double>{};

    for (final transaction in transactions) {
      if (transaction.isIncome) {
        income += transaction.amount;
      } else {
        expenses += transaction.amount;
        categoryTotals.update(
          transaction.category,
          (amount) => amount + transaction.amount,
          ifAbsent: () => transaction.amount,
        );
      }
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((first, second) => second.value.compareTo(first.value));
    final savings = income - expenses;
    return InsightsSummary(
      totalIncome: income,
      totalExpenses: expenses,
      netSavings: savings,
      savingsRate: income == 0 ? 0 : savings / income * 100,
      averageDailyExpenses: daysInRange <= 0 ? 0 : expenses / daysInRange,
      expensesByCategory: {
        for (final entry in sortedCategories) entry.key: entry.value,
      },
    );
  }

  static List<MonthlyFinancialSummary> lastSixMonths(
    Iterable<Transaction> transactions,
    DateTime now,
  ) {
    final months = <MonthlyFinancialSummary>[];
    for (var offset = 5; offset >= 0; offset--) {
      final monthStart = DateTime(now.year, now.month - offset);
      final nextMonth = DateTime(monthStart.year, monthStart.month + 1);
      var income = 0.0;
      var expenses = 0.0;
      for (final transaction in transactions) {
        if (!transaction.date.isBefore(monthStart) &&
            transaction.date.isBefore(nextMonth)) {
          if (transaction.isIncome) {
            income += transaction.amount;
          } else {
            expenses += transaction.amount;
          }
        }
      }
      months.add(
        MonthlyFinancialSummary(
          year: monthStart.year,
          month: monthStart.month,
          income: income,
          expenses: expenses,
        ),
      );
    }
    return months;
  }

  static MonthlyComparison compareCurrentAndPreviousMonth(
    Iterable<Transaction> transactions,
    DateTime now,
  ) {
    final currentStart = DateTime(now.year, now.month);
    final previousStart = DateTime(now.year, now.month - 1);
    final current = _monthlySummary(transactions, currentStart);
    final previous = _monthlySummary(transactions, previousStart);
    return MonthlyComparison(current: current, previous: previous);
  }

  static MonthlyFinancialSummary _monthlySummary(
    Iterable<Transaction> transactions,
    DateTime start,
  ) {
    final end = DateTime(start.year, start.month + 1);
    var income = 0.0;
    var expenses = 0.0;
    for (final transaction in transactions) {
      if (!transaction.date.isBefore(start) && transaction.date.isBefore(end)) {
        if (transaction.isIncome) {
          income += transaction.amount;
        } else {
          expenses += transaction.amount;
        }
      }
    }
    return MonthlyFinancialSummary(
      year: start.year,
      month: start.month,
      income: income,
      expenses: expenses,
    );
  }
}
