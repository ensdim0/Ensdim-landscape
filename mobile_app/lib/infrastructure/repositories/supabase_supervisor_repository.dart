import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ensdim_landscape/domain/entities/contract.dart';
import 'package:ensdim_landscape/domain/entities/contract_payment.dart';
import 'package:ensdim_landscape/domain/entities/client_comment.dart';
import 'package:ensdim_landscape/domain/entities/contract_task.dart';
import 'package:ensdim_landscape/domain/entities/geographic_line.dart';
import 'package:ensdim_landscape/domain/entities/supervisor_note.dart';
import 'package:ensdim_landscape/domain/entities/task_execution.dart';
import 'package:ensdim_landscape/domain/entities/task_photo.dart';
import 'package:ensdim_landscape/domain/entities/visit.dart';
import 'package:ensdim_landscape/domain/entities/visit_photo.dart';
import 'package:ensdim_landscape/domain/entities/zone.dart';
import 'package:ensdim_landscape/domain/entities/standalone_task.dart';
import 'package:ensdim_landscape/domain/repositories/supervisor_repository.dart';

class SupabaseSupervisorRepository implements SupervisorRepository {
  final SupabaseClient _client;

  SupabaseSupervisorRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  // â”€â”€â”€â”€â”€ Helpers â”€â”€â”€â”€â”€

  Future<String?> _getAssignedLineId() async {
    final profile = await _client
        .from('users')
        .select('assigned_line_id')
        .eq('id', _userId)
        .single();
    return profile['assigned_line_id'] as String?;
  }

  Future<Map<String, String>> _loadZoneNamesById(Set<String> zoneIds) async {
    if (zoneIds.isEmpty) return const {};

    final rows = await _client
        .from('zones')
        .select('id, name')
        .inFilter('id', zoneIds.toList());

    final zoneNames = <String, String>{};
    for (final row in rows as List) {
      final zoneId = row['id']?.toString().trim() ?? '';
      final zoneName = row['name']?.toString().trim() ?? '';
      if (zoneId.isNotEmpty && zoneName.isNotEmpty) {
        zoneNames[zoneId] = zoneName;
      }
    }

    return zoneNames;
  }

  Future<Map<String, String>> _loadLineNamesById(Set<String> lineIds) async {
    if (lineIds.isEmpty) return const {};

    final rows = await _client
        .from('geographic_lines')
        .select('id, name')
        .inFilter('id', lineIds.toList());

    final lineNames = <String, String>{};
    for (final row in rows as List) {
      final lineId = row['id']?.toString().trim() ?? '';
      final lineName = row['name']?.toString().trim() ?? '';
      if (lineId.isNotEmpty && lineName.isNotEmpty) {
        lineNames[lineId] = lineName;
      }
    }

    return lineNames;
  }

  Future<String> _resolveVisitPhotoUrl(String photoPath) async {
    if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
      return photoPath;
    }

    try {
      return await _client.storage
          .from('task-photos')
          .createSignedUrl(photoPath, 3600);
    } catch (_) {
      return _client.storage.from('task-photos').getPublicUrl(photoPath);
    }
  }

  String _sanitizeVisitSummary(String input) {
    final cleanedLines = input
        .replaceAll(RegExp(r'\b(?:https?|ftp)://\S+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bwww\.\S+', caseSensitive: false), '')
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceAll(RegExp(r'\s{2,}'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return cleanedLines.join('\n').trim();
  }

  // â”€â”€â”€â”€â”€ Geographic Line â”€â”€â”€â”€â”€

  @override
  Future<GeographicLine?> getAssignedLine() async {
    final lineId = await _getAssignedLineId();
    if (lineId == null) return null;

    final row = await _client
        .from('geographic_lines')
        .select()
        .eq('id', lineId)
        .single();

    return _mapLine(row);
  }

  // â”€â”€â”€â”€â”€ Contracts â”€â”€â”€â”€â”€

  @override
  Future<List<Contract>> listAssignedContracts() async {
    final lineId = await _getAssignedLineId();
    if (lineId == null) return [];

    // Surface only active and pending contracts in supervisor flows.
    final rows = await _client
        .from('contracts_view')
        .select('*, users!user_id(phone)')
        .eq('line_id', lineId)
        .inFilter('status', ['active', 'pending'])
        .order('created_at', ascending: false);

    final contractRows = rows as List;
    final zoneIds = contractRows
        .map((row) => row['zone_id']?.toString().trim() ?? '')
        .where((zoneId) => zoneId.isNotEmpty)
        .toSet();
    final lineIds = contractRows
        .map((row) => row['line_id']?.toString().trim() ?? '')
        .where((lineId) => lineId.isNotEmpty)
        .toSet();

    final zoneNames = await _loadZoneNamesById(zoneIds);
    final lineNames = await _loadLineNamesById(lineIds);

    return contractRows.map((r) {
      final zoneId = r['zone_id']?.toString().trim() ?? '';
      final lineId = r['line_id']?.toString().trim() ?? '';
      return _mapContract(
        r,
        zoneName: zoneNames[zoneId],
        lineName: lineNames[lineId],
      );
    }).toList();
  }

  @override
  Future<Set<String>> listLateContractIds() async {
    final rows = await _client.rpc('get_late_contract_ids_for_supervisor');
    return (rows as List)
        .map((r) => r['contract_id']?.toString())
        .whereType<String>()
        .toSet();
  }

  @override
  Future<List<ContractPayment>> listContractPayments(String contractId) async {
    final rows = await _client.rpc(
      'get_contract_payments_for_supervisor',
      params: {'p_contract_id': contractId},
    );
    return (rows as List).map((row) {
      final r = row as Map<String, dynamic>;
      return ContractPayment(
        id: r['id'] as String,
        contractId: contractId,
        amount: (r['amount'] as num?)?.toDouble() ?? 0.0,
        paymentMethod: r['payment_method']?.toString() ?? 'cash',
        paymentDate: r['payment_date']?.toString() ?? '',
        notes: r['notes']?.toString(),
        createdAt: r['created_at']?.toString() ?? '',
        dueDate: r['due_date']?.toString(),
        gatewayStatus: r['gateway_status']?.toString(),
      );
    }).toList();
  }

  @override
  Future<List<Zone>> listAssignedZones() async {
    final lineId = await _getAssignedLineId();
    if (lineId == null) return [];

    final rows = await _client
        .from('zones')
        .select('id, line_id, name, is_active, sort_order, created_at')
        .eq('line_id', lineId)
        .eq('is_active', true)
        .order('sort_order')
        .order('name');

    return (rows as List).map((r) => _mapZone(r)).toList();
  }

  @override
  Future<Contract> getContract(String contractId) async {
    final row = await _client
        .from('contracts_view')
        .select('*, users!user_id(phone)')
        .eq('id', contractId)
        .single();
    final contractRow = Map<String, dynamic>.from(row as Map);
    final zoneId = contractRow['zone_id']?.toString().trim() ?? '';
    final lineId = contractRow['line_id']?.toString().trim() ?? '';
    final zoneNames = await _loadZoneNamesById({if (zoneId.isNotEmpty) zoneId});
    final lineNames = await _loadLineNamesById({if (lineId.isNotEmpty) lineId});

    return _mapContract(
      contractRow,
      zoneName: zoneNames[zoneId],
      lineName: lineNames[lineId],
    );
  }

  // â”€â”€â”€â”€â”€ Visits â”€â”€â”€â”€â”€

  @override
  Future<List<Visit>> listVisits(String contractId) async {
    final rows = await _client
        .from('visits')
        .select()
        .eq('contract_id', contractId)
        .order('visit_date', ascending: false);

    return (rows as List).map((r) => _mapVisit(r)).toList();
  }

  @override
  Future<Visit> getVisit(String visitId) async {
    final row = await _client
        .from('visits')
        .select()
        .eq('id', visitId)
        .single();

    return _mapVisit(row);
  }

  @override
  Future<Visit> updateVisitStatus({
    required String visitId,
    required String status,
  }) async {
    final row = await _client
        .from('visits')
        .update({'status': status})
        .eq('id', visitId)
        .select()
        .single();

    return _mapVisit(row);
  }

  @override
  Future<Visit> completeVisit({
    required String visitId,
    required String summary,
    double? gpsLat,
    double? gpsLng,
  }) async {
    final sanitizedSummary = _sanitizeVisitSummary(summary);
    final row = await _client
        .from('visits')
        .update({
          'status': 'completed',
          'summary': sanitizedSummary,
          'gps_lat': gpsLat,
          'gps_lng': gpsLng,
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', visitId)
        .select()
        .single();

    return _mapVisit(row);
  }

  @override
  Future<void> markTaskDone(String taskId) async {
    await _client
        .from('contract_tasks')
        .update({'status': 'completed'})
        .eq('id', taskId);
  }

  @override
  Future<void> unmarkTaskDone(String taskId) async {
    await _client
        .from('contract_tasks')
        .update({'status': 'pending'})
        .eq('id', taskId);
  }

  @override
  Future<VisitPhoto> uploadVisitPhoto({
    required String visitId,
    required String filePath,
  }) async {
    final file = File(filePath);
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
    final storagePath = 'visit-photos/$visitId/$fileName';

    await _client.storage.from('task-photos').upload(storagePath, file);

    final row = await _client
        .from('visit_photos')
        .insert({'visit_id': visitId, 'photo_path': storagePath})
        .select()
        .single();

    return _mapVisitPhoto(row);
  }

  @override
  Future<List<VisitPhoto>> listVisitPhotos(String visitId) async {
    final rows = await _client
        .from('visit_photos')
        .select()
        .eq('visit_id', visitId)
        .order('created_at');

    return Future.wait((rows as List).map((r) => _mapVisitPhoto(r)));
  }

  @override
  Future<List<ClientComment>> listVisitComments(String visitId) async {
    final rows = await _client
        .from('client_comments')
        .select(
          'id, contract_id, visit_id, comment, attachment_path, created_at, author_name, author_user_id',
        )
        .eq('visit_id', visitId)
        .order('created_at', ascending: false);

    return (rows as List)
        .whereType<Map>()
        .map((row) => _mapClientComment(row))
        .where((comment) => comment.id.isNotEmpty)
        .toList(growable: false);
  }

  // â”€â”€â”€â”€â”€ Tasks â”€â”€â”€â”€â”€

  @override
  Future<List<ContractTask>> listTasks({
    required String contractId,
    String? visitId,
  }) async {
    var query = _client
        .from('contract_tasks')
        .select()
        .eq('contract_id', contractId);

    if (visitId != null) {
      query = query.eq('visit_id', visitId);
    }

    final rows = await query.order('month');
    return (rows as List).map((r) => _mapTask(r)).toList();
  }

  // â”€â”€â”€â”€â”€ Task Executions â”€â”€â”€â”€â”€

  @override
  Future<TaskExecution> createTaskExecution({
    required String taskId,
    required String visitId,
    String? notes,
    double? gpsLat,
    double? gpsLng,
  }) async {
    final row = await _client
        .from('task_executions')
        .insert({
          'task_id': taskId,
          'supervisor_id': _userId,
          'visit_id': visitId,
          'notes': notes,
          'status': 'completed',
          'gps_lat': gpsLat,
          'gps_lng': gpsLng,
        })
        .select()
        .single();

    // Update the contract_task status too
    await _client
        .from('contract_tasks')
        .update({'status': 'completed'})
        .eq('id', taskId);

    return _mapExecution(row);
  }

  @override
  Future<List<TaskExecution>> listTaskExecutions(String visitId) async {
    final rows = await _client
        .from('task_executions')
        .select()
        .eq('visit_id', visitId)
        .order('created_at', ascending: false);

    return (rows as List).map((r) => _mapExecution(r)).toList();
  }

  // â”€â”€â”€â”€â”€ Photos â”€â”€â”€â”€â”€

  @override
  Future<TaskPhoto> uploadTaskPhoto({
    required String executionId,
    required String filePath,
    required String photoType,
  }) async {
    final file = File(filePath);
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
    final storagePath = 'task-photos/$executionId/$fileName';

    await _client.storage.from('task-photos').upload(storagePath, file);

    final row = await _client
        .from('task_photos')
        .insert({
          'execution_id': executionId,
          'photo_path': storagePath,
          'photo_type': photoType,
        })
        .select()
        .single();

    return _mapPhoto(row);
  }

  @override
  Future<List<TaskPhoto>> listTaskPhotos(String executionId) async {
    final rows = await _client
        .from('task_photos')
        .select()
        .eq('execution_id', executionId)
        .order('created_at');

    return (rows as List).map((r) => _mapPhoto(r)).toList();
  }

  // â”€â”€â”€â”€â”€ Stats â”€â”€â”€â”€â”€

  @override
  Future<SupervisorStats> getStats() async {
    final contracts = await listAssignedContracts();
    final activeContracts = contracts.where((c) => c.status == 'active').length;

    if (contracts.isEmpty) {
      return const SupervisorStats(
        totalContracts: 0,
        activeContracts: 0,
        totalVisits: 0,
        completedVisits: 0,
        pendingTasks: 0,
        completedTasks: 0,
      );
    }

    final contractIds = contracts.map((c) => c.id).toList();

    final visits = await _client
        .from('visits')
        .select('id, status, completed_at')
        .inFilter('contract_id', contractIds);

    final visitsList = visits as List;
    final totalVisits = visitsList.length;
    final completedVisits = visitsList
        .where((v) => v['status'] == 'completed')
        .length;

    final now = DateTime.now();
    bool isToday(String? iso) {
      if (iso == null) return false;
      final dt = DateTime.tryParse(iso)?.toLocal();
      if (dt == null) return false;
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }

    final visitsCompletedToday = visitsList
        .where(
          (v) =>
              v['status'] == 'completed' &&
              isToday(v['completed_at']?.toString()),
        )
        .length;

    final tasks = await _client
        .from('contract_tasks')
        .select('id, status')
        .inFilter('contract_id', contractIds);
    final tasksList = tasks as List;
    final pendingTasks = tasksList
        .where((t) => t['status'] == 'pending')
        .length;
    final completedTasks = tasksList
        .where((t) => t['status'] != 'pending')
        .length;

    final standaloneTasks = await _client
        .from('standalone_tasks')
        .select('id, status, task_date')
        .eq('supervisor_id', _userId);
    final standaloneTasksToday = (standaloneTasks as List)
        .where((t) => isToday(t['task_date']?.toString()))
        .toList();
    final standaloneTasksTotalToday = standaloneTasksToday.length;
    final standaloneTasksCompletedToday = standaloneTasksToday
        .where((t) => t['status'] == 'completed')
        .length;

    return SupervisorStats(
      totalContracts: contracts.length,
      activeContracts: activeContracts,
      totalVisits: totalVisits,
      completedVisits: completedVisits,
      pendingTasks: pendingTasks,
      completedTasks: completedTasks,
      visitsCompletedToday: visitsCompletedToday,
      standaloneTasksTotalToday: standaloneTasksTotalToday,
      standaloneTasksCompletedToday: standaloneTasksCompletedToday,
    );
  }

  @override
  @override
  Future<void> requestContractStatusChange({
    required String contractId,
    required String requestedStatus,
  }) async {
    await _client.rpc(
      'create_contract_status_request',
      params: {
        'p_contract_id': contractId,
        'p_requested_status': requestedStatus,
      },
    );
  }

  // â"€â"€â"€â"€â"€ Supervisor Notes â"€â"€â"€â"€â"€

  @override
  Future<List<SupervisorNote>> listSupervisorNotes(String visitId) async {
    final rows = await _client
        .from('supervisor_notes')
        .select()
        .eq('visit_id', visitId)
        .order('created_at', ascending: false);

    return (rows as List).map((r) => _mapSupervisorNote(r)).toList();
  }

  @override
  Future<SupervisorNote> createSupervisorNote({
    required String visitId,
    required String contractId,
    required String content,
    required String visibility,
  }) async {
    final row = await _client
        .from('supervisor_notes')
        .insert({
          'visit_id': visitId,
          'contract_id': contractId,
          'content': content,
          'visibility': visibility,
        })
        .select()
        .single();

    return _mapSupervisorNote(row);
  }

  @override
  Future<SupervisorNote> updateSupervisorNote({
    required String noteId,
    required String content,
    required String visibility,
  }) async {
    final row = await _client
        .from('supervisor_notes')
        .update({
          'content': content,
          'visibility': visibility,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', noteId)
        .select()
        .single();

    return _mapSupervisorNote(row);
  }

  @override
  Future<void> deleteSupervisorNote(String noteId) async {
    await _client.from('supervisor_notes').delete().eq('id', noteId);
  }

  @override
  Future<List<StandaloneTask>> listAssignedStandaloneTasks() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final response = await _client
        .from('standalone_tasks')
        .select()
        .eq('supervisor_id', user.id)
        .order('task_date', ascending: true);

    final rows = (response as List).whereType<Map>().toList();

    final zoneIds = rows
        .map((r) => r['zone_id']?.toString().trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final lineIds = rows
        .map((r) => r['line_id']?.toString().trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final zoneNames = await _loadZoneNamesById(zoneIds);
    final lineNames = await _loadLineNamesById(lineIds);

    return rows.map((row) {
      final zoneId = row['zone_id']?.toString().trim() ?? '';
      final lineId = row['line_id']?.toString().trim() ?? '';
      final enriched = Map<String, dynamic>.from(row);
      if (zoneNames.containsKey(zoneId)) {
        enriched['zone_name'] = zoneNames[zoneId];
      }
      if (lineNames.containsKey(lineId)) {
        enriched['line_name'] = lineNames[lineId];
      }
      return StandaloneTask.fromJson(enriched);
    }).toList();
  }

  @override
  Future<StandaloneTask> getStandaloneTask(String taskId) async {
    if (taskId.trim().isEmpty) {
      throw Exception('Invalid taskId');
    }
    final response = await _client
        .from('standalone_tasks')
        .select()
        .eq('id', taskId)
        .single();

    final row = Map<String, dynamic>.from(response as Map);
    final zoneId = row['zone_id']?.toString().trim() ?? '';
    final lineId = row['line_id']?.toString().trim() ?? '';
    final zoneNames = await _loadZoneNamesById({if (zoneId.isNotEmpty) zoneId});
    final lineNames = await _loadLineNamesById({if (lineId.isNotEmpty) lineId});

    if (zoneNames.containsKey(zoneId)) row['zone_name'] = zoneNames[zoneId];
    if (lineNames.containsKey(lineId)) row['line_name'] = lineNames[lineId];

    return StandaloneTask.fromJson(row);
  }

  @override
  Future<StandaloneTask> updateStandaloneTaskStatus({
    required String taskId,
    required String status,
    String? supervisorReport,
  }) async {
    if (taskId.trim().isEmpty) {
      throw Exception('Invalid taskId');
    }
    final updates = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (supervisorReport != null) {
      updates['supervisor_report'] = supervisorReport;
    }

    final response = await _client
        .from('standalone_tasks')
        .update(updates)
        .eq('id', taskId)
        .eq('supervisor_id', _userId)
        .select()
        .single();

    return StandaloneTask.fromJson(response);
  } // â”€â”€â”€â”€â”€ Mappers â”€â”€â”€â”€â”€

  GeographicLine _mapLine(Map<String, dynamic> row) => GeographicLine(
    id: row['id'] as String,
    name: row['name'] as String,
    lineType: row['line_type'] as String? ?? '',
    status: (row['is_active'] as bool? ?? true) ? 'active' : 'inactive',
    phoneNumber: row['phone_number'] as String?,
    carNumber: row['car_number'] as String?,
    createdAt: row['created_at']?.toString() ?? '',
  );

  Contract _mapContract(
    Map<String, dynamic> row, {
    String? zoneName,
    String? lineName,
  }) => Contract(
    id: row['id'] as String,
    code: row['code'] as String? ?? '',
    zoneId: row['zone_id'] as String?,
    zoneName: zoneName,
    lineName: lineName,
    lineId: row['line_id'] as String?,
    status: row['status'] as String? ?? 'active',
    startDate: row['start_date']?.toString() ?? '',
    endDate: row['end_date']?.toString() ?? '',
    totalValue: (row['total_value'] as num?)?.toDouble() ?? 0.0,
    clientName: row['client_name'] as String?,
    clientPhone:
        (row['client_phone'] ??
                row['phone'] ??
                (row['users'] != null ? (row['users'] as Map)['phone'] : null))
            as String?,
    contractUserName: row['contract_user_name'] as String?,
    contractUserPhone: row['contract_user_phone'] as String?,
    addressDetails: row['address_details'] as String?,
    palmInfo: ContractPalmInfo.fromJson(row['palm_info']),
    blockNumber: row['block_number'] as String?,
    street: row['street'] as String?,
    avenue: row['avenue'] as String?,
    house: row['house'] as String?,
    kuwaitFinderUrl: row['kuwait_finder_url'] as String?,
    contractImageUrl: row['contract_image_url'] as String?,
    terms: _mapContractTerms(row['terms']),
    createdAt: row['created_at']?.toString() ?? '',
  );

  List<ContractTerm> _mapContractTerms(dynamic rawTerms) {
    if (rawTerms is! List) return const [];

    return rawTerms.whereType<Map>().map((rawTerm) {
      final activationOrder =
          (rawTerm['activationOrder'] as num?)?.toInt() ??
          (rawTerm['activation_order'] as num?)?.toInt() ??
          0;
      final visitsRaw = rawTerm['visits'];
      final visits = visitsRaw is List
          ? visitsRaw.whereType<Map>().map((rawVisit) {
              return ContractTermVisit(
                id: rawVisit['id']?.toString(),
                description: rawVisit['description']?.toString() ?? '',
                isExcluded: rawVisit['isExcluded'] as bool? ?? false,
              );
            }).toList()
          : const <ContractTermVisit>[];

      return ContractTerm(
        id: rawTerm['id']?.toString(),
        content: rawTerm['content']?.toString() ?? '',
        isExcluded: rawTerm['isExcluded'] as bool? ?? false,
        activationOrder: activationOrder,
        visits: visits,
      );
    }).toList();
  }

  Visit _mapVisit(Map<String, dynamic> row) => Visit(
    id: row['id'] as String,
    contractId: row['contract_id'] as String,
    contractItemId: row['contract_item_id'] as String?,
    title: row['title'] as String?,
    description: row['description'] as String?,
    visitDate: row['visit_date']?.toString() ?? '',
    notes: row['notes'] as String?,
    status: row['status'] as String? ?? 'planned',
    summary: row['summary'] as String?,
    gpsLat: (row['gps_lat'] as num?)?.toDouble(),
    gpsLng: (row['gps_lng'] as num?)?.toDouble(),
    completedAt: row['completed_at']?.toString(),
    createdAt: row['created_at']?.toString() ?? '',
  );

  ContractTask _mapTask(Map<String, dynamic> row) => ContractTask(
    id: row['id'] as String,
    contractId: row['contract_id'] as String,
    visitId: row['visit_id'] as String?,
    title: row['title'] as String,
    month: (row['month'] as num?)?.toInt() ?? 0,
    status: row['status'] as String? ?? 'pending',
    createdAt: row['created_at']?.toString() ?? '',
  );

  ClientComment _mapClientComment(Map<dynamic, dynamic> row) => ClientComment(
    id: row['id']?.toString() ?? '',
    contractId: row['contract_id']?.toString() ?? '',
    visitId: row['visit_id']?.toString() ?? '',
    comment: row['comment']?.toString() ?? '',
    authorName: row['author_name']?.toString(),
    authorUserId: row['author_user_id']?.toString(),
    attachmentPath: row['attachment_path']?.toString(),
    createdAt: row['created_at']?.toString() ?? '',
  );

  TaskExecution _mapExecution(Map<String, dynamic> row) => TaskExecution(
    id: row['id'] as String,
    taskId: row['task_id'] as String,
    supervisorId: row['supervisor_id'] as String,
    visitId: row['visit_id'] as String?,
    notes: row['notes'] as String?,
    status: row['status'] as String? ?? 'completed',
    gpsLat: (row['gps_lat'] as num?)?.toDouble(),
    gpsLng: (row['gps_lng'] as num?)?.toDouble(),
    createdAt: row['created_at']?.toString() ?? '',
  );

  TaskPhoto _mapPhoto(Map<String, dynamic> row) => TaskPhoto(
    id: row['id'] as String,
    executionId: row['execution_id'] as String,
    photoPath: row['photo_path'] as String,
    photoType: row['photo_type'] as String? ?? 'before',
    createdAt: row['created_at']?.toString() ?? '',
  );

  SupervisorNote _mapSupervisorNote(Map<String, dynamic> row) => SupervisorNote(
    id: row['id'] as String? ?? '',
    visitId: row['visit_id'] as String? ?? '',
    contractId: row['contract_id'] as String? ?? '',
    content: row['content'] as String? ?? '',
    visibility: row['visibility'] as String? ?? 'supervisors_only',
    createdBy: row['created_by'] as String?,
    createdAt: row['created_at']?.toString() ?? '',
    updatedAt: row['updated_at']?.toString() ?? '',
  );

  Zone _mapZone(Map<String, dynamic> row) => Zone(
    id: row['id'] as String,
    lineId: row['line_id'] as String,
    name: row['name'] as String? ?? '',
    isActive: row['is_active'] as bool? ?? true,
    sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
    createdAt: row['created_at']?.toString() ?? '',
  );

  Future<VisitPhoto> _mapVisitPhoto(Map<String, dynamic> row) async =>
      VisitPhoto(
        id: row['id'] as String,
        visitId: row['visit_id'] as String,
        photoPath: await _resolveVisitPhotoUrl(row['photo_path'] as String),
        createdAt: row['created_at']?.toString() ?? '',
      );
}
