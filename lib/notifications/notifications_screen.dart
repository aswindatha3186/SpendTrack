import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../theme/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    required this.notifications,
    required this.budgetAlertsEnabled,
    required this.onMarkRead,
    required this.onMarkAllRead,
    required this.onDelete,
    required this.onClearAll,
    required this.onBudgetAlertsChanged,
    super.key,
  });

  final List<AppNotification> notifications;
  final bool budgetAlertsEnabled;
  final Future<void> Function(String id, bool isRead) onMarkRead;
  final Future<void> Function() onMarkAllRead;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function() onClearAll;
  final Future<void> Function(bool enabled) onBudgetAlertsChanged;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late List<AppNotification> _notifications;
  late bool _budgetAlertsEnabled;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _notifications = List.of(widget.notifications);
    _budgetAlertsEnabled = widget.budgetAlertsEnabled;
  }

  @override
  void didUpdateWidget(covariant NotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notifications != widget.notifications) {
      _notifications = List.of(widget.notifications);
    }
    if (oldWidget.budgetAlertsEnabled != widget.budgetAlertsEnabled) {
      _budgetAlertsEnabled = widget.budgetAlertsEnabled;
    }
  }

  int get _unreadCount => _notifications.where((item) => !item.isRead).length;

  Future<void> _perform(Future<void> Function() action) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      await action();
    } catch (error, stackTrace) {
      debugPrint('Failed to update notifications: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update notifications. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _markRead(AppNotification notification) => _perform(() async {
    final nextReadState = !notification.isRead;
    await widget.onMarkRead(notification.id, nextReadState);
    if (!mounted) return;
    setState(() {
      _notifications = _notifications
          .map(
            (item) => item.id == notification.id
                ? item.copyWith(isRead: nextReadState)
                : item,
          )
          .toList();
    });
  });

  Future<void> _markAllRead() => _perform(() async {
    await widget.onMarkAllRead();
    if (mounted) {
      setState(() {
        _notifications = _notifications
            .map((item) => item.copyWith(isRead: true))
            .toList();
      });
    }
  });

  Future<void> _delete(AppNotification notification) => _perform(() async {
    await widget.onDelete(notification.id);
    if (mounted) {
      setState(() {
        _notifications.removeWhere((item) => item.id == notification.id);
      });
    }
  });

  Future<void> _clearAll() async {
    if (_notifications.isEmpty || _isUpdating) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('This removes all saved in-app notifications.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _perform(() async {
      await widget.onClearAll();
      if (mounted) setState(() => _notifications.clear());
    });
  }

  Future<void> _setBudgetAlerts(bool enabled) => _perform(() async {
    await widget.onBudgetAlertsChanged(enabled);
    if (mounted) setState(() => _budgetAlertsEnabled = enabled);
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Notifications',
        style: TextStyle(color: navy, fontWeight: FontWeight.bold),
      ),
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      actions: [
        if (_notifications.isNotEmpty)
          IconButton(
            key: const Key('clear-all-notifications'),
            tooltip: 'Clear all notifications',
            onPressed: _isUpdating ? null : _clearAll,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
      ],
    ),
    body: Column(
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          color: Colors.white,
          child: SwitchListTile(
            key: const Key('budget-alerts-setting'),
            value: _budgetAlertsEnabled,
            onChanged: _isUpdating ? null : _setBudgetAlerts,
            activeThumbColor: green,
            title: const Text(
              'Budget alerts',
              style: TextStyle(color: navy, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'In-app alerts at 70%, 90% and 100% of budget limits.',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _unreadCount == 0 ? 'All caught up' : '$_unreadCount unread',
                  style: const TextStyle(
                    color: navy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                key: const Key('mark-all-notifications-read'),
                onPressed: _isUpdating || _unreadCount == 0
                    ? null
                    : _markAllRead,
                child: const Text('Mark all as read'),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'These are in-app notifications only; Android push notifications are not enabled.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ),
        Expanded(
          child: _notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none, color: green, size: 42),
                      SizedBox(height: 12),
                      Text(
                        'No notifications yet',
                        style: TextStyle(
                          color: navy,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) =>
                      _notificationCard(_notifications[index]),
                ),
        ),
      ],
    ),
  );

  Widget _notificationCard(AppNotification notification) {
    final timestamp = _formatDateTime(notification.createdAt);
    return Card(
      key: Key('notification-${notification.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      color: notification.isRead ? Colors.white : const Color(0xFFEAF7EE),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Icon(
                notification.deduplicationKey == null
                    ? Icons.receipt_long_outlined
                    : Icons.savings_outlined,
                color: green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: const TextStyle(
                            color: navy,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.circle, size: 8, color: green),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    notification.message,
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    timestamp,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              key: Key('notification-menu-${notification.id}'),
              onSelected: (action) {
                if (action == 'read') _markRead(notification);
                if (action == 'delete') _delete(notification);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'read',
                  child: Text(
                    notification.isRead ? 'Mark unread' : 'Mark read',
                  ),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour < 12 ? 'AM' : 'PM';
    return '${dateTime.day.toString().padLeft(2, '0')}/'
        '${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} '
        '$hour:$minute $period';
  }
}
