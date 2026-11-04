class Transaction {
  static int _nextId = 0;

  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime date;
  final bool isIncome;

  Transaction({
    String? id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.isIncome,
  }) : id = id ?? _generateId();

  static String _generateId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'amount': amount,
    'date': date.toIso8601String(),
    'isIncome': isIncome,
  };

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final category = json['category'];
    final amount = json['amount'];
    final date = json['date'];
    final isIncome = json['isIncome'];

    if (id is! String ||
        id.isEmpty ||
        title is! String ||
        category is! String ||
        amount is! num ||
        !amount.isFinite ||
        date is! String ||
        isIncome is! bool) {
      throw const FormatException('Invalid transaction data.');
    }

    return Transaction(
      id: id,
      title: title,
      category: category,
      amount: amount.toDouble(),
      date: DateTime.parse(date),
      isIncome: isIncome,
    );
  }
}
