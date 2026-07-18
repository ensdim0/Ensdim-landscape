class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String? body;
  final bool isRead;
  final Map<String, dynamic> meta;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    this.body,
    required this.isRead,
    required this.meta,
    required this.createdAt,
  });
}
