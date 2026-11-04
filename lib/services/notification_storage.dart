import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';

class NotificationStorage {
  static const _notificationsKey = 'spendtrack_notifications';
  static const _alertKeysKey = 'spendtrack_notification_alert_keys';
  static const _budgetAlertsEnabledKey = 'spendtrack_budget_alerts_enabled';

  Future<List<AppNotification>> loadNotifications() async {
    final preferences = await SharedPreferences.getInstance();
    final savedData = preferences.getString(_notificationsKey);
    if (savedData == null) return [];

    final decoded = jsonDecode(savedData);
    if (decoded is! List) {
      throw const FormatException('Saved notifications must be a JSON list.');
    }

    final notifications = <AppNotification>[];
    final ids = <String>{};
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Saved notification has an invalid shape.');
      }
      final notification = AppNotification.fromJson(item);
      if (ids.add(notification.id)) notifications.add(notification);
    }
    return notifications;
  }

  Future<void> addIfAbsent(Iterable<AppNotification> candidates) async {
    final preferences = await SharedPreferences.getInstance();
    final notifications = await loadNotifications();
    final alertKeys = preferences.getStringList(_alertKeysKey)?.toSet() ?? {};
    for (final notification in notifications) {
      final key = notification.deduplicationKey;
      if (key != null) alertKeys.add(key);
    }

    final ids = notifications.map((item) => item.id).toSet();
    var changed = false;
    for (final notification in candidates) {
      final alertKey = notification.deduplicationKey;
      if (alertKey != null && !alertKeys.add(alertKey)) continue;
      if (!ids.add(notification.id)) continue;
      notifications.insert(0, notification);
      changed = true;
    }

    if (changed) {
      await _saveNotifications(preferences, notifications);
    }
    final savedKeys = await preferences.setStringList(
      _alertKeysKey,
      alertKeys.toList(),
    );
    if (!savedKeys) {
      throw StateError('Unable to save notification alert history.');
    }
  }

  Future<void> markRead(String id, {required bool isRead}) async {
    final preferences = await SharedPreferences.getInstance();
    final notifications = await loadNotifications();
    final index = notifications.indexWhere((item) => item.id == id);
    if (index < 0) return;
    notifications[index] = notifications[index].copyWith(isRead: isRead);
    await _saveNotifications(preferences, notifications);
  }

  Future<void> markAllRead() async {
    final preferences = await SharedPreferences.getInstance();
    final notifications = (await loadNotifications())
        .map((item) => item.copyWith(isRead: true))
        .toList();
    await _saveNotifications(preferences, notifications);
  }

  Future<void> delete(String id) async {
    final preferences = await SharedPreferences.getInstance();
    final notifications = await loadNotifications()
      ..removeWhere((item) => item.id == id);
    await _saveNotifications(preferences, notifications);
  }

  Future<void> clearAll() async {
    final preferences = await SharedPreferences.getInstance();
    await _saveNotifications(preferences, []);
  }

  Future<bool> loadBudgetAlertsEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_budgetAlertsEnabledKey) ?? true;
  }

  Future<void> saveBudgetAlertsEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setBool(_budgetAlertsEnabledKey, enabled);
    if (!saved) {
      throw StateError('Unable to save budget notification settings.');
    }
  }

  Future<void> _saveNotifications(
    SharedPreferences preferences,
    List<AppNotification> notifications,
  ) async {
    final saved = await preferences.setString(
      _notificationsKey,
      jsonEncode(notifications.map((item) => item.toJson()).toList()),
    );
    if (!saved) {
      throw StateError('Unable to save notifications to local storage.');
    }
  }
}
