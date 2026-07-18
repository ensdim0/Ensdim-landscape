import 'package:bustan_amari/domain/entities/contract.dart';
import 'package:bustan_amari/domain/entities/contract_payment.dart';
import 'package:bustan_amari/domain/entities/client_comment.dart';
import 'package:bustan_amari/domain/entities/contract_task.dart';
import 'package:bustan_amari/domain/entities/geographic_line.dart';
import 'package:bustan_amari/domain/entities/supervisor_note.dart';
import 'package:bustan_amari/domain/entities/task_execution.dart';
import 'package:bustan_amari/domain/entities/task_photo.dart';
import 'package:bustan_amari/domain/entities/visit.dart';
import 'package:bustan_amari/domain/entities/visit_photo.dart';
import 'package:bustan_amari/domain/entities/zone.dart';
import 'package:bustan_amari/domain/entities/standalone_task.dart';

/// Contract for all supervisor-specific data operations.
/// Implementations should respect RLS — only data for the
/// authenticated supervisor's assigned line is returned.
abstract class SupervisorRepository {
  /// Fetch the supervisor's assigned geographic line.
  Future<GeographicLine?> getAssignedLine();

  /// List all active contracts within the supervisor's assigned line.
  Future<List<Contract>> listAssignedContracts();

  /// IDs of contracts (within the supervisor's assigned line) that have at
  /// least one payment past its due date and not yet paid.
  Future<Set<String>> listLateContractIds();

  /// List all payments for a contract (restricted to the supervisor's
  /// assigned line via RLS-safe RPC).
  Future<List<ContractPayment>> listContractPayments(String contractId);

  /// List all active zones within the supervisor's assigned line.
  Future<List<Zone>> listAssignedZones();

  /// Get a single contract by ID.
  Future<Contract> getContract(String contractId);

  /// Request a contract status change for admin review.
  Future<void> requestContractStatusChange({
    required String contractId,
    required String requestedStatus,
  });

  /// List visits for a given contract.
  Future<List<Visit>> listVisits(String contractId);

  /// Get a single visit.
  Future<Visit> getVisit(String visitId);

  /// Update visit status (planned → in_progress → completed/cancelled).
  Future<Visit> updateVisitStatus({
    required String visitId,
    required String status,
  });

  /// Complete a visit with summary, GPS, and timestamp.
  Future<Visit> completeVisit({
    required String visitId,
    required String summary,
    double? gpsLat,
    double? gpsLng,
  });

  /// Mark a single task as completed in the database.
  Future<void> markTaskDone(String taskId);

  /// Revert a completed task back to pending.
  Future<void> unmarkTaskDone(String taskId);

  /// Upload a visit-level photo.
  Future<VisitPhoto> uploadVisitPhoto({
    required String visitId,
    required String filePath,
  });

  /// List photos for a visit.
  Future<List<VisitPhoto>> listVisitPhotos(String visitId);

  /// List client comments attached to a visit.
  Future<List<ClientComment>> listVisitComments(String visitId);

  /// List tasks for a given contract (optionally filtered by visit).
  Future<List<ContractTask>> listTasks({
    required String contractId,
    String? visitId,
  });

  /// Record a task execution with optional GPS and notes.
  Future<TaskExecution> createTaskExecution({
    required String taskId,
    required String visitId,
    String? notes,
    double? gpsLat,
    double? gpsLng,
  });

  /// Upload a before/after photo for a task execution.
  Future<TaskPhoto> uploadTaskPhoto({
    required String executionId,
    required String filePath,
    required String photoType,
  });

  /// List task executions for a visit.
  Future<List<TaskExecution>> listTaskExecutions(String visitId);

  /// List photos for a task execution.
  Future<List<TaskPhoto>> listTaskPhotos(String executionId);

  /// Get supervisor's summary stats (total contracts, visits, completions).
  Future<SupervisorStats> getStats();

  /// List supervisor notes for a visit.
  Future<List<SupervisorNote>> listSupervisorNotes(String visitId);

  /// Create a new supervisor note.
  Future<SupervisorNote> createSupervisorNote({
    required String visitId,
    required String contractId,
    required String content,
    required String visibility, // 'supervisors_only' or 'all'
  });

  /// Update a supervisor note.
  Future<SupervisorNote> updateSupervisorNote({
    required String noteId,
    required String content,
    required String visibility,
  });

  /// Delete a supervisor note.
  Future<void> deleteSupervisorNote(String noteId);

  /// List all standalone tasks assigned to the supervisor.
  Future<List<StandaloneTask>> listAssignedStandaloneTasks();

  /// Get a single standalone task by ID.
  Future<StandaloneTask> getStandaloneTask(String taskId);

  /// Update a standalone task status (pending → in_progress → completed/cancelled).
  /// If [supervisorReport] is provided it will be saved to the task and available to admins.
  Future<StandaloneTask> updateStandaloneTaskStatus({
    required String taskId,
    required String status,
    String? supervisorReport,
  });
}

/// Summary statistics for the supervisor dashboard.
class SupervisorStats {
  final int totalContracts;
  final int activeContracts;
  final int totalVisits;
  final int completedVisits;
  final int pendingTasks;
  final int completedTasks;
  final int visitsCompletedToday;
  final int standaloneTasksTotalToday;
  final int standaloneTasksCompletedToday;

  const SupervisorStats({
    required this.totalContracts,
    required this.activeContracts,
    required this.totalVisits,
    required this.completedVisits,
    required this.pendingTasks,
    required this.completedTasks,
    this.visitsCompletedToday = 0,
    this.standaloneTasksTotalToday = 0,
    this.standaloneTasksCompletedToday = 0,
  });

  double get visitCompletionRate =>
      totalVisits > 0 ? completedVisits / totalVisits : 0.0;

  double get taskCompletionRate => (pendingTasks + completedTasks) > 0
      ? completedTasks / (pendingTasks + completedTasks)
      : 0.0;

  double get standaloneTaskCompletionRateToday => standaloneTasksTotalToday > 0
      ? standaloneTasksCompletedToday / standaloneTasksTotalToday
      : 0.0;
}
