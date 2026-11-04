import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendtrack/models/app_notification.dart';
import 'package:spendtrack/models/monthly_budget.dart';
import 'package:spendtrack/models/transaction.dart';
import 'package:spendtrack/notifications/budget_notification_generator.dart';
import 'package:spendtrack/notifications/notifications_screen.dart';
import 'package:spendtrack/services/notification_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('budget alerts are generated at 70, 90 and 100 percent thresholds', () {
    final budget = MonthlyBudget(year: 2026, month: 11, amount: 100);
    final createdAt = DateTime(2026, 11, 5, 10, 30);

    for (final entry in [
      (spent: 69.99, expected: 0),
      (spent: 70.0, expected: 1),
      (spent: 90.0, expected: 2),
      (spent: 100.0, expected: 3),
    ]) {
      final alerts = BudgetNotificationGenerator.generate(
        budgets: [budget],
        transactions: [_expense('total-${entry.spent}', entry.spent, 'Food')],
        createdAt: createdAt,
      );
      expect(alerts, hasLength(entry.expected));
      expect(alerts.every((alert) => alert.createdAt == createdAt), isTrue);
    }
  });

  test('category alerts use category limits and exclude income', () {
    final budget = MonthlyBudget(
      year: 2026,
      month: 11,
      amount: 1000,
      categoryLimits: {'Food': 100},
    );
    final alerts = BudgetNotificationGenerator.generate(
      budgets: [budget],
      transactions: [
        _expense('food', 100, 'Food'),
        _expense('income', 5000, 'Salary', isIncome: true),
      ],
      createdAt: DateTime(2026, 11, 5),
    );

    expect(alerts, hasLength(3));
    expect(
      alerts.every((alert) => alert.title.startsWith('Food budget')),
      isTrue,
    );
  });

  test(
    'budget alert keys prevent duplicates even after deleting alerts',
    () async {
      final storage = NotificationStorage();
      final now = DateTime(2026, 11, 5);
      final alerts = BudgetNotificationGenerator.generate(
        budgets: [MonthlyBudget(year: 2026, month: 11, amount: 100)],
        transactions: [_expense('expense', 100, 'Food')],
        createdAt: now,
      );

      await storage.addIfAbsent(alerts);
      expect(await storage.loadNotifications(), hasLength(3));
      await storage.addIfAbsent(alerts);
      expect(await storage.loadNotifications(), hasLength(3));

      await storage.delete(alerts.first.id);
      expect(await storage.loadNotifications(), hasLength(2));
      await storage.addIfAbsent(alerts);
      expect(await storage.loadNotifications(), hasLength(2));

      await storage.clearAll();
      await storage.addIfAbsent(alerts);
      expect(await storage.loadNotifications(), isEmpty);
    },
  );

  test('read state, settings and notifications persist after reload', () async {
    final storage = NotificationStorage();
    final notification = AppNotification(
      id: 'transaction-notification',
      title: 'Transaction added',
      message: 'A transaction was saved.',
      createdAt: DateTime(2026, 11, 5, 10, 15),
    );

    await storage.addIfAbsent([notification]);
    await storage.markRead(notification.id, isRead: true);
    await storage.saveBudgetAlertsEnabled(false);

    final restartedStorage = NotificationStorage();
    final restored = await restartedStorage.loadNotifications();
    expect(restored, hasLength(1));
    expect(restored.single.title, notification.title);
    expect(restored.single.createdAt, notification.createdAt);
    expect(restored.single.isRead, isTrue);
    expect(await restartedStorage.loadBudgetAlertsEnabled(), isFalse);

    await restartedStorage.markAllRead();
    expect(
      (await restartedStorage.loadNotifications()).every((item) => item.isRead),
      isTrue,
    );
  });

  testWidgets('notifications screen marks read and confirms clear all', (
    tester,
  ) async {
    var notifications = [
      AppNotification(
        id: 'notice-1',
        title: 'Transaction added',
        message: 'Groceries were saved.',
        createdAt: DateTime(2026, 11, 5, 10, 15),
      ),
      AppNotification(
        id: 'notice-2',
        title: 'Food budget reached 70%',
        message: 'You reached the budget alert threshold.',
        createdAt: DateTime(2026, 11, 5, 11),
        deduplicationKey: 'budget:2026-11:category:Food:70',
      ),
    ];
    var budgetAlertsEnabled = true;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => NotificationsScreen(
            notifications: notifications,
            budgetAlertsEnabled: budgetAlertsEnabled,
            onMarkRead: (id, isRead) async {
              setState(() {
                notifications = notifications
                    .map(
                      (item) =>
                          item.id == id ? item.copyWith(isRead: isRead) : item,
                    )
                    .toList();
              });
            },
            onMarkAllRead: () async {
              setState(() {
                notifications = notifications
                    .map((item) => item.copyWith(isRead: true))
                    .toList();
              });
            },
            onDelete: (id) async {
              setState(
                () => notifications.removeWhere((item) => item.id == id),
              );
            },
            onClearAll: () async => setState(() => notifications = []),
            onBudgetAlertsChanged: (enabled) async {
              setState(() => budgetAlertsEnabled = enabled);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 unread'), findsOneWidget);
    expect(find.textContaining('05/11/2026'), findsWidgets);

    await tester.tap(find.byKey(const Key('notification-menu-notice-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark read'));
    await tester.pumpAndSettle();
    expect(find.text('1 unread'), findsOneWidget);

    await tester.tap(find.byKey(const Key('notification-menu-notice-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Food budget reached 70%'), findsNothing);

    await tester.tap(find.byKey(const Key('mark-all-notifications-read')));
    await tester.pumpAndSettle();
    expect(find.text('All caught up'), findsOneWidget);

    await tester.tap(find.byKey(const Key('clear-all-notifications')));
    await tester.pumpAndSettle();
    expect(find.text('Clear all notifications?'), findsOneWidget);
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(find.text('No notifications yet'), findsOneWidget);
  });
}

Transaction _expense(
  String id,
  double amount,
  String category, {
  bool isIncome = false,
}) => Transaction(
  id: id,
  title: id,
  category: category,
  amount: amount,
  date: DateTime(2026, 11, 5),
  isIncome: isIncome,
);
