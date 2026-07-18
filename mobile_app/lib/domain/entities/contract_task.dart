class ContractTask {
  final String id;
  final String contractId;
  final String? visitId;
  final String title;
  final int month;
  final String status;
  final String createdAt;

  const ContractTask({
    required this.id,
    required this.contractId,
    this.visitId,
    required this.title,
    required this.month,
    required this.status,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isVerified => status == 'verified';
  bool get isRejected => status == 'rejected';
}
