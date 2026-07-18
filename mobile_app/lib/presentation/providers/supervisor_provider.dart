import 'package:flutter/foundation.dart';
import 'package:bustan_amari/domain/entities/client_comment.dart';
import 'package:bustan_amari/domain/entities/contract.dart';
import 'package:bustan_amari/domain/entities/contract_payment.dart';
import 'package:bustan_amari/domain/entities/contract_task.dart';
import 'package:bustan_amari/domain/entities/geographic_line.dart';
import 'package:bustan_amari/domain/entities/supervisor_note.dart';
import 'package:bustan_amari/domain/entities/task_execution.dart';
import 'package:bustan_amari/domain/entities/task_photo.dart';
import 'package:bustan_amari/domain/entities/visit.dart';
import 'package:bustan_amari/domain/entities/visit_photo.dart';
import 'package:bustan_amari/domain/entities/zone.dart';
import 'package:bustan_amari/domain/entities/standalone_task.dart';
import 'package:bustan_amari/domain/repositories/supervisor_repository.dart';

enum DataStatus { initial, loading, loaded, error }

/// Central state management for all supervisor data operations.
class SupervisorProvider extends ChangeNotifier {
  final SupervisorRepository _repository;

  SupervisorProvider(this._repository);

  // ───── State ─────

  DataStatus _status = DataStatus.initial;
  DataStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  GeographicLine? _assignedLine;
  GeographicLine? get assignedLine => _assignedLine;

  SupervisorStats? _stats;
  SupervisorStats? get stats => _stats;

  List<Contract> _contracts = [];
  List<Contract> get contracts => _contracts;

  Set<String> _lateContractIds = {};
  Set<String> get lateContractIds => _lateContractIds;

  List<Zone> _assignedZones = [];
  List<Zone> get assignedZones => _assignedZones;

  Contract? _selectedContract;
  Contract? get selectedContract => _selectedContract;

  List<Visit> _visits = [];
  List<Visit> get visits => _visits;

  Visit? _selectedVisit;
  Visit? get selectedVisit => _selectedVisit;

  List<ContractTask> _tasks = [];
  List<ContractTask> get tasks => _tasks;

  Map<String, List<ContractTask>> _visitTasks = {};
  Map<String, List<ContractTask>> get visitTasks => _visitTasks;

  List<TaskExecution> _executions = [];
  List<TaskExecution> get executions => _executions;

  List<TaskPhoto> _photos = [];
  List<TaskPhoto> get photos => _photos;

  List<VisitPhoto> _visitPhotos = [];
  List<VisitPhoto> get visitPhotos => _visitPhotos;

  List<ClientComment> _visitComments = [];
  List<ClientComment> get visitComments => _visitComments;

  List<SupervisorNote> _supervisorNotes = [];
  List<SupervisorNote> get supervisorNotes => _supervisorNotes;

  List<StandaloneTask> _standaloneTasks = [];
  List<StandaloneTask> get standaloneTasks => _standaloneTasks;

  bool _isLoadingStandaloneTasks = false;
  bool get isLoadingStandaloneTasks => _isLoadingStandaloneTasks;

  bool _isActionLoading = false;
  bool get isActionLoading => _isActionLoading;

  String _sanitizeVisitSummary(String input) {
    final normalizedLines = input
        .replaceAll(RegExp(r'\b(?:https?|ftp)://\S+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bwww\.\S+', caseSensitive: false), '')
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceAll(RegExp(r'\s{2,}'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return normalizedLines.join('\n').trim();
  }

  // ───── Dashboard ─────

  Future<void> loadDashboard() async {
    _status = DataStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Load assigned line and contracts in parallel
      final results = await Future.wait([
        _repository.getAssignedLine(),
        _repository.listAssignedContracts(),
        _repository.listAssignedZones(),
      ]);

      _assignedLine = results[0] as GeographicLine?;
      _assignedZones = results[2] as List<Zone>;
      _contracts = _sortContracts(results[1] as List<Contract>, _assignedZones);

      // Load stats (uses visits and tasks queries)
      _stats = await _repository.getStats();
      _status = DataStatus.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _status = DataStatus.error;
    }

    notifyListeners();
  }

  // ───── Contracts ─────

  Future<void> loadContracts() async {
    _status = DataStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.listAssignedContracts(),
        _repository.listAssignedZones(),
        _repository.listLateContractIds().catchError((_) => <String>{}),
      ]);
      _assignedZones = results[1] as List<Zone>;
      _contracts = _sortContracts(results[0] as List<Contract>, _assignedZones);
      _lateContractIds = results[2] as Set<String>;
      _status = DataStatus.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _status = DataStatus.error;
    }

    notifyListeners();
  }

  /// Fetches payments for a single contract (read-only, RLS-safe RPC).
  Future<List<ContractPayment>> fetchContractPayments(String contractId) {
    return _repository.listContractPayments(contractId);
  }

  Future<void> selectContract(String contractId) async {
    try {
      _selectedContract = await _repository.getContract(contractId);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> requestContractStatusChange({
    required String contractId,
    required String requestedStatus,
  }) async {
    try {
      _isActionLoading = true;
      notifyListeners();

      await _repository.requestContractStatusChange(
        contractId: contractId,
        requestedStatus: requestedStatus,
      );

      _isActionLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isActionLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // ───── Visits ─────

  Future<void> loadVisits(String contractId) async {
    _status = DataStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _visits = await _repository.listVisits(contractId);
      _status = DataStatus.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _status = DataStatus.error;
    }

    notifyListeners();
  }

  Future<bool> updateVisitStatus({
    required String visitId,
    required String status,
  }) async {
    _isActionLoading = true;
    notifyListeners();

    try {
      final updated = await _repository.updateVisitStatus(
        visitId: visitId,
        status: status,
      );
      final index = _visits.indexWhere((v) => v.id == visitId);
      if (index >= 0) _visits[index] = updated;
      _selectedVisit = updated;
      _isActionLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isActionLoading = false;
      notifyListeners();
      return false;
    }
  }

  void selectVisit(Visit visit) {
    _selectedVisit = visit;
    notifyListeners();
  }

  // ───── Tasks ─────

  Future<void> loadTasks({required String contractId, String? visitId}) async {
    _status = DataStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _tasks = await _repository.listTasks(
        contractId: contractId,
        visitId: visitId,
      );
      _status = DataStatus.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _status = DataStatus.error;
    }

    notifyListeners();
  }

  Future<void> loadVisitTasksOverview(String contractId) async {
    try {
      final tasks = await _repository.listTasks(contractId: contractId);
      final grouped = <String, List<ContractTask>>{};

      for (final task in tasks) {
        if (task.visitId == null || task.visitId!.isEmpty) continue;
        grouped.putIfAbsent(task.visitId!, () => []).add(task);
      }

      _visitTasks = grouped;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  List<ContractTask> tasksForVisit(String visitId) =>
      _visitTasks[visitId] ?? [];

  Future<TaskExecution?> executeTask({
    required String taskId,
    required String visitId,
    String? notes,
    double? gpsLat,
    double? gpsLng,
  }) async {
    _isActionLoading = true;
    notifyListeners();

    try {
      final execution = await _repository.createTaskExecution(
        taskId: taskId,
        visitId: visitId,
        notes: notes,
        gpsLat: gpsLat,
        gpsLng: gpsLng,
      );
      _executions.insert(0, execution);

      // Update local task status
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index >= 0) {
        final old = _tasks[index];
        _tasks[index] = ContractTask(
          id: old.id,
          contractId: old.contractId,
          visitId: old.visitId,
          title: old.title,
          month: old.month,
          status: 'completed',
          createdAt: old.createdAt,
        );
      }

      _isActionLoading = false;
      notifyListeners();
      return execution;
    } catch (e) {
      _errorMessage = e.toString();
      _isActionLoading = false;
      notifyListeners();
      return null;
    }
  }

  // ───── Task Executions ─────

  Future<void> loadTaskExecutions(String visitId) async {
    try {
      _executions = await _repository.listTaskExecutions(visitId);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ───── Photos ─────

  Future<TaskPhoto?> uploadPhoto({
    required String executionId,
    required String filePath,
    required String photoType,
  }) async {
    _isActionLoading = true;
    notifyListeners();

    try {
      final photo = await _repository.uploadTaskPhoto(
        executionId: executionId,
        filePath: filePath,
        photoType: photoType,
      );
      _photos.add(photo);
      _isActionLoading = false;
      notifyListeners();
      return photo;
    } catch (e) {
      _errorMessage = e.toString();
      _isActionLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> loadPhotos(String executionId) async {
    try {
      _photos = await _repository.listTaskPhotos(executionId);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ───── Task Completion (Toggle) ─────

  bool get allTasksCompleted => _tasks.every((t) => t.isCompleted || t.isVerified);

  Future<bool> toggleTaskStatus(String taskId) async {
    _isActionLoading = true;
    notifyListeners();

    try {
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index < 0) {
        _isActionLoading = false;
        notifyListeners();
        return false;
      }

      final old = _tasks[index];
      final newStatus = old.isCompleted ? 'pending' : 'completed';

      if (old.isCompleted) {
        await _repository.unmarkTaskDone(taskId);
      } else {
        await _repository.markTaskDone(taskId);
      }

      _tasks[index] = ContractTask(
        id: old.id,
        contractId: old.contractId,
        visitId: old.visitId,
        title: old.title,
        month: old.month,
        status: newStatus,
        createdAt: old.createdAt,
      );

      _isActionLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isActionLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ───── Visit Completion ─────

  Future<bool> completeVisitWithDetails({
    required String visitId,
    required String summary,
    required List<String> photoPaths,
    double? gpsLat,
    double? gpsLng,
  }) async {
    _isActionLoading = true;
    notifyListeners();

    try {
      // Upload visit photos
      for (final path in photoPaths) {
        await _repository.uploadVisitPhoto(visitId: visitId, filePath: path);
      }

      final finalSummary = _sanitizeVisitSummary(summary);

      // Complete the visit
      final updated = await _repository.completeVisit(
        visitId: visitId,
        summary: finalSummary,
        gpsLat: gpsLat,
        gpsLng: gpsLng,
      );

      final index = _visits.indexWhere((v) => v.id == visitId);
      if (index >= 0) _visits[index] = updated;
      _selectedVisit = updated;

      _isActionLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isActionLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ───── Visit Photos ─────

  Future<void> loadVisitPhotos(String visitId) async {
    try {
      _visitPhotos = await _repository.listVisitPhotos(visitId);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadVisitComments(String visitId) async {
    try {
      _visitComments = await _repository.listVisitComments(visitId);
      if (kDebugMode) {
        debugPrint(
          '[Comments] loaded ${_visitComments.length} comments for visit $visitId',
        );
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[Comments] error loading: $e');
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadSupervisorNotes(String visitId) async {
    try {
      _supervisorNotes = await _repository.listSupervisorNotes(visitId);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> addSupervisorNote({
    required String visitId,
    required String contractId,
    required String content,
    required String visibility,
  }) async {
    try {
      _isActionLoading = true;
      notifyListeners();
      final note = await _repository.createSupervisorNote(
        visitId: visitId,
        contractId: contractId,
        content: content,
        visibility: visibility,
      );
      _supervisorNotes.insert(0, note);
      _isActionLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isActionLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateSupervisorNote({
    required String noteId,
    required String content,
    required String visibility,
  }) async {
    try {
      _isActionLoading = true;
      notifyListeners();
      final updatedNote = await _repository.updateSupervisorNote(
        noteId: noteId,
        content: content,
        visibility: visibility,
      );
      final index = _supervisorNotes.indexWhere((n) => n.id == noteId);
      if (index >= 0) {
        _supervisorNotes[index] = updatedNote;
      }
      _isActionLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isActionLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteSupervisorNote(String noteId) async {
    try {
      _isActionLoading = true;
      notifyListeners();
      await _repository.deleteSupervisorNote(noteId);
      _supervisorNotes.removeWhere((n) => n.id == noteId);
      _isActionLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isActionLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // ───── Standalone Tasks ─────

  Future<void> loadStandaloneTasks() async {
    try {
      _isLoadingStandaloneTasks = true;
      notifyListeners();
      _standaloneTasks = await _repository.listAssignedStandaloneTasks();

      // Ensure we have contract details (code) for any tasks that reference a
      // contract that is not present in the current _contracts list. This
      // prevents UI showing raw ids or placeholders when contract codes exist
      // but weren't part of the assigned contracts list.
      final missingContractIds = _standaloneTasks
          .map((t) => t.contractId)
          .where((id) => id != null && id.isNotEmpty)
          .map((id) => id!)
          .toSet()
          .difference(_contracts.map((c) => c.id).toSet());

      for (final missing in missingContractIds) {
        try {
          final fetched = await _repository.getContract(missing);
          // Avoid duplicates
          if (!_contracts.any((c) => c.id == fetched.id)) {
            _contracts.add(fetched);
          }
        } catch (_) {
          // Ignore errors — contract might legitimately not be accessible.
        }
      }
      _isLoadingStandaloneTasks = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoadingStandaloneTasks = false;
      notifyListeners();
    }
  }

  Future<StandaloneTask> updateStandaloneTaskStatus({
    required String taskId,
    required String status,
    String? supervisorReport,
  }) async {
    try {
      _isActionLoading = true;
      notifyListeners();

      final updatedTask = await _repository.updateStandaloneTaskStatus(
        taskId: taskId,
        status: status,
        supervisorReport: supervisorReport,
      );

      final index = _standaloneTasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _standaloneTasks[index] = updatedTask;
      }

      _isActionLoading = false;
      notifyListeners();
      return updatedTask;
    } catch (e) {
      _errorMessage = e.toString();
      _isActionLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // ───── Utilities ─────

  List<Contract> _sortContracts(List<Contract> contracts, List<Zone> zones) {
    final zoneOrder = {for (final z in zones) z.id: z.sortOrder};
    return List<Contract>.from(contracts)
      ..sort((a, b) {
        final za = zoneOrder[a.zoneId] ?? 999999;
        final zb = zoneOrder[b.zoneId] ?? 999999;
        if (za != zb) return za.compareTo(zb);
        final ba = int.tryParse(a.blockNumber?.trim() ?? '') ?? 999999;
        final bb = int.tryParse(b.blockNumber?.trim() ?? '') ?? 999999;
        return ba.compareTo(bb);
      });
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
