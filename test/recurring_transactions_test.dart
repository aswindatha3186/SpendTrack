import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendtrack/main.dart';
import 'package:spendtrack/models/monthly_budget.dart';
import 'package:spendtrack/models/recurring_transaction.dart';
import 'package:spendtrack/models/transaction.dart';
import 'package:spendtrack/recurring/recurring_transaction_processor.dart';
import 'package:spendtrack/recurring/recurring_transactions_screen.dart';
import 'package:spendtrack/services/budget_storage.dart';
import 'package:spendtrack/services/notification_storage.dart';
import 'package:spendtrack/services/recurring_transaction_storage.dart';
import 'package:spendtrack/services/transaction_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('recurring transaction JSON preserves schedule fields', () {
    final rule = _rule(
      id: 'monthly-rent',
      title: 'Rent',
      amount: 800,
      frequency: RecurrenceFrequency.monthly,
      startDate: DateTime(2026, 1, 31),
      endDate: DateTime(2026, 6, 30),
      nextRunDate: DateTime(2026, 2, 28),
      isIncome: false,
    );

    final restored = RecurringTransaction.fromJson(rule.toJson());
    expect(restored.id, rule.id);
    expect(restored.title, rule.title);
    expect(restored.amount, rule.amount);
    expect(restored.frequency, rule.frequency);
    expect(restored.startDate, rule.startDate);
    expect(restored.endDate, rule.endDate);
    expect(restored.nextRunDate, rule.nextRunDate);
    expect(restored.isPaused, rule.isPaused);
  });

  test('recurring transaction rejects invalid amounts and date ranges', () {
    expect(() => _rule(amount: 0), throwsArgumentError);
    expect(
      () => _rule(
        startDate: DateTime(2026, 11, 6),
        endDate: DateTime(2026, 11, 5),
      ),
      throwsArgumentError,
    );
  });

  test('recurring storage survives reload and removes duplicate IDs', () async {
    final storage = RecurringTransactionStorage();
    final rule = _rule(id: 'salary');
    await storage.saveRecurringTransactions([rule, rule]);

    final restored = await RecurringTransactionStorage()
        .loadRecurringTransactions();
    expect(restored, hasLength(1));
    expect(restored.single.id, rule.id);
    expect(restored.single.title, 'Recurring item');
  });

  test('daily, weekly, monthly and yearly schedules advance correctly', () {
    final anchor = DateTime(2024, 1, 31);
    expect(
      RecurringTransactionProcessor.nextOccurrence(
        anchor,
        RecurrenceFrequency.daily,
        anchor,
      ),
      DateTime(2024, 2, 1),
    );
    expect(
      RecurringTransactionProcessor.nextOccurrence(
        anchor,
        RecurrenceFrequency.weekly,
        anchor,
      ),
      DateTime(2024, 2, 7),
    );
    expect(
      RecurringTransactionProcessor.nextOccurrence(
        anchor,
        RecurrenceFrequency.monthly,
        anchor,
      ),
      DateTime(2024, 2, 29),
    );
    expect(
      RecurringTransactionProcessor.nextOccurrence(
        DateTime(2024, 2, 29),
        RecurrenceFrequency.yearly,
        DateTime(2024, 2, 29),
      ),
      DateTime(2025, 2, 28),
    );
    expect(
      RecurringTransactionProcessor.nextOccurrence(
        DateTime(2025, 2, 28),
        RecurrenceFrequency.yearly,
        DateTime(2024, 2, 29),
      ),
      DateTime(2026, 2, 28),
    );
  });

  test('missed schedules catch up inclusively and advance their cursor', () {
    final rule = _rule(
      id: 'daily-coffee',
      frequency: RecurrenceFrequency.daily,
      startDate: DateTime(2026, 11, 1),
    );
    final result = RecurringTransactionProcessor.processDue(
      recurringTransactions: [rule],
      existingTransactions: [],
      throughDate: DateTime(2026, 11, 3, 23, 59),
    );

    expect(
      result.transactions.map((transaction) => transaction.date).toList(),
      [DateTime(2026, 11, 1), DateTime(2026, 11, 2), DateTime(2026, 11, 3)],
    );
    expect(
      result.transactions.every((item) => item.title == rule.title),
      isTrue,
    );
    expect(
      result.recurringTransactions.single.nextRunDate,
      DateTime(2026, 11, 4),
    );
  });

  test(
    'month-end schedules retain anchor day and honor inclusive end date',
    () {
      final rule = _rule(
        id: 'month-end',
        frequency: RecurrenceFrequency.monthly,
        startDate: DateTime(2026, 1, 31),
        endDate: DateTime(2026, 3, 31),
      );
      final result = RecurringTransactionProcessor.processDue(
        recurringTransactions: [rule],
        existingTransactions: [],
        throughDate: DateTime(2026, 4, 10),
      );

      expect(result.transactions.map((item) => item.date).toList(), [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
      ]);
      expect(result.recurringTransactions.single.isCompleted, isTrue);
    },
  );

  test('paused schedules skip dates while paused and resume in the future', () {
    final rule = _rule(
      id: 'paused',
      startDate: DateTime(2026, 11, 1),
      isPaused: true,
    );
    final result = RecurringTransactionProcessor.processDue(
      recurringTransactions: [rule],
      existingTransactions: [],
      throughDate: DateTime(2026, 11, 5),
    );
    expect(result.transactions, isEmpty);
    expect(
      result.recurringTransactions.single.nextRunDate,
      DateTime(2026, 11, 6),
    );

    final resumed = result.recurringTransactions.single.copyWith(
      isPaused: false,
    );
    final resumedResult = RecurringTransactionProcessor.processDue(
      recurringTransactions: [resumed],
      existingTransactions: [],
      throughDate: DateTime(2026, 11, 5),
    );
    expect(resumedResult.transactions, isEmpty);
  });

  test('recurring income preserves category and income classification', () {
    final rule = _rule(
      id: 'monthly-allowance',
      title: 'Allowance',
      category: 'Allowance',
      amount: 300,
      isIncome: true,
      frequency: RecurrenceFrequency.monthly,
      startDate: DateTime(2026, 11, 5),
    );
    final result = RecurringTransactionProcessor.processDue(
      recurringTransactions: [rule],
      existingTransactions: [],
      throughDate: DateTime(2026, 11, 5),
    );

    expect(result.transactions, hasLength(1));
    expect(result.transactions.single.isIncome, isTrue);
    expect(result.transactions.single.category, 'Allowance');
    expect(result.transactions.single.amount, 300);
  });

  test('existing stable transaction IDs prevent repeat generation', () {
    final rule = _rule(id: 'dedup', startDate: DateTime(2026, 11, 5));
    final scheduledId = RecurringTransactionProcessor.transactionId(
      rule.id,
      rule.startDate,
    );
    final existing = Transaction(
      id: scheduledId,
      title: rule.title,
      category: rule.category,
      amount: rule.amount,
      date: rule.startDate,
      isIncome: rule.isIncome,
    );
    final result = RecurringTransactionProcessor.processDue(
      recurringTransactions: [rule],
      existingTransactions: [existing],
      throughDate: DateTime(2026, 11, 5),
    );

    expect(result.transactions, isEmpty);
    expect(result.processedTransactions, hasLength(1));
    expect(
      result.recurringTransactions.single.nextRunDate,
      DateTime(2026, 11, 6),
    );
  });

  testWidgets('schedule screen creates, edits, pauses, resumes and deletes', (
    tester,
  ) async {
    var rules = <RecurringTransaction>[];
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => RecurringTransactionsScreen(
            initialRules: rules,
            onSave: (updated) async {
              setState(() => rules = updated);
              return updated;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-recurring-transaction')));
    await tester.pumpAndSettle();
    final saveButton = find.byKey(const Key('save-recurring-transaction'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a title and a valid positive amount.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('recurring-title-field')),
      'Monthly rent',
    );
    await tester.enterText(
      find.byKey(const Key('recurring-amount-field')),
      '900',
    );
    await tester.enterText(
      find.byKey(const Key('recurring-amount-field')),
      '0',
    );
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a title and a valid positive amount.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('recurring-amount-field')),
      '900',
    );
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(rules, hasLength(1));
    expect(find.text('Monthly rent'), findsOneWidget);

    final id = rules.single.id;
    await tester.tap(find.byKey(Key('recurring-menu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();
    expect(rules.single.isPaused, isTrue);
    expect(find.textContaining('Paused ·'), findsOneWidget);

    await tester.tap(find.byKey(Key('recurring-menu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    expect(rules.single.isPaused, isFalse);

    await tester.tap(find.byKey(Key('recurring-menu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('recurring-title-field')),
      'Updated rent',
    );
    await tester.ensureVisible(
      find.byKey(const Key('save-recurring-transaction')),
    );
    await tester.tap(find.byKey(const Key('save-recurring-transaction')));
    await tester.pumpAndSettle();
    expect(rules.single.title, 'Updated rent');
    expect(rules, hasLength(1));

    await tester.tap(find.byKey(Key('recurring-menu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete recurring transaction?'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(rules, isEmpty);
    expect(find.text('No recurring transactions'), findsOneWidget);
  });

  testWidgets(
    'due recurrence updates transactions, budgets and notifications',
    (tester) async {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day);
      final rule = _rule(
        id: 'monthly-recurring-expense',
        title: 'Recurring groceries',
        amount: 125,
        frequency: RecurrenceFrequency.daily,
        startDate: startDate,
        endDate: startDate,
      );
      await TransactionStorage().saveTransactions([]);
      await RecurringTransactionStorage().saveRecurringTransactions([rule]);
      await BudgetStorage().saveBudgets([
        MonthlyBudget(year: now.year, month: now.month, amount: 100),
      ]);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SpendTrackApp());
      await tester.pumpAndSettle();

      final generated = await TransactionStorage().loadTransactions();
      expect(generated, hasLength(1));
      expect(
        generated!.single.id,
        'recurring:monthly-recurring-expense:'
        '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-'
        '${startDate.day.toString().padLeft(2, '0')}',
      );
      expect(find.text('Recurring groceries'), findsOneWidget);
      expect(find.text('₹-125.00'), findsOneWidget);

      final processedRules = await RecurringTransactionStorage()
          .loadRecurringTransactions();
      expect(processedRules.single.isCompleted, isTrue);

      final notifications = await NotificationStorage().loadNotifications();
      expect(
        notifications.where(
          (item) => item.title == 'Recurring transaction processed',
        ),
        hasLength(1),
      );
      expect(
        notifications.where(
          (item) => item.title == 'Monthly budget reached 100%',
        ),
        hasLength(1),
      );

      await tester.pumpWidget(const SpendTrackApp());
      await tester.pumpAndSettle();
      expect(await TransactionStorage().loadTransactions(), hasLength(1));
      expect(await NotificationStorage().loadNotifications(), hasLength(4));

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Recurring groceries'), findsOneWidget);

      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();
      expect(find.text('₹125.00'), findsWidgets);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-recurring-transactions')));
      await tester.pumpAndSettle();
      expect(find.text('Recurring Transactions'), findsOneWidget);
      expect(find.textContaining('Completed ·'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-monthly-budgets')));
      await tester.pumpAndSettle();
      expect(find.text('₹125.00'), findsWidgets);
    },
  );
}

RecurringTransaction _rule({
  String id = 'recurring-1',
  String title = 'Recurring item',
  double amount = 25,
  String category = 'Food',
  bool isIncome = false,
  RecurrenceFrequency frequency = RecurrenceFrequency.daily,
  DateTime? startDate,
  DateTime? endDate,
  DateTime? nextRunDate,
  bool isPaused = false,
}) => RecurringTransaction(
  id: id,
  title: title,
  category: category,
  amount: amount,
  isIncome: isIncome,
  frequency: frequency,
  startDate: startDate ?? DateTime(2026, 11, 5),
  endDate: endDate,
  nextRunDate: nextRunDate,
  isPaused: isPaused,
);
