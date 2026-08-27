/// One row per person assigned to a standalone task's team — either a
/// supervisor (has a mobile app account) or a worker (cost/HR record only,
/// no login). Exactly one of [supervisorId] / [workerId] is set.
class StandaloneTaskAssignee {
  final String id;
  final String taskId;
  final String? supervisorId;
  final String? workerId;

  const StandaloneTaskAssignee({
    required this.id,
    required this.taskId,
    this.supervisorId,
    this.workerId,
  });

  bool get isSupervisor => supervisorId != null;
  bool get isWorker => workerId != null;

  factory StandaloneTaskAssignee.fromJson(Map<String, dynamic> json) {
    return StandaloneTaskAssignee(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      supervisorId: json['supervisor_id'] as String?,
      workerId: json['worker_id'] as String?,
    );
  }
}
