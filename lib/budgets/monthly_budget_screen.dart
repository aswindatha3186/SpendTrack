import 'package:flutter/material.dart';

import '../models/monthly_budget.dart';
import '../models/transaction.dart';
import '../theme/app_colors.dart';
import '../budgets/budget_calculator.dart';

const _budgetCategories = [
  'Food',
  'Travel',
  'Shopping',
  'Education',
  'Health',
  'Entertainment',
  'Other',
];

class MonthlyBudgetScreen extends StatefulWidget {
  const MonthlyBudgetScreen({
    required this.initialBudgets,
    required this.transactions,
    required this.onSaveBudgets,
    super.key,
  });

  final List<MonthlyBudget> initialBudgets;
  final List<Transaction> transactions;
  final Future<bool> Function(List<MonthlyBudget>) onSaveBudgets;

  @override
  State<MonthlyBudgetScreen> createState() => _MonthlyBudgetScreenState();
}

class _MonthlyBudgetScreenState extends State<MonthlyBudgetScreen> {
  late List<MonthlyBudget> _budgets;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _budgets = List.of(widget.initialBudgets)
      ..sort((first, second) {
        final firstMonth = DateTime(first.year, first.month);
        final secondMonth = DateTime(second.year, second.month);
        return secondMonth.compareTo(firstMonth);
      });
  }

  Future<void> _openForm({MonthlyBudget? budget}) async {
    final result = await showModalBottomSheet<MonthlyBudget>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => _BudgetFormSheet(budget: budget),
    );
    if (result == null || !mounted) return;

    final duplicateMonth = _budgets.any(
      (item) =>
          item.id != budget?.id &&
          item.year == result.year &&
          item.month == result.month,
    );
    if (duplicateMonth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A budget already exists for that month.'),
        ),
      );
      return;
    }

    final existingIndex = _budgets.indexWhere(
      (item) =>
          item.id == result.id ||
          (item.year == result.year && item.month == result.month),
    );
    final updatedBudgets = List<MonthlyBudget>.of(_budgets);
    if (existingIndex < 0) {
      updatedBudgets.add(result);
    } else {
      updatedBudgets[existingIndex] = result;
    }
    updatedBudgets.sort(
      (first, second) => DateTime(
        second.year,
        second.month,
      ).compareTo(DateTime(first.year, first.month)),
    );
    await _save(updatedBudgets, successMessage: 'Budget saved.');
  }

  Future<void> _confirmDelete(MonthlyBudget budget) async {
    if (_isSaving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete monthly budget?'),
        content: Text(
          'Delete the ${_monthLabel(budget.year, budget.month)} budget?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final updatedBudgets = _budgets
        .where((item) => item.id != budget.id)
        .toList();
    await _save(updatedBudgets, successMessage: 'Budget deleted.');
  }

  Future<void> _save(
    List<MonthlyBudget> updatedBudgets, {
    required String successMessage,
  }) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final saved = await widget.onSaveBudgets(updatedBudgets);
      if (!mounted) return;
      if (saved) {
        setState(() => _budgets = updatedBudgets);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(successMessage)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save budget. Please retry.')),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to save monthly budget: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save budget. Please retry.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentMonth = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Monthly Budgets',
          style: TextStyle(color: navy, fontWeight: FontWeight.bold),
        ),
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
      ),
      body: _budgets.isEmpty
          ? _emptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                _overviewHeader(_budgets),
                const SizedBox(height: 20),
                for (final budget in _budgets)
                  _budgetCard(budget, currentMonth),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-monthly-budget'),
        onPressed: _isSaving ? null : () => _openForm(),
        backgroundColor: green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add budget'),
      ),
    );
  }

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFE4F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.savings_outlined, color: green, size: 38),
          ),
          const SizedBox(height: 18),
          const Text(
            'No budgets yet',
            style: TextStyle(
              color: navy,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a monthly plan and track your spending by category.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _isSaving ? null : () => _openForm(),
            icon: const Icon(Icons.add),
            label: const Text('Create your first budget'),
          ),
        ],
      ),
    ),
  );

  Widget _overviewHeader(List<MonthlyBudget> budgets) {
    final current = budgets.where(
      (budget) =>
          budget.year == DateTime.now().year &&
          budget.month == DateTime.now().month,
    );
    final planned = current.fold<double>(0, (sum, item) => sum + item.amount);
    final spent = current.fold<double>(
      0,
      (sum, item) =>
          sum + BudgetProgress.calculate(item, widget.transactions).spent,
    );
    final remaining = planned - spent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF123C2A), green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'THIS MONTH',
            style: TextStyle(
              color: Colors.white70,
              letterSpacing: 1.1,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${spent.toStringAsFixed(2)} spent',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            planned == 0
                ? 'Add a budget to start tracking'
                : '₹${remaining.toStringAsFixed(2)} remaining of ₹${planned.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _budgetCard(MonthlyBudget budget, DateTime currentMonth) {
    final progress = BudgetProgress.calculate(budget, widget.transactions);
    final isCurrentMonth =
        budget.year == currentMonth.year && budget.month == currentMonth.month;
    final color = _statusColor(progress.percentConsumed);
    return Container(
      key: Key('budget-card-${budget.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _monthLabel(budget.year, budget.month),
                      style: const TextStyle(
                        color: navy,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isCurrentMonth)
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Text(
                          'Current month',
                          style: TextStyle(color: green, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: Key('budget-menu-${budget.id}'),
                enabled: !_isSaving,
                onSelected: (action) {
                  if (action == 'edit') _openForm(budget: budget);
                  if (action == 'delete') _confirmDelete(budget);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _BudgetProgressBar(
            percent: progress.percentConsumed,
            color: color,
            height: 10,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BudgetMetric(
                  label: 'Budget',
                  value: _money(budget.amount),
                ),
              ),
              Expanded(
                child: _BudgetMetric(
                  label: 'Spent',
                  value: _money(progress.spent),
                ),
              ),
              Expanded(
                child: _BudgetMetric(
                  label: 'Remaining',
                  value: _money(progress.remaining),
                  valueColor: progress.remaining < 0
                      ? const Color(0xFFDC2626)
                      : navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${progress.percentConsumed.toStringAsFixed(1)}% used',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          if (progress.isExceeded || progress.isApproaching) ...[
            const SizedBox(height: 12),
            _BudgetAlert(exceeded: progress.isExceeded),
          ],
          if (budget.categoryLimits.isNotEmpty) ...[
            const Divider(height: 28),
            const Text(
              'Category limits',
              style: TextStyle(color: navy, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            for (final category in progress.categories)
              _categoryProgress(category),
          ],
        ],
      ),
    );
  }

  Widget _categoryProgress(CategoryBudgetProgress progress) {
    final color = _statusColor(progress.percentConsumed);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  progress.category,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '${_money(progress.spent)} / ${_money(progress.limit)}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _BudgetProgressBar(percent: progress.percentConsumed, color: color),
          if (progress.percentConsumed >= 70)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  progress.percentConsumed >= 100
                      ? '${progress.category} limit exceeded'
                      : '${progress.category} spending is approaching its limit',
                  style: TextStyle(color: color, fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Color _statusColor(double percent) {
    if (percent >= 100) return const Color(0xFFDC2626);
    if (percent >= 70) return const Color(0xFFF59E0B);
    return green;
  }

  static String _money(double amount) => '₹${amount.toStringAsFixed(2)}';

  static String _monthLabel(int year, int month) =>
      '${_monthNames[month - 1]} $year';
}

class _BudgetMetric extends StatelessWidget {
  const _BudgetMetric({
    required this.label,
    required this.value,
    this.valueColor = navy,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  );
}

class _BudgetProgressBar extends StatelessWidget {
  const _BudgetProgressBar({
    required this.percent,
    required this.color,
    this.height = 7,
  });

  final double percent;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: LinearProgressIndicator(
      value: (percent / 100).clamp(0, 1),
      minHeight: height,
      backgroundColor: const Color(0xFFE9EDF2),
      color: color,
    ),
  );
}

class _BudgetAlert extends StatelessWidget {
  const _BudgetAlert({required this.exceeded});

  final bool exceeded;

  @override
  Widget build(BuildContext context) {
    final color = exceeded ? const Color(0xFFDC2626) : const Color(0xFFB45309);
    final backgroundColor = exceeded
        ? const Color(0xFFFEF2F2)
        : const Color(0xFFFFF7ED);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            exceeded ? Icons.error_outline : Icons.warning_amber_rounded,
            color: color,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              exceeded
                  ? 'You have exceeded this monthly budget.'
                  : 'You have used at least 70% of this monthly budget.',
              style: TextStyle(color: color, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetFormSheet extends StatefulWidget {
  const _BudgetFormSheet({this.budget});

  final MonthlyBudget? budget;

  @override
  State<_BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends State<_BudgetFormSheet> {
  late final TextEditingController _amountController;
  late final Map<String, TextEditingController> _categoryControllers;
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final budget = widget.budget;
    _month = budget == null
        ? DateTime(DateTime.now().year, DateTime.now().month)
        : DateTime(budget.year, budget.month);
    _amountController = TextEditingController(
      text: budget?.amount.toString() ?? '',
    );
    _categoryControllers = {
      for (final category in _budgetCategories)
        category: TextEditingController(
          text: budget?.categoryLimits[category]?.toString() ?? '',
        ),
    };
  }

  @override
  void dispose() {
    _amountController.dispose();
    for (final controller in _categoryControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _selectMonth() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select a date in the budget month',
    );
    if (selectedDate != null && mounted) {
      setState(() => _month = DateTime(selectedDate.year, selectedDate.month));
    }
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || !amount.isFinite || amount <= 0) {
      _showValidationError('Enter a valid monthly budget amount.');
      return;
    }
    final categoryLimits = <String, double>{};
    for (final entry in _categoryControllers.entries) {
      final value = entry.value.text.trim();
      if (value.isEmpty) continue;
      final limit = double.tryParse(value);
      if (limit == null || !limit.isFinite || limit <= 0) {
        _showValidationError('Enter a valid limit for ${entry.key}.');
        return;
      }
      categoryLimits[entry.key] = limit;
    }
    Navigator.pop(
      context,
      MonthlyBudget(
        id: widget.budget?.id,
        year: _month.year,
        month: _month.month,
        amount: amount,
        categoryLimits: categoryLimits,
      ),
    );
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 22,
      right: 22,
      top: 24,
      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.budget == null
                ? 'Create monthly budget'
                : 'Edit monthly budget',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          const SizedBox(height: 18),
          const Text('Budget month'),
          const SizedBox(height: 7),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('budget-month-button'),
              onPressed: _selectMonth,
              icon: const Icon(Icons.calendar_month),
              label: Text(
                '${_monthNames[_month.month - 1]} ${_month.year}',
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Monthly spending limit'),
          const SizedBox(height: 7),
          TextField(
            key: const Key('budget-total-field'),
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: '₹ ',
              hintText: 'e.g. 20000',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Category limits (optional)',
            style: TextStyle(color: navy, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Leave a category blank if you do not want a separate limit.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 10),
          for (final category in _budgetCategories)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                key: Key('category-budget-field-$category'),
                controller: _categoryControllers[category],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: category,
                  prefixText: '₹ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              key: const Key('save-monthly-budget'),
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                widget.budget == null ? 'Save budget' : 'Save changes',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
