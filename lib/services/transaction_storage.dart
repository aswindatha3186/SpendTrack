import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction.dart';

class TransactionStorage {
  static const _transactionsKey = 'spendtrack_transactions';

  Future<List<Transaction>?> loadTransactions() async {
    final preferences = await SharedPreferences.getInstance();
    final savedData = preferences.getString(_transactionsKey);
    if (savedData == null) {
      return null;
    }

    final decoded = jsonDecode(savedData);
    if (decoded is! List) {
      throw const FormatException('Saved transactions must be a JSON list.');
    }

    final transactions = <Transaction>[];
    final ids = <String>{};
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Saved transaction has an invalid shape.');
      }

      final transaction = Transaction.fromJson(item);
      if (ids.add(transaction.id)) {
        transactions.add(transaction);
      }
    }
    return transactions;
  }

  Future<void> saveTransactions(Iterable<Transaction> transactions) async {
    final preferences = await SharedPreferences.getInstance();
    final ids = <String>{};
    final uniqueTransactions = transactions
        .where((transaction) => ids.add(transaction.id))
        .map((transaction) => transaction.toJson())
        .toList();
    final saved = await preferences.setString(
      _transactionsKey,
      jsonEncode(uniqueTransactions),
    );
    if (!saved) {
      throw StateError('Unable to save transactions to local storage.');
    }
  }
}
