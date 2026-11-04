import '../models/transaction.dart';

enum TransactionSortOrder { newest, oldest, highestAmount, lowestAmount }

class TransactionFilters {
  const TransactionFilters({
    this.isIncome,
    this.category,
    this.startDate,
    this.endDate,
    this.minimumAmount,
    this.maximumAmount,
    this.sortOrder = TransactionSortOrder.newest,
  });

  final bool? isIncome;
  final String? category;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? minimumAmount;
  final double? maximumAmount;
  final TransactionSortOrder sortOrder;

  bool get hasFilters =>
      isIncome != null ||
      category != null ||
      startDate != null ||
      endDate != null ||
      minimumAmount != null ||
      maximumAmount != null ||
      sortOrder != TransactionSortOrder.newest;

  List<Transaction> apply(
    Iterable<Transaction> transactions, {
    String searchQuery = '',
  }) {
    final query = searchQuery.trim().toLowerCase();
    final results = transactions.where((transaction) {
      if (query.isNotEmpty &&
          !transaction.title.toLowerCase().contains(query) &&
          !transaction.category.toLowerCase().contains(query)) {
        return false;
      }
      if (isIncome != null && transaction.isIncome != isIncome) return false;
      if (category != null && transaction.category != category) return false;

      final date = _dateOnly(transaction.date);
      if (startDate != null && date.isBefore(_dateOnly(startDate!))) {
        return false;
      }
      if (endDate != null && date.isAfter(_dateOnly(endDate!))) return false;
      if (minimumAmount != null && transaction.amount < minimumAmount!) {
        return false;
      }
      if (maximumAmount != null && transaction.amount > maximumAmount!) {
        return false;
      }
      return true;
    }).toList();

    switch (sortOrder) {
      case TransactionSortOrder.newest:
        results.sort((first, second) => second.date.compareTo(first.date));
      case TransactionSortOrder.oldest:
        results.sort((first, second) => first.date.compareTo(second.date));
      case TransactionSortOrder.highestAmount:
        results.sort((first, second) => second.amount.compareTo(first.amount));
      case TransactionSortOrder.lowestAmount:
        results.sort((first, second) => first.amount.compareTo(second.amount));
    }
    return results;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
