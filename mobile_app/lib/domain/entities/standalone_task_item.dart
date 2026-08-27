/// A checklist entry on a standalone task, entered by the admin at creation
/// time. Ending the visit is blocked until every item for the task is
/// completed (enforced server-side by end_standalone_task_visit()).
class StandaloneTaskItem {
  final String id;
  final String taskId;
  final String title;
  final String status; // 'pending' | 'completed'
  final int sortOrder;
  final String? completedBy;
  final String? completedAt;

  const StandaloneTaskItem({
    required this.id,
    required this.taskId,
    required this.title,
    required this.status,
    this.sortOrder = 0,
    this.completedBy,
    this.completedAt,
  });

  bool get isCompleted => status == 'completed';

  factory StandaloneTaskItem.fromJson(Map<String, dynamic> json) {
    return StandaloneTaskItem(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      title: json['title'] as String,
      status: json['status'] as String? ?? 'pending',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      completedBy: json['completed_by'] as String?,
      completedAt: json['completed_at'] as String?,
    );
  }

  StandaloneTaskItem copyWith({String? status, String? completedBy, String? completedAt}) {
    return StandaloneTaskItem(
      id: id,
      taskId: taskId,
      title: title,
      status: status ?? this.status,
      sortOrder: sortOrder,
      completedBy: completedBy,
      completedAt: completedAt,
    );
  }
}
