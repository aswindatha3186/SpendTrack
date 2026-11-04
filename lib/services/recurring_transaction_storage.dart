import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/recurring_transaction.dart';

class RecurringTransactionStorage {
  static const _recurringTransactionsKey = 'spendtrack_recurring_transactions';

  Future<List<RecurringTransaction>> loadRecurringTransactions() async {
    final preferences = await SharedPreferences.getInstance();
    final savedData = preferences.getString(_recurringTransactionsKey);
    if (savedData == null) return [];

    final decoded = jsonDecode(savedData);
    if (decoded is! List) {
      throw const FormatException(
        'Saved recurring transactions must be a JSON list.',
      );
    }
    final items = <RecurringTransaction>[];
    final ids = <String>{};
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException(
          'Saved recurring transaction has an invalid shape.',
        );
      }
      final recurring = RecurringTransaction.fromJson(item);
      if (ids.add(recurring.id)) items.add(recurring);
    }
    return items;
  }

  Future<void> saveRecurringTransactions(
    Iterable<RecurringTransaction> recurringTransactions,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final ids = <String>{};
    final unique = recurringTransactions
        .where((item) => ids.add(item.id))
        .map((item) => item.toJson())
        .toList();
    final saved = await preferences.setString(
      _recurringTransactionsKey,
      jsonEncode(unique),
    );
    if (!saved) {
      throw StateError('Unable to save recurring transactions locally.');
    }
  }
}
