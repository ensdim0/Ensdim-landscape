class ClientComment {
  final String id;
  final String contractId;
  final String visitId;
  final String comment;
  final String? authorName;
  final String? authorUserId;
  final String createdAt;
  final String? attachmentPath;

  const ClientComment({
    required this.id,
    required this.contractId,
    required this.visitId,
    required this.comment,
    this.authorName,
    this.authorUserId,
    required this.createdAt,
    this.attachmentPath,
  });
}
