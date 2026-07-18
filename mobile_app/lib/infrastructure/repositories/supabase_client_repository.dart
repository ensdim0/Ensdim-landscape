import 'dart:io';

import 'package:bustan_amari/core/errors/app_exception.dart';
import 'package:bustan_amari/core/l10n/app_localizations.dart';
import 'package:bustan_amari/domain/entities/contract.dart';
import 'package:bustan_amari/domain/entities/standalone_task.dart';
import 'package:bustan_amari/domain/entities/client_comment.dart';
import 'package:bustan_amari/domain/entities/contract_payment.dart';
import 'package:bustan_amari/domain/entities/contract_task.dart';
import 'package:bustan_amari/domain/entities/task_execution.dart';
import 'package:bustan_amari/domain/entities/task_photo.dart';
import 'package:bustan_amari/domain/entities/visit.dart';
import 'package:bustan_amari/domain/entities/visit_photo.dart';
import 'package:bustan_amari/domain/repositories/client_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClientRepository implements ClientRepository {
  final SupabaseClient _client;

  SupabaseClientRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  Future<String?> _resolveClientIdForComment(String contractId) async {
    try {
      final contractRow = await _client
          .from('contracts')
          .select('client_id')
          .eq('id', contractId)
          .single();

      final fromContract = contractRow['client_id']?.toString();
      if (fromContract != null && fromContract.trim().isNotEmpty) {
        return fromContract;
      }
    } catch (_) {
      // Ignore and try other compatibility paths.
    }

    try {
      final clientRow = await _client
          .from('clients')
          .select('id')
          .eq('user_id', _userId)
          .limit(1)
          .maybeSingle();

      final fromClientsTable = clientRow?['id']?.toString();
      if (fromClientsTable != null && fromClientsTable.trim().isNotEmpty) {
        return fromClientsTable;
      }
    } catch (_) {
      // Ignore when clients table does not exist in newer schema.
    }

    return null;
  }

  String? get _userDisplayName {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final metadata = user.userMetadata;
    final fromMetadata =
        metadata?['fullName']?.toString() ??
        metadata?['full_name']?.toString() ??
        metadata?['name']?.toString();
    if (fromMetadata != null && fromMetadata.trim().isNotEmpty) {
      return fromMetadata.trim();
    }
    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) return email;
    return null;
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

  Future<String> _resolveTaskPhotoUrl(String photoPath) async {
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

  Future<Map<String, String>> _loadContractTypeNamesById(Set<String> typeIds) async {
    if (typeIds.isEmpty) return const {};
    final rows = await _client
        .from('contract_types')
        .select('id, name')
        .inFilter('id', typeIds.toList());
    final names = <String, String>{};
    for (final row in rows as List) {
      final id = row['id']?.toString().trim() ?? '';
      final name = row['name']?.toString().trim() ?? '';
      if (id.isNotEmpty && name.isNotEmpty) names[id] = name;
    }
    return names;
  }

  @override
  Future<List<Contract>> listMyContracts() async {
    final rows = await _client
        .from('contracts_view')
        .select('*, users!user_id(phone)')
        .eq('user_id', _userId)
        .order('created_at', ascending: false);

    final contractRows = rows as List;

    final zoneIds = contractRows
        .map((row) => row['zone_id']?.toString().trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final typeIds = contractRows
        .map((row) => row['contract_type_id']?.toString().trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final results = await Future.wait([
      _loadZoneNamesById(zoneIds),
      _loadContractTypeNamesById(typeIds),
    ]);
    final zoneNames = results[0];
    final typeNames = results[1];

    return contractRows.map((row) {
      final zoneId = row['zone_id']?.toString().trim() ?? '';
      final typeId = row['contract_type_id']?.toString().trim() ?? '';
      return _mapContract(row,
          zoneName: zoneNames[zoneId], contractType: typeNames[typeId]);
    }).toList();
  }

  @override
  Future<Contract> updateContractGuardInfo({
    required String contractId,
    required String guardName,
    required String guardPhone,
  }) async {
    try {
      await _client.rpc(
        'update_contract_guard_info',
        params: <String, dynamic>{
          'p_contract_id': contractId,
          'p_guard_name': guardName.trim(),
          'p_guard_phone': guardPhone.trim(),
        },
      );

      final row = await _client
          .from('contracts_view')
          .select('*, users!user_id(phone)')
          .eq('id', contractId)
          .eq('user_id', _userId)
          .maybeSingle();

      if (row == null) {
        throw const FormatException('contract_not_found');
      }

      final contractRow = Map<String, dynamic>.from(row as Map);
      final zoneId = contractRow['zone_id']?.toString().trim() ?? '';
      final typeId = contractRow['contract_type_id']?.toString().trim() ?? '';

      final lookupResults = await Future.wait([
        _loadZoneNamesById({if (zoneId.isNotEmpty) zoneId}),
        _loadContractTypeNamesById({if (typeId.isNotEmpty) typeId}),
      ]);

      return _mapContract(contractRow,
          zoneName: lookupResults[0][zoneId],
          contractType: lookupResults[1][typeId]);
    } catch (e) {
      throw AppException(
        AppLocalizations.current.tr('guardInfoUpdateFailed'),
        ErrorType.server,
        e,
      );
    }
  }

  @override
  Future<List<ContractPayment>> listContractPayments(String contractId) async {
    final rows = await _client
        .from('contract_payments')
        .select()
        .eq('contract_id', contractId)
        .order('payment_date', ascending: false);

    return (rows as List).map((row) => _mapPayment(row)).toList();
  }

  @override
  Future<List<Visit>> listContractVisits(String contractId) async {
    final rows = await _client
        .from('visits')
        .select()
        .eq('contract_id', contractId)
        .order('visit_date', ascending: false);

    return (rows as List).map((row) => _mapVisit(row)).toList();
  }

  @override
  Future<List<ContractTask>> listContractTasks(String contractId) async {
    final rows = await _client
        .from('contract_tasks')
        .select()
        .eq('contract_id', contractId)
        .order('month', ascending: true);

    return (rows as List).map((row) => _mapTask(row)).toList();
  }

  @override
  Future<List<StandaloneTask>> listStandaloneTasksByContract(
    String contractId,
  ) async {
    final rows = await _client
        .from('standalone_tasks')
        .select()
        .eq('contract_id', contractId)
        .order('task_date', ascending: true);

    return (rows as List).map((row) => StandaloneTask.fromJson(row)).toList();
  }

  @override
  Future<List<VisitPhoto>> listVisitPhotos(String visitId) async {
    final rows = await _client
        .from('visit_photos')
        .select()
        .eq('visit_id', visitId)
        .order('created_at');

    final photos = await Future.wait(
      (rows as List)
          .whereType<Map>()
          .where(
            (row) => (row['photo_path']?.toString().trim().isNotEmpty ?? false),
          )
          .map((row) async {
            final resolvedUrl = await _resolveVisitPhotoUrl(
              row['photo_path']?.toString() ?? '',
            );

            return VisitPhoto(
              id: row['id']?.toString() ?? '',
              visitId: row['visit_id']?.toString() ?? visitId,
              photoPath: resolvedUrl,
              createdAt: row['created_at']?.toString() ?? '',
            );
          }),
    );

    return photos
        .where((photo) => photo.id.isNotEmpty && photo.photoPath.isNotEmpty)
        .toList();
  }

  @override
  Future<List<TaskExecution>> listVisitTaskExecutions(String visitId) async {
    final rows = await _client
        .from('task_executions')
        .select()
        .eq('visit_id', visitId)
        .order('created_at', ascending: false);

    return (rows as List)
        .whereType<Map>()
        .map(
          (row) => TaskExecution(
            id: row['id']?.toString() ?? '',
            taskId: row['task_id']?.toString() ?? '',
            supervisorId: row['supervisor_id']?.toString() ?? '',
            visitId: row['visit_id']?.toString(),
            notes: row['notes']?.toString(),
            status: row['status']?.toString() ?? 'completed',
            gpsLat: (row['gps_lat'] as num?)?.toDouble(),
            gpsLng: (row['gps_lng'] as num?)?.toDouble(),
            createdAt: row['created_at']?.toString() ?? '',
          ),
        )
        .where((e) => e.id.isNotEmpty && e.taskId.isNotEmpty)
        .toList();
  }

  @override
  Future<List<TaskExecution>> listTaskExecutionsByTaskIds(
    List<String> taskIds,
  ) async {
    if (taskIds.isEmpty) return const [];

    final rows = await _client
        .from('task_executions')
        .select()
        .inFilter('task_id', taskIds)
        .order('created_at', ascending: false);

    return (rows as List)
        .whereType<Map>()
        .map(
          (row) => TaskExecution(
            id: row['id']?.toString() ?? '',
            taskId: row['task_id']?.toString() ?? '',
            supervisorId: row['supervisor_id']?.toString() ?? '',
            visitId: row['visit_id']?.toString(),
            notes: row['notes']?.toString(),
            status: row['status']?.toString() ?? 'completed',
            gpsLat: (row['gps_lat'] as num?)?.toDouble(),
            gpsLng: (row['gps_lng'] as num?)?.toDouble(),
            createdAt: row['created_at']?.toString() ?? '',
          ),
        )
        .where((e) => e.id.isNotEmpty && e.taskId.isNotEmpty)
        .toList();
  }

  @override
  Future<List<TaskPhoto>> listTaskPhotosByExecutionIds(
    List<String> executionIds,
  ) async {
    if (executionIds.isEmpty) return const [];

    final rows = await _client
        .from('task_photos')
        .select()
        .inFilter('execution_id', executionIds)
        .order('created_at', ascending: true);

    final photos = await Future.wait(
      (rows as List)
          .whereType<Map>()
          .where(
            (row) => (row['photo_path']?.toString().trim().isNotEmpty ?? false),
          )
          .map((row) async {
            final resolvedUrl = await _resolveTaskPhotoUrl(
              row['photo_path']?.toString() ?? '',
            );

            return TaskPhoto(
              id: row['id']?.toString() ?? '',
              executionId: row['execution_id']?.toString() ?? '',
              photoPath: resolvedUrl,
              photoType: row['photo_type']?.toString() ?? 'before',
              createdAt: row['created_at']?.toString() ?? '',
            );
          }),
    );

    return photos
        .where((p) => p.id.isNotEmpty && p.executionId.isNotEmpty)
        .toList();
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

    final comments = await Future.wait(
      (rows as List).whereType<Map>().map((row) async {
        final raw = row['attachment_path']?.toString() ?? '';
        if (raw.trim().isNotEmpty) {
          try {
            row['attachment_path'] = await _resolveTaskPhotoUrl(raw);
          } catch (_) {
            // ignore resolution errors and leave raw path
          }
        }

        return _mapClientComment(row);
      }),
    );

    return comments
        .where((comment) => comment.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<ClientComment> createVisitComment({
    required String contractId,
    required String visitId,
    required String comment,
    String? attachmentFilePath,
  }) async {
    final trimmed = comment.trim();
    final clientId = await _resolveClientIdForComment(contractId);
    Map<String, dynamic> inserted;

    final basePayload = <String, dynamic>{
      'contract_id': contractId,
      'visit_id': visitId,
      'comment': trimmed,
      if (clientId != null) 'client_id': clientId,
    };

    if (attachmentFilePath != null && attachmentFilePath.trim().isNotEmpty) {
      try {
        final file = File(attachmentFilePath);
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
        final storagePath = 'comment-attachments/$visitId/$fileName';

        await _client.storage.from('task-photos').upload(storagePath, file);
        basePayload['attachment_path'] = storagePath;
      } catch (_) {
        // ignore upload failures and continue without attachment
      }
    }

    try {
      inserted = await _client
          .from('client_comments')
          .insert({...basePayload, 'author_name': _userDisplayName})
          .select()
          .single();
    } catch (_) {
      try {
        inserted = await _client
            .from('client_comments')
            .insert(basePayload)
            .select()
            .single();
      } catch (_) {
        final fallback = <String, dynamic>{
          'contract_id': contractId,
          'comment': trimmed,
          if (clientId != null) 'client_id': clientId,
        };
        if (basePayload.containsKey('attachment_path')) {
          fallback['attachment_path'] = basePayload['attachment_path'];
        }

        inserted = await _client
            .from('client_comments')
            .insert(fallback)
            .select()
            .single();
      }
    }

    if ((inserted['attachment_path']?.toString().trim().isNotEmpty ?? false)) {
      try {
        inserted['attachment_path'] = await _resolveTaskPhotoUrl(
          inserted['attachment_path'].toString(),
        );
      } catch (_) {
        // leave raw path if resolution fails
      }
    }

    return _mapClientComment(inserted);
  }

  Contract _mapContract(Map<String, dynamic> row, {String? zoneName, String? contractType}) =>
      Contract(
        id: row['id'] as String,
        code: row['code'] as String? ?? '',
        zoneId: row['zone_id'] as String?,
        zoneName: zoneName,
        lineId: row['line_id'] as String?,
        status: row['status'] as String? ?? 'active',
        startDate: row['start_date']?.toString() ?? '',
        endDate: row['end_date']?.toString() ?? '',
        totalValue: (row['total_value'] as num?)?.toDouble() ?? 0.0,
        clientName: row['client_name'] as String?,
        clientPhone:
            (row['client_phone'] ??
                    row['phone'] ??
                    (row['users'] != null
                        ? (row['users'] as Map)['phone']
                        : null))
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
        contractType: contractType,
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

  ContractPayment _mapPayment(Map<String, dynamic> row) => ContractPayment(
    id: row['id'] as String,
    contractId: row['contract_id'] as String,
    amount: (row['amount'] as num?)?.toDouble() ?? 0.0,
    paymentMethod: row['payment_method']?.toString() ?? 'cash',
    paymentDate: row['payment_date']?.toString() ?? '',
    transferImageUrl: row['transfer_image_url'] as String?,
    notes: row['notes'] as String?,
    createdAt: row['created_at']?.toString() ?? '',
    dueDate: row['due_date']?.toString(),
    paymentGatewayUrl: row['payment_gateway_url']?.toString(),
    paymentGatewayOrderId: row['payment_gateway_order_id']?.toString(),
    gatewayStatus: row['gateway_status']?.toString(),
    gatewayFeeAmount: (row['gateway_fee_amount'] as num?)?.toDouble(),
    receiptUrl: row['receipt_url']?.toString(),
    gatewayPaymentMethod: row['gateway_payment_method']?.toString(),
    receiptData: row['receipt_data'] is Map
        ? Map<String, dynamic>.from(row['receipt_data'] as Map)
        : null,
  );

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

  ContractTask _mapTask(Map<String, dynamic> row) => ContractTask(
    id: row['id'] as String,
    contractId: row['contract_id'] as String,
    visitId: row['visit_id'] as String?,
    title: row['title'] as String? ?? '',
    month: (row['month'] as num?)?.toInt() ?? 1,
    status: row['status'] as String? ?? 'pending',
    createdAt: row['created_at']?.toString() ?? '',
  );
}
