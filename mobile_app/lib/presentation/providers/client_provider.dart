import 'package:flutter/foundation.dart';
import 'package:ensdim_landscape/domain/entities/client_comment.dart';
import 'package:ensdim_landscape/domain/entities/contract.dart';
import 'package:ensdim_landscape/domain/entities/contract_payment.dart';
import 'package:ensdim_landscape/domain/entities/contract_task.dart';
import 'package:ensdim_landscape/domain/entities/standalone_task.dart';
import 'package:ensdim_landscape/domain/entities/task_execution.dart';
import 'package:ensdim_landscape/domain/entities/task_photo.dart';
import 'package:ensdim_landscape/domain/entities/visit.dart';
import 'package:ensdim_landscape/domain/entities/visit_photo.dart';
import 'package:ensdim_landscape/domain/repositories/client_repository.dart';

enum ClientDataStatus { initial, loading, loaded, error }

class ClientProvider extends ChangeNotifier {
  final ClientRepository _repository;

  ClientProvider(this._repository);

  ClientDataStatus _status = ClientDataStatus.initial;
  ClientDataStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<Contract> _contracts = [];
  List<Contract> get contracts => _contracts;

  Contract? _selectedContract;
  Contract? get selectedContract => _selectedContract;

  final Map<String, List<ContractPayment>> _paymentsByContract = {};
  final Map<String, List<Visit>> _visitsByContract = {};
  final Map<String, List<ContractTask>> _tasksByContract = {};
  final Map<String, List<StandaloneTask>> _standaloneTasksByContract = {};
  final Map<String, List<VisitPhoto>> _photosByVisit = {};
  final Map<String, List<TaskExecution>> _executionsByVisit = {};
  final Map<String, List<TaskPhoto>> _taskPhotosByVisit = {};
  final Map<String, List<ClientComment>> _commentsByVisit = {};

  List<ContractPayment> paymentsFor(String contractId) =>
      _paymentsByContract[contractId] ?? const [];

  List<Visit> visitsFor(String contractId) =>
      _visitsByContract[contractId] ?? const [];

  List<ContractTask> tasksFor(String contractId) =>
      _tasksByContract[contractId] ?? const [];

  List<StandaloneTask> standaloneTasksFor(String contractId) =>
      _standaloneTasksByContract[contractId] ?? const [];

  List<VisitPhoto> visitPhotosFor(String visitId) =>
      _photosByVisit[visitId] ?? const [];

  List<TaskExecution> taskExecutionsForVisit(String visitId) =>
      _executionsByVisit[visitId] ?? const [];

  List<TaskPhoto> taskPhotosForVisit(String visitId) =>
      _taskPhotosByVisit[visitId] ?? const [];

  List<ClientComment> visitCommentsFor(String visitId) =>
      _commentsByVisit[visitId] ?? const [];

  double get totalContractsValue =>
      _contracts.fold(0.0, (sum, c) => sum + c.totalValue);

  double get totalPaid {
    var total = 0.0;
    for (final list in _paymentsByContract.values) {
      total += list
          .where((p) => p.gatewayStatus == 'paid' ||
              (p.gatewayStatus == null && p.dueDate == null))
          .fold(0.0, (sum, p) => sum + p.amount);
    }
    return total;
  }

  int get totalVisitsCount {
    var count = 0;
    for (final list in _visitsByContract.values) {
      count += list.length;
    }
    return count;
  }

  int get completedVisitsCount {
    var count = 0;
    for (final list in _visitsByContract.values) {
      count += list.where((v) => v.status == 'completed').length;
    }
    return count;
  }

  Future<void> loadDashboard() async {
    _status = ClientDataStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _contracts = await _repository.listMyContracts();

      if (_contracts.isNotEmpty) {
        _selectedContract = _selectedContract ?? _contracts.first;
        await _loadContractRelatedData(_selectedContract!.id);
      }

      _status = ClientDataStatus.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _status = ClientDataStatus.error;
    }

    notifyListeners();
  }

  Future<void> selectContract(Contract contract) async {
    _selectedContract = contract;
    notifyListeners();

    final alreadyLoaded =
        _paymentsByContract.containsKey(contract.id) &&
        _visitsByContract.containsKey(contract.id) &&
        _tasksByContract.containsKey(contract.id) &&
        _standaloneTasksByContract.containsKey(contract.id);

    if (!alreadyLoaded) {
      await _loadContractRelatedData(contract.id);
      notifyListeners();
    }
  }

  Future<void> refreshSelectedContract() async {
    final selected = _selectedContract;
    if (selected == null) {
      await loadDashboard();
      return;
    }

    _status = ClientDataStatus.loading;
    notifyListeners();

    try {
      await _loadContractRelatedData(selected.id, forceReload: true);
      _status = ClientDataStatus.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _status = ClientDataStatus.error;
    }

    notifyListeners();
  }

  Future<bool> updateContractGuardInfo({
    required String contractId,
    required String guardName,
    required String guardPhone,
  }) async {
    try {
      final updatedContract = await _repository.updateContractGuardInfo(
        contractId: contractId,
        guardName: guardName,
        guardPhone: guardPhone,
      );

      _contracts = _contracts
          .map(
            (contract) =>
                contract.id == updatedContract.id ? updatedContract : contract,
          )
          .toList(growable: false);

      if (_selectedContract?.id == updatedContract.id) {
        _selectedContract = updatedContract;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<VisitPhoto>> loadVisitPhotos(
    String visitId, {
    bool forceReload = false,
  }) async {
    final cached = _photosByVisit[visitId];
    if (!forceReload && cached != null && cached.isNotEmpty) {
      return cached;
    }

    final photos = await _repository.listVisitPhotos(visitId);
    _photosByVisit[visitId] = photos;
    notifyListeners();
    return photos;
  }

  Future<void> loadVisitTaskDetails(
    String visitId, {
    bool forceReload = false,
    List<String> taskIds = const [],
  }) async {
    final hasExecutions = (_executionsByVisit[visitId] ?? const []).isNotEmpty;
    final hasPhotos = (_taskPhotosByVisit[visitId] ?? const []).isNotEmpty;
    if (!forceReload && (hasExecutions || hasPhotos)) return;

    final byVisit = await _repository.listVisitTaskExecutions(visitId);
    final byTasks = taskIds.isEmpty
        ? const <TaskExecution>[]
        : await _repository.listTaskExecutionsByTaskIds(taskIds);

    final mergedById = <String, TaskExecution>{
      for (final e in byVisit) e.id: e,
      for (final e in byTasks) e.id: e,
    };
    final executions =
        mergedById.values
            .where((e) => e.visitId == null || e.visitId == visitId)
            .toList(growable: false)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _executionsByVisit[visitId] = executions;

    final executionIds = executions.map((e) => e.id).toList(growable: false);
    final photos = await _repository.listTaskPhotosByExecutionIds(executionIds);
    _taskPhotosByVisit[visitId] = photos;

    notifyListeners();
  }

  Future<List<ClientComment>> loadVisitComments(
    String visitId, {
    bool forceReload = false,
  }) async {
    final cached = _commentsByVisit[visitId];
    if (!forceReload && cached != null) {
      return cached;
    }

    final comments = await _repository.listVisitComments(visitId);
    _commentsByVisit[visitId] = comments;
    notifyListeners();
    return comments;
  }

  Future<ClientComment?> submitVisitComment({
    required String contractId,
    required String visitId,
    required String comment,
    String? attachmentFilePath,
  }) async {
    final trimmed = comment.trim();
    if (trimmed.isEmpty &&
        (attachmentFilePath == null || attachmentFilePath.trim().isEmpty)) {
      return null;
    }

    try {
      final created = await _repository.createVisitComment(
        contractId: contractId,
        visitId: visitId,
        comment: trimmed,
        attachmentFilePath: attachmentFilePath,
      );

      final current = List<ClientComment>.from(_commentsByVisit[visitId] ?? []);
      current.insert(0, created);
      _commentsByVisit[visitId] = current;
      notifyListeners();
      return created;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> _loadContractRelatedData(
    String contractId, {
    bool forceReload = false,
  }) async {
    if (!forceReload &&
        _paymentsByContract.containsKey(contractId) &&
        _visitsByContract.containsKey(contractId) &&
        _tasksByContract.containsKey(contractId) &&
        _standaloneTasksByContract.containsKey(contractId)) {
      return;
    }

    final results = await Future.wait([
      _repository.listContractPayments(contractId),
      _repository.listContractVisits(contractId),
      _repository.listContractTasks(contractId),
      _repository.listStandaloneTasksByContract(contractId),
    ]);

    _paymentsByContract[contractId] = results[0] as List<ContractPayment>;
    _visitsByContract[contractId] = results[1] as List<Visit>;
    _tasksByContract[contractId] = results[2] as List<ContractTask>;
    _standaloneTasksByContract[contractId] = results[3] as List<StandaloneTask>;
  }
}
