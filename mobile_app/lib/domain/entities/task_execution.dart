class TaskExecution {
  final String id;
  final String taskId;
  final String supervisorId;
  final String? visitId;
  final String? notes;
  final String status;
  final double? gpsLat;
  final double? gpsLng;
  final String createdAt;

  const TaskExecution({
    required this.id,
    required this.taskId,
    required this.supervisorId,
    this.visitId,
    this.notes,
    required this.status,
    this.gpsLat,
    this.gpsLng,
    required this.createdAt,
  });

  bool get hasGps => gpsLat != null && gpsLng != null;
}
