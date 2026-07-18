class Visit {
  final String id;
  final String contractId;
  final String? contractItemId;
  final String? title;
  final String? description;
  final String visitDate;
  final String? notes;
  final String status;
  final String? summary;
  final double? gpsLat;
  final double? gpsLng;
  final String? completedAt;
  final String createdAt;

  const Visit({
    required this.id,
    required this.contractId,
    this.contractItemId,
    this.title,
    this.description,
    required this.visitDate,
    this.notes,
    required this.status,
    this.summary,
    this.gpsLat,
    this.gpsLng,
    this.completedAt,
    required this.createdAt,
  });

  bool get isPlanned => status == 'planned';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get hasGps => gpsLat != null && gpsLng != null;

  String get groupingKey {
    if (contractItemId != null && contractItemId!.isNotEmpty) {
      return contractItemId!;
    }
    if (title != null && title!.trim().isNotEmpty) {
      return 'title:${title!.trim()}';
    }
    return 'general';
  }
}
