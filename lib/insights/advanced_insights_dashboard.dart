import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../models/transaction.dart';
import 'insights_calculator.dart';

class AdvancedInsightsDashboard extends StatefulWidget {
  const AdvancedInsightsDashboard({
    required this.transactions,
    this.now,
    super.key,
  });

  final List<Transaction> transactions;
  final DateTime? now;

  @override
  State<AdvancedInsightsDashboard> createState() =>
      _AdvancedInsightsDashboardState();
}

class _AdvancedInsightsDashboardState extends State<AdvancedInsightsDashboard> {
  InsightsPeriod _period = InsightsPeriod.thisMonth;
  DateTimeRange? _customRange;

  DateTime get _now => widget.now ?? DateTime.now();

  InsightsDateRange get _dateRange => InsightsDateRange.forPeriod(
    _period,
    _now,
    customStart: _customRange?.start,
    customEnd: _customRange?.end,
  )!;

  Future<void> _selectPeriod(InsightsPeriod? period) async {
    if (period == null) return;
    if (period == InsightsPeriod.custom) {
      final today = DateTime(_now.year, _now.month, _now.day);
      final initialStart =
          _customRange?.start ?? DateTime(_now.year, _now.month);
      final initialEnd = _customRange?.end ?? today;
      final selected = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDateRange: DateTimeRange(
          start: initialStart.isAfter(today) ? today : initialStart,
          end: initialEnd.isAfter(today) ? today : initialEnd,
        ),
      );
      if (selected == null || !mounted) return;
      setState(() {
        _period = InsightsPeriod.custom;
        _customRange = selected;
      });
      return;
    }

    setState(() {
      _period = period;
      _customRange = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final range = _dateRange;
    final filteredTransactions = InsightsCalculator.filterTransactions(
      widget.transactions,
      range,
    );
    final summary = InsightsCalculator.summarize(
      filteredTransactions,
      daysInRange: range.dayCount,
    );
    final monthlySummaries = InsightsCalculator.lastSixMonths(
      widget.transactions,
      _now,
    );
    final monthlyComparison = InsightsCalculator.compareCurrentAndPreviousMonth(
      widget.transactions,
      _now,
    );
    final currentWeekRange = InsightsDateRange.forPeriod(
      InsightsPeriod.thisWeek,
      _now,
    )!;
    final currentMonthRange = InsightsDateRange.forPeriod(
      InsightsPeriod.thisMonth,
      _now,
    )!;
    final weekSummary = InsightsCalculator.summarize(
      InsightsCalculator.filterTransactions(
        widget.transactions,
        currentWeekRange,
      ),
      daysInRange: currentWeekRange.dayCount,
    );
    final monthSummary = InsightsCalculator.summarize(
      InsightsCalculator.filterTransactions(
        widget.transactions,
        currentMonthRange,
      ),
      daysInRange: currentMonthRange.dayCount,
    );
    final categories = summary.expensesByCategory.entries
        .map(
          (entry) => _CategoryValue(
            name: entry.key,
            amount: entry.value,
            percentage: summary.categoryPercentages[entry.key] ?? 0,
          ),
        )
        .toList();

    return SingleChildScrollView(
      key: const Key('advanced-insights-dashboard'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Insights',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Understand your spending and savings',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 18),
          _dateFilter(range),
          const SizedBox(height: 18),
          _sectionTitle('Financial summary', _periodLabel(_period)),
          const SizedBox(height: 12),
          _summaryGrid(summary),
          const SizedBox(height: 22),
          _sectionTitle('Spending by category', 'Expense breakdown'),
          const SizedBox(height: 12),
          _CategoryCard(
            categories: categories,
            totalExpenses: summary.totalExpenses,
          ),
          const SizedBox(height: 22),
          _sectionTitle('Income vs expenses', 'Last six months'),
          const SizedBox(height: 12),
          _MonthlyChartCard(months: monthlySummaries),
          const SizedBox(height: 22),
          _sectionTitle('Spending trends', 'Based on saved transactions'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TrendCard(
                  title: 'This week',
                  amount: weekSummary.totalExpenses,
                  subtitle: '${currentWeekRange.dayCount} day period',
                  icon: Icons.date_range,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TrendCard(
                  title: 'This month',
                  amount: monthSummary.totalExpenses,
                  subtitle: '${currentMonthRange.dayCount} days so far',
                  icon: Icons.calendar_month,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _sectionTitle('Financial insights', 'Current month vs previous'),
          const SizedBox(height: 12),
          _FinancialInsightsCard(
            summary: summary,
            comparison: monthlyComparison,
            currencyFormatter: _money,
          ),
          if (filteredTransactions.isEmpty) ...[
            const SizedBox(height: 18),
            const _EmptyInsightsState(),
          ],
        ],
      ),
    );
  }

  Widget _dateFilter(InsightsDateRange range) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list, color: green),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<InsightsPeriod>(
                    key: const Key('insights-period-filter'),
                    value: _period,
                    isExpanded: true,
                    items: InsightsPeriod.values
                        .map(
                          (period) => DropdownMenuItem(
                            value: period,
                            child: Text(_periodLabel(period)),
                          ),
                        )
                        .toList(),
                    onChanged: _selectPeriod,
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 34, bottom: 6),
              child: Text(
                '${_formatDate(range.start)} – ${_formatDate(DateTime(range.endExclusive.year, range.endExclusive.month, range.endExclusive.day - 1))}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final titleWidget = Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: navy,
          ),
        );
        final subtitleWidget = Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        );
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleWidget, const SizedBox(height: 2), subtitleWidget],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: titleWidget),
            const SizedBox(width: 8),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: subtitleWidget,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryGrid(InsightsSummary summary) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Income',
                amount: _money(summary.totalIncome),
                icon: Icons.south_west,
                color: green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Expenses',
                amount: _money(summary.totalExpenses),
                icon: Icons.north_east,
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Net savings',
                amount: _money(summary.netSavings),
                icon: Icons.savings_outlined,
                color: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Savings rate',
                amount: '${summary.savingsRate.toStringAsFixed(1)}%',
                icon: Icons.show_chart,
                color: const Color(0xFF8B5CF6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _money(double amount) => '₹${amount.toStringAsFixed(2)}';

  static String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';

  static String _periodLabel(InsightsPeriod period) => switch (period) {
    InsightsPeriod.thisWeek => 'This week',
    InsightsPeriod.thisMonth => 'This month',
    InsightsPeriod.lastMonth => 'Last month',
    InsightsPeriod.last3Months => 'Last 3 months',
    InsightsPeriod.last6Months => 'Last 6 months',
    InsightsPeriod.custom => 'Custom range',
  };
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String title;
  final String amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryValue {
  const _CategoryValue({
    required this.name,
    required this.amount,
    required this.percentage,
  });

  final String name;
  final double amount;
  final double percentage;
}

const _chartColors = [
  Color(0xFF16A34A),
  Color(0xFF2563EB),
  Color(0xFFF59E0B),
  Color(0xFF8B5CF6),
  Color(0xFFEF4444),
  Color(0xFF06B6D4),
  Color(0xFFEC4899),
  Color(0xFF64748B),
];

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.categories, required this.totalExpenses});

  final List<_CategoryValue> categories;
  final double totalExpenses;

  @override
  Widget build(BuildContext context) {
    final highestCategory = categories.isEmpty ? null : categories.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          if (categories.isEmpty)
            const SizedBox(
              height: 190,
              child: Center(
                child: Text(
                  'No expenses in this date range.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else ...[
            if (highestCategory != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Top category: ${highestCategory.name} · ${_CategoryCard._money(highestCategory.amount)}',
                  key: const Key('highest-spending-category'),
                  style: const TextStyle(
                    color: green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            _DonutChart(categories: categories, totalExpenses: totalExpenses),
            const SizedBox(height: 8),
            ...List.generate(categories.length, (index) {
              final category = categories[index];
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _chartColors[index % _chartColors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        category.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      '${category.percentage.toStringAsFixed(1)}%',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _money(category.amount),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  static String _money(double amount) => '₹${amount.toStringAsFixed(2)}';
}

class _DonutChart extends StatefulWidget {
  const _DonutChart({required this.categories, required this.totalExpenses});

  final List<_CategoryValue> categories;
  final double totalExpenses;

  @override
  State<_DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<_DonutChart> {
  int _selectedIndex = -1;

  @override
  void didUpdateWidget(covariant _DonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categories != widget.categories) {
      _selectedIndex = -1;
    }
  }

  void _selectSlice(TapDownDetails details, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final point = details.localPosition - center;
    final radius = math.min(size.width, size.height) / 2;
    final distance = point.distance;
    if (distance > radius || distance < radius * 0.48) return;

    var angle = (math.atan2(point.dy, point.dx) + math.pi / 2) % (2 * math.pi);
    if (angle < 0) angle += 2 * math.pi;
    var accumulated = 0.0;
    for (var index = 0; index < widget.categories.length; index++) {
      final sweep =
          widget.categories[index].amount / widget.totalExpenses * 2 * math.pi;
      if (angle < accumulated + sweep) {
        setState(() => _selectedIndex = index);
        return;
      }
      accumulated += sweep;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected =
        _selectedIndex >= 0 && _selectedIndex < widget.categories.length
        ? widget.categories[_selectedIndex]
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, 220.0);
        return SizedBox(
          height: size,
          width: double.infinity,
          child: Center(
            child: SizedBox(
              height: size,
              width: size,
              child: GestureDetector(
                key: const Key('category-donut-chart'),
                onTapDown: (details) => _selectSlice(details, Size(size, size)),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      key: ValueKey(
                        widget.categories
                            .map(
                              (category) =>
                                  '${category.name}:${category.amount}',
                            )
                            .join('|'),
                      ),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      builder: (context, progress, _) => CustomPaint(
                        size: Size(size, size),
                        painter: _DonutPainter(
                          categories: widget.categories,
                          total: widget.totalExpenses,
                          progress: progress,
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            selected?.name ?? 'Total spent',
                            key: const Key('category-chart-center-label'),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _CategoryCard._money(
                              selected?.amount ?? widget.totalExpenses,
                            ),
                            style: const TextStyle(
                              color: navy,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.categories,
    required this.total,
    required this.progress,
  });

  final List<_CategoryValue> categories;
  final double total;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.45;
    final rect = Rect.fromCircle(center: center, radius: radius);
    var start = -math.pi / 2;
    for (var index = 0; index < categories.length; index++) {
      final sweep = categories[index].amount / total * 2 * math.pi * progress;
      final paint = Paint()
        ..color = _chartColors[index % _chartColors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.30
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.categories != categories ||
      oldDelegate.total != total ||
      oldDelegate.progress != progress;
}

class _MonthlyChartCard extends StatelessWidget {
  const _MonthlyChartCard({required this.months});

  final List<MonthlyFinancialSummary> months;

  @override
  Widget build(BuildContext context) {
    final maxAmount = months.fold<double>(
      0,
      (maxValue, month) =>
          math.max(maxValue, math.max(month.income, month.expenses)),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _LegendDot(color: green, label: 'Income'),
              const SizedBox(width: 18),
              _LegendDot(color: const Color(0xFFEF4444), label: 'Expenses'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 170,
            width: double.infinity,
            child: CustomPaint(
              key: const Key('income-expense-monthly-chart'),
              painter: _MonthlyBarPainter(months: months, maxAmount: maxAmount),
            ),
          ),
          Row(
            children: months
                .map(
                  (month) => Expanded(
                    child: Text(
                      _monthName(month.month),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _MonthlyBarPainter extends CustomPainter {
  const _MonthlyBarPainter({required this.months, required this.maxAmount});

  final List<MonthlyFinancialSummary> months;
  final double maxAmount;

  @override
  void paint(Canvas canvas, Size size) {
    const topPadding = 8.0;
    const bottomPadding = 8.0;
    final chartHeight = size.height - topPadding - bottomPadding;
    final gridPaint = Paint()
      ..color = const Color(0xFFE9EDF2)
      ..strokeWidth = 1;
    for (var line = 0; line < 4; line++) {
      final y = topPadding + chartHeight * line / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final groupWidth = size.width / math.max(months.length, 1);
    final barWidth = math.min(13.0, groupWidth * 0.28);
    for (var index = 0; index < months.length; index++) {
      final month = months[index];
      final centerX = groupWidth * (index + 0.5);
      final incomeHeight = maxAmount == 0
          ? 0.0
          : chartHeight * month.income / maxAmount;
      final expenseHeight = maxAmount == 0
          ? 0.0
          : chartHeight * month.expenses / maxAmount;
      final incomePaint = Paint()..color = green;
      final expensePaint = Paint()..color = const Color(0xFFEF4444);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            centerX - barWidth - 2,
            topPadding + chartHeight - incomeHeight,
            barWidth,
            incomeHeight,
          ),
          const Radius.circular(4),
        ),
        incomePaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            centerX + 2,
            topPadding + chartHeight - expenseHeight,
            barWidth,
            expenseHeight,
          ),
          const Radius.circular(4),
        ),
        expensePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MonthlyBarPainter oldDelegate) =>
      oldDelegate.months != months || oldDelegate.maxAmount != maxAmount;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
    ],
  );
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final double amount;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: green, size: 20),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            color: navy,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.grey, fontSize: 10),
        ),
      ],
    ),
  );
}

class _FinancialInsightsCard extends StatelessWidget {
  const _FinancialInsightsCard({
    required this.summary,
    required this.comparison,
    required this.currencyFormatter,
  });

  final InsightsSummary summary;
  final MonthlyComparison comparison;
  final String Function(double) currencyFormatter;

  @override
  Widget build(BuildContext context) {
    final expenseChange = comparison.expenseChangePercentage;
    final incomeChange = comparison.incomeChangePercentage;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _InsightRow(
            label: 'Highest spending category',
            value: summary.highestSpendingCategory ?? 'No expenses',
            icon: Icons.local_fire_department_outlined,
          ),
          const Divider(height: 22),
          _InsightRow(
            label: 'Average daily expenses',
            value: currencyFormatter(summary.averageDailyExpenses),
            icon: Icons.today_outlined,
          ),
          const Divider(height: 22),
          _InsightRow(
            label: 'Total savings in selected period',
            value: currencyFormatter(summary.netSavings),
            icon: Icons.savings_outlined,
          ),
          const Divider(height: 22),
          _InsightRow(
            label: 'Savings rate',
            value: '${summary.savingsRate.toStringAsFixed(1)}%',
            icon: Icons.percent,
          ),
          const Divider(height: 22),
          _InsightRow(
            label: 'Expenses vs previous month',
            value: _changeText(
              comparison.current.expenses,
              comparison.previous.expenses,
              expenseChange,
            ),
            icon: Icons.compare_arrows,
          ),
          const SizedBox(height: 10),
          _InsightRow(
            label: 'Income vs previous month',
            value: _changeText(
              comparison.current.income,
              comparison.previous.income,
              incomeChange,
            ),
            icon: Icons.compare_arrows,
          ),
        ],
      ),
    );
  }

  String _changeText(double current, double previous, double? change) {
    final changeLabel = change == null
        ? 'new'
        : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%';
    return '${currencyFormatter(current)} vs ${currencyFormatter(previous)} · $changeLabel';
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 19, color: green),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: const TextStyle(
            color: navy,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    ],
  );
}

class _EmptyInsightsState extends StatelessWidget {
  const _EmptyInsightsState();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFE4F5E9),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Row(
      children: [
        Icon(Icons.insights, color: green),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'No transactions match this date range. Add a transaction or choose another period.',
            style: TextStyle(color: navy, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

String _monthName(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];
