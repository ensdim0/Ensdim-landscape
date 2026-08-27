import 'package:ensdim_landscape/domain/entities/standalone_task.dart';

/// Result of calling start_standalone_task_visit() / end_standalone_task_visit().
/// [success] is false when someone else on the team already did it, the
/// checklist isn't fully completed yet (end only), or the visit is in the
/// wrong state — [task] always carries the current authoritative state so
/// the UI can show what actually happened without a second round trip.
class StandaloneTaskVisitResult {
  final bool success;
  final String? reason; // end only: 'pending_items' | 'already_ended' | 'not_authorized'
  final StandaloneTask task;

  const StandaloneTaskVisitResult({
    required this.success,
    required this.task,
    this.reason,
  });
}

/// Result of calling confirm_standalone_task_payment().
class StandaloneTaskPaymentResult {
  final bool success;
  final StandaloneTask task;

  const StandaloneTaskPaymentResult({required this.success, required this.task});
}
