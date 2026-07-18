import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AdminDataStatus { initial, loading, loaded, error }

class AdminProvider extends ChangeNotifier {
  final SupabaseClient _client;

  AdminProvider(this._client) {
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  AdminDataStatus _status = AdminDataStatus.initial;
  AdminDataStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<Map<String, dynamic>> _contracts = const [];
  List<Map<String, dynamic>> _contractTypes = const [];
  List<Map<String, dynamic>> _visits = const [];
  List<Map<String, dynamic>> _payments = const [];
  List<Map<String, dynamic>> _expenses = const [];
  List<Map<String, dynamic>> _lines = const [];
  List<Map<String, dynamic>> _zones = const [];

  List<Map<String, dynamic>> get allContracts => _contracts;
  List<Map<String, dynamic>> get allVisits => _visits;

  DateTimeRange? _dateRange;
  DateTimeRange? get dateRange => _dateRange;

  String _visitStatusFilter = 'all';
  String get visitStatusFilter => _visitStatusFilter;

  String _contractStatusFilter = 'all';
  String get contractStatusFilter => _contractStatusFilter;

  String _contractSearch = '';
  String get contractSearch => _contractSearch;

  String? _contractLineIdFilter;
  String? get contractLineIdFilter => _contractLineIdFilter;

  String? _contractZoneIdFilter;
  String? get contractZoneIdFilter => _contractZoneIdFilter;

  Future<void> loadDashboard() async {
    _status = AdminDataStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _safeFetch(
          () => _client
              .from('contracts_view')
              .select('*')
              .order('created_at', ascending: false),
        ),
        _safeFetch(
          () => _client
              .from('visits')
              .select(
                'id, contract_id, visit_date, status, updated_at, notes, title, summary, gps_lat, gps_lng, completed_at',
              )
              .order('updated_at', ascending: false),
        ),
        _safeFetch(
          () => _client
              .from('contract_payments')
              .select(
                'id, contract_id, amount, payment_method, payment_date, created_at, notes, gateway_status, due_date',
              )
              .order('payment_date', ascending: false),
        ),
        _safeFetch(
          () => _client
              .from('vehicle_expenses')
              .select(
                'id, vehicle_id, description, amount, expense_date, created_at',
              )
              .order('expense_date', ascending: false),
        ),
        _safeFetch(() => _client.from('contract_types').select('id, name')),
        _safeFetch(
          () =>
              _client.from('geographic_lines').select('id, name').order('name'),
        ),
        _safeFetch(
          () => _client.from('zones').select('id, line_id, name').order('name'),
        ),
      ]);

      _contracts = results[0];
      _visits = results[1];
      _payments = results[2];
      _expenses = results[3];
      _contractTypes = results[4];
      _lines = results[5];
      _zones = results[6];

      _status = AdminDataStatus.loaded;
    } catch (e) {
      _status = AdminDataStatus.error;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> _safeFetch(
    Future<dynamic> Function() query,
  ) async {
    try {
      final rows = await query();
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      return const [];
    }
  }

  void setDateRange(DateTimeRange? range) {
    _dateRange = range;
    notifyListeners();
  }

  void resetFilters() {
    _dateRange = null;
    _visitStatusFilter = 'all';
    _contractStatusFilter = 'all';
    _contractSearch = '';
    _contractLineIdFilter = null;
    _contractZoneIdFilter = null;
    notifyListeners();
  }

  void setVisitStatusFilter(String status) {
    _visitStatusFilter = status;
    notifyListeners();
  }

  void setContractStatusFilter(String status) {
    _contractStatusFilter = status;
    notifyListeners();
  }

  void setContractSearch(String query) {
    _contractSearch = query;
    notifyListeners();
  }

  void setContractLineFilter(String? lineId) {
    _contractLineIdFilter = _normalizeNullable(lineId);

    final selectedZone = _zoneById(_contractZoneIdFilter);
    final selectedZoneLineId = selectedZone?['line_id']?.toString();
    if (_contractLineIdFilter != null &&
        selectedZoneLineId != _contractLineIdFilter) {
      _contractZoneIdFilter = null;
    }

    notifyListeners();
  }

  void setContractZoneFilter(String? zoneId) {
    _contractZoneIdFilter = _normalizeNullable(zoneId);
    final selectedZone = _zoneById(_contractZoneIdFilter);
    final selectedZoneLineId = selectedZone?['line_id']?.toString();
    if (selectedZoneLineId != null && selectedZoneLineId.isNotEmpty) {
      _contractLineIdFilter = selectedZoneLineId;
    }
    notifyListeners();
  }

  List<Map<String, dynamic>> get availableContractLines {
    final usedLineIds = _contracts
        .map((c) => _normalizeNullable(c['line_id']?.toString()))
        .whereType<String>()
        .toSet();

    if (usedLineIds.isEmpty) return const [];

    final matched = _lines
        .where((line) => usedLineIds.contains(line['id']?.toString()))
        .map(
          (line) => {
            'id': line['id']?.toString() ?? '',
            'name':
                _normalizeName(line['name']) ?? line['id']?.toString() ?? '',
          },
        )
        .where((line) => (line['id'] as String).isNotEmpty)
        .toList();

    final matchedIds = matched.map((line) => line['id'] as String).toSet();
    final missing = usedLineIds
        .where((id) => !matchedIds.contains(id))
        .map((id) => {'id': id, 'name': id})
        .toList();

    final all = [...matched, ...missing];
    all.sort(
      (a, b) => (a['name'] as String).toLowerCase().compareTo(
        (b['name'] as String).toLowerCase(),
      ),
    );
    return all;
  }

  List<Map<String, dynamic>> get availableContractZones {
    final usedZoneIds = _contracts
        .where((c) {
          final zoneId = _normalizeNullable(c['zone_id']?.toString());
          if (zoneId == null) return false;
          if (_contractLineIdFilter == null) return true;
          return c['line_id']?.toString() == _contractLineIdFilter;
        })
        .map((c) => c['zone_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    if (usedZoneIds.isEmpty) return const [];

    final matched = _zones
        .where((zone) => usedZoneIds.contains(zone['id']?.toString()))
        .map(
          (zone) => {
            'id': zone['id']?.toString() ?? '',
            'line_id': zone['line_id']?.toString(),
            'name':
                _normalizeName(zone['name']) ?? zone['id']?.toString() ?? '',
          },
        )
        .where((zone) => (zone['id'] as String).isNotEmpty)
        .toList();

    final matchedIds = matched.map((zone) => zone['id'] as String).toSet();
    final missing = usedZoneIds
        .where((id) => !matchedIds.contains(id))
        .map((id) => {'id': id, 'line_id': null, 'name': id})
        .toList();

    final all = [...matched, ...missing];
    all.sort(
      (a, b) => (a['name'] as String).toLowerCase().compareTo(
        (b['name'] as String).toLowerCase(),
      ),
    );
    return all;
  }

  String contractLineNameById(String? lineId) {
    final id = _normalizeNullable(lineId);
    if (id == null) return '';
    final line = _lineById(id);
    return _normalizeName(line?['name']) ?? id;
  }

  String contractZoneNameById(String? zoneId) {
    final id = _normalizeNullable(zoneId);
    if (id == null) return '';
    final zone = _zoneById(id);
    return _normalizeName(zone?['name']) ?? id;
  }

  String? _normalizeNullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String? _normalizeName(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  Map<String, dynamic>? _lineById(String? lineId) {
    final id = _normalizeNullable(lineId);
    if (id == null) return null;
    for (final line in _lines) {
      if (line['id']?.toString() == id) return line;
    }
    return null;
  }

  Map<String, dynamic>? _zoneById(String? zoneId) {
    final id = _normalizeNullable(zoneId);
    if (id == null) return null;
    for (final zone in _zones) {
      if (zone['id']?.toString() == id) return zone;
    }
    return null;
  }

  DateTime _parseDate(dynamic raw) {
    if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(raw.toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _inRange(DateTime d) {
    final r = _dateRange;
    if (r == null) return true;
    final start = DateTime(r.start.year, r.start.month, r.start.day);
    final end = DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  String contractCodeById(String contractId) {
    final contract = _contracts.cast<Map<String, dynamic>?>().firstWhere(
      (c) => c?['id']?.toString() == contractId,
      orElse: () => null,
    );
    return contract?['code']?.toString() ?? '—';
  }

  Map<String, dynamic>? contractById(String contractId) {
    return _contracts.cast<Map<String, dynamic>?>().firstWhere(
      (c) => c?['id']?.toString() == contractId,
      orElse: () => null,
    );
  }

  String? contractTypeNameById(String? contractTypeId) {
    final id = contractTypeId?.trim();
    if (id == null || id.isEmpty) return null;

    final type = _contractTypes.cast<Map<String, dynamic>?>().firstWhere(
      (row) => row?['id']?.toString() == id,
      orElse: () => null,
    );

    final name = type?['name']?.toString().trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }

  List<Map<String, dynamic>> visitsForContract(String contractId) {
    final list = _visits
        .where((v) => v['contract_id']?.toString() == contractId)
        .toList();
    list.sort(
      (a, b) =>
          _parseDate(b['visit_date']).compareTo(_parseDate(a['visit_date'])),
    );
    return list;
  }

  List<Map<String, dynamic>> paymentsForContract(String contractId) {
    final list = _payments
        .where((p) => p['contract_id']?.toString() == contractId)
        .toList();
    list.sort(
      (a, b) => _parseDate(
        b['payment_date'],
      ).compareTo(_parseDate(a['payment_date'])),
    );
    return list;
  }

  num paidAmountForContract(String contractId) {
    return paymentsForContract(contractId)
        .where((p) {
          final gs = p['gateway_status']?.toString();
          final dd = p['due_date']?.toString();
          return gs == 'paid' || (gs == null && dd == null);
        })
        .fold<num>(0, (sum, p) => sum + ((p['amount'] as num?) ?? 0));
  }

  List<Map<String, dynamic>> get visitsChangedToday {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final list = _visits.where((v) {
      final updated = _parseDate(v['updated_at']);
      final status = v['status']?.toString() ?? 'planned';
      return !updated.isBefore(start) &&
          updated.isBefore(end) &&
          status != 'planned';
    }).toList();

    list.sort(
      (a, b) =>
          _parseDate(b['updated_at']).compareTo(_parseDate(a['updated_at'])),
    );
    return list;
  }

  List<Map<String, dynamic>> get visitsThisMonth {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);

    final list = _visits.where((v) {
      final visitDate = _parseDate(v['visit_date']);
      return !visitDate.isBefore(start) && visitDate.isBefore(end);
    }).toList();

    list.sort(
      (a, b) =>
          _parseDate(b['visit_date']).compareTo(_parseDate(a['visit_date'])),
    );
    return list;
  }

  List<Map<String, dynamic>> get filteredVisits {
    return _visits.where((v) {
      final visitDate = _parseDate(v['visit_date']);
      final status = v['status']?.toString() ?? 'planned';
      final statusOk =
          _visitStatusFilter == 'all' || status == _visitStatusFilter;
      return _inRange(visitDate) && statusOk;
    }).toList();
  }

  List<Map<String, dynamic>> get visitsInDateRange {
    return _visits.where((v) {
      final visitDate = _parseDate(v['visit_date']);
      return _inRange(visitDate);
    }).toList();
  }

  Map<String, int> get visitStatusCountsInDateRange {
    final counts = <String, int>{
      'planned': 0,
      'in_progress': 0,
      'completed': 0,
      'cancelled': 0,
    };

    for (final v in visitsInDateRange) {
      final status = v['status']?.toString() ?? 'planned';
      counts[status] = (counts[status] ?? 0) + 1;
    }

    return counts;
  }

  Map<String, int> get visitStatusCounts {
    final counts = <String, int>{
      'planned': 0,
      'in_progress': 0,
      'completed': 0,
      'cancelled': 0,
    };
    for (final v in filteredVisits) {
      final status = v['status']?.toString() ?? 'planned';
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  List<Map<String, dynamic>> get filteredTransferPayments {
    return _payments.where((p) {
      final method = (p['payment_method']?.toString() ?? '').toLowerCase();
      final paymentDate = _parseDate(p['payment_date']);
      return _inRange(paymentDate) &&
          (method == 'transfer' || method == 'bank_transfer');
    }).toList();
  }

  List<Map<String, dynamic>> get filteredContracts {
    return _contracts.where((c) {
      final createdAt = _parseDate(c['created_at']);
      final status = c['status']?.toString() ?? 'pending';
      final code = c['code']?.toString() ?? '';
      final clientName = c['client_name']?.toString() ?? '';
      final lineId = c['line_id']?.toString();
      final zoneId = c['zone_id']?.toString();
      final lineName = contractLineNameById(lineId);
      final zoneName = contractZoneNameById(zoneId);

      final statusOk =
          _contractStatusFilter == 'all' || status == _contractStatusFilter;
      final lineOk =
          _contractLineIdFilter == null || lineId == _contractLineIdFilter;
      final zoneOk =
          _contractZoneIdFilter == null || zoneId == _contractZoneIdFilter;
      final searchOk =
          _contractSearch.trim().isEmpty ||
          code.toLowerCase().contains(_contractSearch.toLowerCase()) ||
          clientName.toLowerCase().contains(_contractSearch.toLowerCase()) ||
          lineName.toLowerCase().contains(_contractSearch.toLowerCase()) ||
          zoneName.toLowerCase().contains(_contractSearch.toLowerCase());

      return _inRange(createdAt) && statusOk && lineOk && zoneOk && searchOk;
    }).toList();
  }

  List<Map<String, dynamic>> get filteredNewContracts {
    return _contracts
        .where((c) => _inRange(_parseDate(c['created_at'])))
        .toList();
  }

  num get periodRevenue {
    return _payments
        .where((p) => _inRange(_parseDate(p['payment_date'])))
        .fold<num>(0, (sum, p) => sum + ((p['amount'] as num?) ?? 0));
  }

  num get periodExpenses {
    return _expenses
        .where((e) => _inRange(_parseDate(e['expense_date'])))
        .fold<num>(0, (sum, e) => sum + ((e['amount'] as num?) ?? 0));
  }

  num get periodNet => periodRevenue - periodExpenses;

  int get newContractsCount => filteredNewContracts.length;
  int get transferCount => filteredTransferPayments.length;

  List<Map<String, dynamic>> get topExpenses {
    final list = _expenses
        .where((e) => _inRange(_parseDate(e['expense_date'])))
        .toList();
    list.sort(
      (a, b) =>
          ((b['amount'] as num?) ?? 0).compareTo((a['amount'] as num?) ?? 0),
    );
    return list.take(10).toList();
  }

  List<Map<String, dynamic>> get recentPayments {
    final list = _payments
        .where((p) => _inRange(_parseDate(p['payment_date'])))
        .toList();
    list.sort(
      (a, b) => _parseDate(
        b['payment_date'],
      ).compareTo(_parseDate(a['payment_date'])),
    );
    return list.take(10).toList();
  }
}
