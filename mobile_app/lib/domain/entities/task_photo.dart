class TaskPhoto {
  final String id;
  final String executionId;
  final String photoPath;
  final String photoType;
  final String createdAt;

  const TaskPhoto({
    required this.id,
    required this.executionId,
    required this.photoPath,
    required this.photoType,
    required this.createdAt,
  });

  bool get isBefore => photoType == 'before';
  bool get isAfter => photoType == 'after';
}
