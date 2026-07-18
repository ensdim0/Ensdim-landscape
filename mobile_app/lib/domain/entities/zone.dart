class Zone {
  final String id;
  final String lineId;
  final String name;
  final bool isActive;
  final int sortOrder;
  final String createdAt;

  const Zone({
    required this.id,
    required this.lineId,
    required this.name,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
  });
}
