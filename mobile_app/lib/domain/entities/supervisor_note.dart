class SupervisorNote {
  final String id;
  final String visitId;
  final String contractId;
  final String content;
  final String visibility; // 'supervisors_only' or 'all'
  final String? createdBy;
  final String createdAt;
  final String updatedAt;

  const SupervisorNote({
    required this.id,
    required this.visitId,
    required this.contractId,
    required this.content,
    required this.visibility,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isVisibleToClients => visibility == 'all';
  bool get isSupervisorsOnly => visibility == 'supervisors_only';

  factory SupervisorNote.fromJson(Map<String, dynamic> json) {
    return SupervisorNote(
      id: json['id'] as String? ?? '',
      visitId: json['visit_id'] as String? ?? '',
      contractId: json['contract_id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      visibility: json['visibility'] as String? ?? 'supervisors_only',
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'visit_id': visitId,
    'contract_id': contractId,
    'content': content,
    'visibility': visibility,
    'created_by': createdBy,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}
