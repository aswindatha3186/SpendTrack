import '../models/monthly_budget.dart';
import '../models/transaction.dart';

class CategoryBudgetProgress {
  const CategoryBudgetProgress({
    required this.category,
    required this.limit,
    required this.spent,
  });

  final String category;
  final double limit;
  final double spent;

  double get remaining => limit - spent;
  double get percentConsumed => limit <= 0 ? 0 : spent / limit * 100;
}

class BudgetProgress {
  const BudgetProgress({
    required this.budget,
    required this.spent,
    required this.categorySpending,
  });

  final MonthlyBudget budget;
  final double spent;
  final Map<String, double> categorySpending;

  double get remaining => budget.amount - spent;
  double get percentConsumed => spent / budget.amount * 100;
  bool get isExceeded => percentConsumed >= 100;
  bool get isApproaching => percentConsumed >= 70 && !isExceeded;

  List<CategoryBudgetProgress> get categories =>
      budget.categoryLimits.entries
          .map(
            (entry) => CategoryBudgetProgress(
              category: entry.key,
              limit: entry.value,
              spent: categorySpending[entry.key] ?? 0,
            ),
          )
          .toList()
        ..sort(
          (first, second) =>
              second.percentConsumed.compareTo(first.percentConsumed),
        );

  static BudgetProgress calculate(
    MonthlyBudget budget,
    Iterable<Transaction> transactions,
  ) {
    var spent = 0.0;
    final spendingByCategory = <String, double>{};
    for (final transaction in transactions) {
      if (transaction.isIncome ||
          transaction.date.year != budget.year ||
          transaction.date.month != budget.month) {
        continue;
      }
      spent += transaction.amount;
      spendingByCategory.update(
        transaction.category,
        (total) => total + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    return BudgetProgress(
      budget: budget,
      spent: spent,
      categorySpending: spendingByCategory,
    );
  }
}
