import '../budgets/budget_calculator.dart';
import '../models/app_notification.dart';
import '../models/monthly_budget.dart';
import '../models/transaction.dart';

class BudgetNotificationGenerator {
  static const thresholds = [70, 90, 100];

  static List<AppNotification> generate({
    required Iterable<MonthlyBudget> budgets,
    required Iterable<Transaction> transactions,
    required DateTime createdAt,
  }) {
    final transactionList = transactions.toList();
    final notifications = <AppNotification>[];
    for (final budget in budgets) {
      final progress = BudgetProgress.calculate(budget, transactionList);
      for (final threshold in thresholds) {
        if (progress.percentConsumed >= threshold) {
          notifications.add(
            _notification(
              budget: budget,
              threshold: threshold,
              scope: 'overall',
              label: 'Monthly budget',
              spent: progress.spent,
              limit: budget.amount,
              createdAt: createdAt,
            ),
          );
        }
      }

      for (final categoryProgress in progress.categories) {
        for (final threshold in thresholds) {
          if (categoryProgress.percentConsumed >= threshold) {
            notifications.add(
              _notification(
                budget: budget,
                threshold: threshold,
                scope: 'category:${categoryProgress.category}',
                label: '${categoryProgress.category} budget',
                spent: categoryProgress.spent,
                limit: categoryProgress.limit,
                createdAt: createdAt,
              ),
            );
          }
        }
      }
    }
    return notifications;
  }

  static AppNotification _notification({
    required MonthlyBudget budget,
    required int threshold,
    required String scope,
    required String label,
    required double spent,
    required double limit,
    required DateTime createdAt,
  }) {
    final key =
        'budget:${budget.year}-${budget.month.toString().padLeft(2, '0')}:'
        '$scope:$threshold';
    final title = '$label reached $threshold%';
    final month = '${budget.month.toString().padLeft(2, '0')}/${budget.year}';
    return AppNotification(
      id: key,
      title: title,
      message:
          '$month: ${_money(spent)} spent of ${_money(limit)}. '
          'You have used at least $threshold% of this limit.',
      createdAt: createdAt,
      deduplicationKey: key,
    );
  }

  static String _money(double amount) => '₹${amount.toStringAsFixed(2)}';
}
