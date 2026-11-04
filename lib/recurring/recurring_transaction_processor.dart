import '../models/recurring_transaction.dart';
import '../models/transaction.dart';

class RecurringProcessingResult {
  const RecurringProcessingResult({
    required this.transactions,
    required this.processedTransactions,
    required this.recurringTransactions,
  });

  final List<Transaction> transactions;
  final List<Transaction> processedTransactions;
  final List<RecurringTransaction> recurringTransactions;
}

class RecurringTransactionProcessor {
  static RecurringProcessingResult processDue({
    required Iterable<RecurringTransaction> recurringTransactions,
    required Iterable<Transaction> existingTransactions,
    required DateTime throughDate,
  }) {
    final cutoff = _dateOnly(throughDate);
    final existingIds = existingTransactions.map((item) => item.id).toSet();
    final generated = <Transaction>[];
    final processed = <Transaction>[];
    final updatedRules = <RecurringTransaction>[];

    for (final rule in recurringTransactions) {
      var nextRunDate = rule.nextRunDate;
      while (!nextRunDate.isAfter(cutoff) &&
          (rule.endDate == null || !nextRunDate.isAfter(rule.endDate!))) {
        if (!rule.isPaused) {
          final transaction = Transaction(
            id: _transactionId(rule.id, nextRunDate),
            title: rule.title,
            category: rule.category,
            amount: rule.amount,
            date: nextRunDate,
            isIncome: rule.isIncome,
          );
          processed.add(transaction);
          if (existingIds.add(transaction.id)) generated.add(transaction);
        }
        nextRunDate = nextOccurrence(
          nextRunDate,
          rule.frequency,
          rule.startDate,
        );
      }

      updatedRules.add(rule.copyWith(nextRunDate: nextRunDate));
    }

    return RecurringProcessingResult(
      transactions: generated,
      processedTransactions: processed,
      recurringTransactions: updatedRules,
    );
  }

  static DateTime nextOccurrence(
    DateTime current,
    RecurrenceFrequency frequency,
    DateTime anchor,
  ) {
    switch (frequency) {
      case RecurrenceFrequency.daily:
        return DateTime(current.year, current.month, current.day + 1);
      case RecurrenceFrequency.weekly:
        return DateTime(current.year, current.month, current.day + 7);
      case RecurrenceFrequency.monthly:
        final nextMonth = DateTime(current.year, current.month + 1);
        final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
        return DateTime(
          nextMonth.year,
          nextMonth.month,
          anchor.day.clamp(1, lastDay),
        );
      case RecurrenceFrequency.yearly:
        final lastDay = DateTime(current.year + 1, anchor.month + 1, 0).day;
        return DateTime(
          current.year + 1,
          anchor.month,
          anchor.day.clamp(1, lastDay),
        );
    }
  }

  static String transactionId(String recurringId, DateTime date) =>
      _transactionId(recurringId, date);

  static String _transactionId(String recurringId, DateTime date) =>
      'recurring:$recurringId:${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
