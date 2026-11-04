import 'package:flutter_test/flutter_test.dart';
import 'package:spendtrack/models/transaction.dart';
import 'package:spendtrack/transactions/transaction_filter.dart';

void main() {
  final transactions = [
    _transaction(
      id: 'food-old',
      title: 'Market groceries',
      category: 'Food',
      amount: 70,
      date: DateTime(2026, 11, 1, 21),
    ),
    _transaction(
      id: 'food-new',
      title: 'Weekly groceries',
      category: 'Food',
      amount: 120,
      date: DateTime(2026, 11, 3),
    ),
    _transaction(
      id: 'travel',
      title: 'Bus pass',
      category: 'Travel',
      amount: 95,
      date: DateTime(2026, 11, 2),
    ),
    _transaction(
      id: 'salary',
      title: 'Monthly salary',
      category: 'Salary',
      amount: 120,
      date: DateTime(2026, 11, 4),
      isIncome: true,
    ),
  ];

  test('search, type, category, dates and amount limits combine', () {
    final visible = TransactionFilters(
      isIncome: false,
      category: 'Food',
      startDate: DateTime(2026, 11, 2, 18),
      endDate: DateTime(2026, 11, 3, 10),
      minimumAmount: 100,
      maximumAmount: 120,
    ).apply(transactions, searchQuery: 'gRoCeRiEs');

    expect(visible.map((item) => item.id), ['food-new']);
  });

  test(
    'date range includes whole boundary days and excludes adjacent days',
    () {
      final visible = TransactionFilters(
        startDate: DateTime(2026, 11, 2),
        endDate: DateTime(2026, 11, 3),
      ).apply(transactions);

      expect(visible.map((item) => item.id).toSet(), {'travel', 'food-new'});
    },
  );

  test('search matches title or category case-insensitively', () {
    expect(
      TransactionFilters().apply(transactions, searchQuery: 'salary').single.id,
      'salary',
    );
    expect(
      TransactionFilters().apply(transactions, searchQuery: 'TRAVEL').single.id,
      'travel',
    );
  });

  test('amount limits include endpoints and reject unmatched results', () {
    final visible = TransactionFilters(
      minimumAmount: 95,
      maximumAmount: 120,
    ).apply(transactions, searchQuery: 'Food');
    expect(visible.map((item) => item.id), ['food-new']);

    expect(TransactionFilters(maximumAmount: 5).apply(transactions), isEmpty);
  });

  test('all sorting choices produce the requested order', () {
    expect(
      TransactionFilters(sortOrder: TransactionSortOrder.newest)
          .apply(transactions)
          .map((item) => item.id)
          .toList(),
      ['salary', 'food-new', 'travel', 'food-old'],
    );
    expect(
      TransactionFilters(sortOrder: TransactionSortOrder.oldest)
          .apply(transactions)
          .map((item) => item.id)
          .toList(),
      ['food-old', 'travel', 'food-new', 'salary'],
    );
    expect(
      TransactionFilters(sortOrder: TransactionSortOrder.highestAmount)
          .apply(transactions)
          .map((item) => item.id)
          .toList(),
      ['food-new', 'salary', 'travel', 'food-old'],
    );
    expect(
      TransactionFilters(sortOrder: TransactionSortOrder.lowestAmount)
          .apply(transactions)
          .map((item) => item.id)
          .toList(),
      ['food-old', 'travel', 'food-new', 'salary'],
    );
  });
}

Transaction _transaction({
  required String id,
  required String title,
  required String category,
  required double amount,
  required DateTime date,
  bool isIncome = false,
}) => Transaction(
  id: id,
  title: title,
  category: category,
  amount: amount,
  date: date,
  isIncome: isIncome,
);
