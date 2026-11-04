class AppNotification {
  static int _nextId = 0;

  AppNotification({
    String? id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.deduplicationKey,
  }) : id = id ?? _generateId();

  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? deduplicationKey;

  static String _generateId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    title: title,
    message: message,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
    deduplicationKey: deduplicationKey,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead,
    'deduplicationKey': deduplicationKey,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final message = json['message'];
    final createdAt = json['createdAt'];
    final isRead = json['isRead'];
    final deduplicationKey = json['deduplicationKey'];

    if (id is! String ||
        id.isEmpty ||
        title is! String ||
        message is! String ||
        createdAt is! String ||
        isRead is! bool ||
        (deduplicationKey != null && deduplicationKey is! String)) {
      throw const FormatException('Invalid notification data.');
    }

    return AppNotification(
      id: id,
      title: title,
      message: message,
      createdAt: DateTime.parse(createdAt),
      isRead: isRead,
      deduplicationKey: deduplicationKey as String?,
    );
  }
}
