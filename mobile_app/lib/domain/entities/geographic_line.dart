class GeographicLine {
  final String id;
  final String name;
  final String lineType;
  final String status;
  final String? phoneNumber;
  final String? carNumber;
  final String createdAt;

  const GeographicLine({
    required this.id,
    required this.name,
    required this.lineType,
    required this.status,
    this.phoneNumber,
    this.carNumber,
    required this.createdAt,
  });

  bool get isActive => status == 'active';
}
