import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/monthly_budget.dart';

class BudgetStorage {
  static const _budgetsKey = 'spendtrack_monthly_budgets';

  Future<List<MonthlyBudget>> loadBudgets() async {
    final preferences = await SharedPreferences.getInstance();
    final savedData = preferences.getString(_budgetsKey);
    if (savedData == null) return [];

    final decoded = jsonDecode(savedData);
    if (decoded is! List) {
      throw const FormatException('Saved monthly budgets must be a JSON list.');
    }

    final budgets = <MonthlyBudget>[];
    final ids = <String>{};
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException(
          'Saved monthly budget has an invalid shape.',
        );
      }
      final budget = MonthlyBudget.fromJson(item);
      if (ids.add(budget.id)) budgets.add(budget);
    }
    return budgets;
  }

  Future<void> saveBudgets(Iterable<MonthlyBudget> budgets) async {
    final preferences = await SharedPreferences.getInstance();
    final uniqueByMonth = <String, MonthlyBudget>{};
    for (final budget in budgets) {
      uniqueByMonth.putIfAbsent(_monthKey(budget), () => budget);
    }
    final saved = await preferences.setString(
      _budgetsKey,
      jsonEncode(
        uniqueByMonth.values.map((budget) => budget.toJson()).toList(),
      ),
    );
    if (!saved) {
      throw StateError('Unable to save monthly budgets to local storage.');
    }
  }

  Future<void> upsertBudget(MonthlyBudget budget) async {
    final budgets = await loadBudgets();
    final existingIndex = budgets.indexWhere(
      (existing) =>
          existing.id == budget.id ||
          (existing.year == budget.year && existing.month == budget.month),
    );
    if (existingIndex == -1) {
      budgets.add(budget);
    } else {
      budgets[existingIndex] = budget;
    }
    await saveBudgets(budgets);
  }

  Future<void> deleteBudget(String id) async {
    final budgets = await loadBudgets();
    budgets.removeWhere((budget) => budget.id == id);
    await saveBudgets(budgets);
  }

  String _monthKey(MonthlyBudget budget) =>
      '${budget.year}-${budget.month.toString().padLeft(2, '0')}';
}
