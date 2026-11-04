enum RecurrenceFrequency { daily, weekly, monthly, yearly }

class RecurringTransaction {
  static int _nextId = 0;

  RecurringTransaction({
    String? id,
    required this.title,
    required this.category,
    required this.amount,
    required this.isIncome,
    required this.frequency,
    required DateTime startDate,
    DateTime? endDate,
    DateTime? nextRunDate,
    this.isPaused = false,
  }) : id = id ?? _generateId(),
       startDate = _dateOnly(startDate),
       endDate = endDate == null ? null : _dateOnly(endDate),
       nextRunDate = _dateOnly(nextRunDate ?? startDate) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'Must not be empty.');
    }
    if (category.trim().isEmpty) {
      throw ArgumentError.value(category, 'category', 'Must not be empty.');
    }
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Must be positive and finite.',
      );
    }
    if (this.endDate != null && this.endDate!.isBefore(this.startDate)) {
      throw ArgumentError.value(
        endDate,
        'endDate',
        'Must not precede startDate.',
      );
    }
    if (this.nextRunDate.isBefore(this.startDate)) {
      throw ArgumentError.value(
        nextRunDate,
        'nextRunDate',
        'Must not precede startDate.',
      );
    }
  }

  final String id;
  final String title;
  final String category;
  final double amount;
  final bool isIncome;
  final RecurrenceFrequency frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextRunDate;
  final bool isPaused;

  bool get isCompleted => endDate != null && nextRunDate.isAfter(endDate!);

  RecurringTransaction copyWith({
    String? title,
    String? category,
    double? amount,
    bool? isIncome,
    RecurrenceFrequency? frequency,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    DateTime? nextRunDate,
    bool? isPaused,
  }) => RecurringTransaction(
    id: id,
    title: title ?? this.title,
    category: category ?? this.category,
    amount: amount ?? this.amount,
    isIncome: isIncome ?? this.isIncome,
    frequency: frequency ?? this.frequency,
    startDate: startDate ?? this.startDate,
    endDate: clearEndDate ? null : endDate ?? this.endDate,
    nextRunDate: nextRunDate ?? this.nextRunDate,
    isPaused: isPaused ?? this.isPaused,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'amount': amount,
    'isIncome': isIncome,
    'frequency': frequency.name,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'nextRunDate': nextRunDate.toIso8601String(),
    'isPaused': isPaused,
  };

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final category = json['category'];
    final amount = json['amount'];
    final isIncome = json['isIncome'];
    final frequencyName = json['frequency'];
    final startDate = json['startDate'];
    final endDate = json['endDate'];
    final nextRunDate = json['nextRunDate'];
    final isPaused = json['isPaused'];

    final frequency = RecurrenceFrequency.values
        .where((value) => value.name == frequencyName)
        .firstOrNull;
    if (id is! String ||
        id.isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        category is! String ||
        category.isEmpty ||
        amount is! num ||
        !amount.isFinite ||
        amount <= 0 ||
        isIncome is! bool ||
        frequency is! RecurrenceFrequency ||
        startDate is! String ||
        (endDate != null && endDate is! String) ||
        nextRunDate is! String ||
        isPaused is! bool) {
      throw const FormatException('Invalid recurring transaction data.');
    }

    try {
      return RecurringTransaction(
        id: id,
        title: title,
        category: category,
        amount: amount.toDouble(),
        isIncome: isIncome,
        frequency: frequency,
        startDate: DateTime.parse(startDate),
        endDate: endDate == null ? null : DateTime.parse(endDate as String),
        nextRunDate: DateTime.parse(nextRunDate),
        isPaused: isPaused,
      );
    } on FormatException {
      rethrow;
    } on ArgumentError {
      throw const FormatException('Invalid recurring transaction dates.');
    }
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _generateId() =>
      'recurring-${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';
}
