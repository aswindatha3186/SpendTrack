class MonthlyBudget {
  final String id;
  final int year;
  final int month;
  final double amount;
  final Map<String, double> categoryLimits;

  MonthlyBudget({
    String? id,
    required this.year,
    required this.month,
    required this.amount,
    Map<String, double> categoryLimits = const {},
  }) : id = id ?? _monthId(year, month),
       categoryLimits = Map.unmodifiable(categoryLimits);

  static String _monthId(int year, int month) =>
      '$year-${month.toString().padLeft(2, '0')}';

  DateTime get monthStart => DateTime(year, month);

  Map<String, Object> toJson() => {
    'id': id,
    'year': year,
    'month': month,
    'amount': amount,
    'categoryLimits': categoryLimits,
  };

  factory MonthlyBudget.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final year = json['year'];
    final month = json['month'];
    final amount = json['amount'];
    final categoryLimits = json['categoryLimits'];

    if (id is! String ||
        id.isEmpty ||
        year is! int ||
        month is! int ||
        month < 1 ||
        month > 12 ||
        amount is! num ||
        !amount.isFinite ||
        amount <= 0 ||
        categoryLimits is! Map<String, dynamic>) {
      throw const FormatException('Invalid monthly budget data.');
    }

    final limits = <String, double>{};
    for (final entry in categoryLimits.entries) {
      final value = entry.value;
      if (value is! num || !value.isFinite || value <= 0) {
        throw const FormatException('Invalid monthly category limit.');
      }
      limits[entry.key] = value.toDouble();
    }

    return MonthlyBudget(
      id: id,
      year: year,
      month: month,
      amount: amount.toDouble(),
      categoryLimits: limits,
    );
  }
}
