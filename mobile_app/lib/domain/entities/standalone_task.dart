class StandaloneTask {
  final String id;
  final String title;
  final String? description;
  final String? address;
  final String? clientId;
  final String? clientName;
  final String? clientPhone;
  final String? supervisorId;
  final String? contractId;
  final String? zoneId;
  final String? zoneName;
  final String? lineId;
  final String? lineName;
  final double? cost;
  final String taskDate;
  final String? notes;
  final String? supervisorReport;
  final String status; // pending, in_progress, completed, cancelled
  final String createdAt;
  final String? updatedAt;
  final String paymentStatus; // 'unpaid' | 'paid'
  final String? paymentMethod;
  final String? visitStartedAt;
  final double? visitStartedLat;
  final double? visitStartedLng;
  final String? startedBy;
  final String? visitEndedAt;
  final double? visitEndedLat;
  final double? visitEndedLng;
  final String? endedBy;
  final String? paymentConfirmedAt;
  final String? paymentConfirmedBy;

  const StandaloneTask({
    required this.id,
    required this.title,
    this.description,
    this.address,
    this.clientId,
    this.clientName,
    this.clientPhone,
    this.supervisorId,
    this.contractId,
    this.zoneId,
    this.zoneName,
    this.lineId,
    this.lineName,
    this.cost,
    required this.taskDate,
    this.notes,
    this.supervisorReport,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.paymentStatus = 'unpaid',
    this.paymentMethod,
    this.visitStartedAt,
    this.visitStartedLat,
    this.visitStartedLng,
    this.startedBy,
    this.visitEndedAt,
    this.visitEndedLat,
    this.visitEndedLng,
    this.endedBy,
    this.paymentConfirmedAt,
    this.paymentConfirmedBy,
  });

  factory StandaloneTask.fromJson(Map<String, dynamic> json) {
    return StandaloneTask(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      address: json['address'] as String?,
      clientId: json['client_id'] as String?,
      clientName: json['client_name'] as String?,
      clientPhone: json['client_phone'] as String?,
      supervisorId: json['supervisor_id'] as String?,
      contractId: json['contract_id'] as String?,
      zoneId: json['zone_id'] as String?,
      zoneName: json['zone_name'] as String? ?? json['zoneName'] as String?,
      lineId: json['line_id'] as String?,
      lineName: json['line_name'] as String? ?? json['lineName'] as String?,
      cost: (json['cost'] as num?)?.toDouble(),
      taskDate: json['task_date'] as String,
      notes: json['notes'] as String?,
      supervisorReport:
          json['supervisor_report'] as String? ??
          json['supervisorReport'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String?,
      paymentStatus: json['payment_status'] as String? ?? 'unpaid',
      paymentMethod: json['payment_method'] as String?,
      visitStartedAt: json['visit_started_at'] as String?,
      visitStartedLat: (json['visit_started_lat'] as num?)?.toDouble(),
      visitStartedLng: (json['visit_started_lng'] as num?)?.toDouble(),
      startedBy: json['started_by'] as String?,
      visitEndedAt: json['visit_ended_at'] as String?,
      visitEndedLat: (json['visit_ended_lat'] as num?)?.toDouble(),
      visitEndedLng: (json['visit_ended_lng'] as num?)?.toDouble(),
      endedBy: json['ended_by'] as String?,
      paymentConfirmedAt: json['payment_confirmed_at'] as String?,
      paymentConfirmedBy: json['payment_confirmed_by'] as String?,
    );
  }

  StandaloneTask copyWith({
    String? id,
    String? title,
    String? description,
    String? address,
    String? clientId,
    String? clientName,
    String? clientPhone,
    String? supervisorId,
    String? contractId,
    String? zoneId,
    String? zoneName,
    String? lineId,
    String? lineName,
    double? cost,
    String? taskDate,
    String? notes,
    String? supervisorReport,
    String? status,
    String? createdAt,
    String? updatedAt,
    String? paymentStatus,
    String? paymentMethod,
    String? visitStartedAt,
    double? visitStartedLat,
    double? visitStartedLng,
    String? startedBy,
    String? visitEndedAt,
    double? visitEndedLat,
    double? visitEndedLng,
    String? endedBy,
    String? paymentConfirmedAt,
    String? paymentConfirmedBy,
  }) {
    return StandaloneTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      address: address ?? this.address,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      supervisorId: supervisorId ?? this.supervisorId,
      contractId: contractId ?? this.contractId,
      zoneId: zoneId ?? this.zoneId,
      zoneName: zoneName ?? this.zoneName,
      lineId: lineId ?? this.lineId,
      lineName: lineName ?? this.lineName,
      cost: cost ?? this.cost,
      taskDate: taskDate ?? this.taskDate,
      notes: notes ?? this.notes,
      supervisorReport: supervisorReport ?? this.supervisorReport,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      visitStartedAt: visitStartedAt ?? this.visitStartedAt,
      visitStartedLat: visitStartedLat ?? this.visitStartedLat,
      visitStartedLng: visitStartedLng ?? this.visitStartedLng,
      startedBy: startedBy ?? this.startedBy,
      visitEndedAt: visitEndedAt ?? this.visitEndedAt,
      visitEndedLat: visitEndedLat ?? this.visitEndedLat,
      visitEndedLng: visitEndedLng ?? this.visitEndedLng,
      endedBy: endedBy ?? this.endedBy,
      paymentConfirmedAt: paymentConfirmedAt ?? this.paymentConfirmedAt,
      paymentConfirmedBy: paymentConfirmedBy ?? this.paymentConfirmedBy,
    );
  }
}
