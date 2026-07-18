class ContractPalmStats {
  final int largeProductive;
  final int largeNonProductive;
  final int smallProductive;
  final int smallNonProductive;

  const ContractPalmStats({
    this.largeProductive = 0,
    this.largeNonProductive = 0,
    this.smallProductive = 0,
    this.smallNonProductive = 0,
  });

  factory ContractPalmStats.fromJson(dynamic json) {
    if (json is! Map) return const ContractPalmStats();
    return ContractPalmStats(
      largeProductive: (json['largeProductive'] as num?)?.toInt() ?? 0,
      largeNonProductive: (json['largeNonProductive'] as num?)?.toInt() ?? 0,
      smallProductive: (json['smallProductive'] as num?)?.toInt() ?? 0,
      smallNonProductive: (json['smallNonProductive'] as num?)?.toInt() ?? 0,
    );
  }
}

class ContractPalmInfo {
  final bool isPalm;
  final String? species;
  final ContractPalmStats baladi;
  final ContractPalmStats washingtonia;

  const ContractPalmInfo({
    required this.isPalm,
    this.species,
    this.baladi = const ContractPalmStats(),
    this.washingtonia = const ContractPalmStats(),
  });

  factory ContractPalmInfo.fromJson(dynamic json) {
    if (json is! Map) return const ContractPalmInfo(isPalm: false);
    return ContractPalmInfo(
      isPalm: json['isPalm'] == true,
      species: json['species']?.toString(),
      baladi: ContractPalmStats.fromJson(json['baladi']),
      washingtonia: ContractPalmStats.fromJson(json['washingtonia']),
    );
  }
}

class Contract {
  final String id;
  final String code;
  final String? zoneId;
  final String? zoneName;
  final String? lineName;
  final String? lineId;
  final String status;
  final String startDate;
  final String endDate;
  final double totalValue;
  final String? clientName;
  final String? clientPhone;
  final String? contractUserName;
  final String? contractUserPhone;
  final String? addressDetails;
  final ContractPalmInfo? palmInfo;
  final String? blockNumber;
  final String? street;
  final String? avenue;
  final String? house;
  final String? kuwaitFinderUrl;
  final String? contractImageUrl;
  final List<ContractTerm> terms;
  final String createdAt;
  final String? contractType;

  const Contract({
    required this.id,
    required this.code,
    this.zoneId,
    this.zoneName,
    this.lineName,
    this.lineId,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.totalValue,
    this.clientName,
    this.clientPhone,
    this.contractUserName,
    this.contractUserPhone,
    this.addressDetails,
    this.palmInfo,
    this.blockNumber,
    this.street,
    this.avenue,
    this.house,
    this.kuwaitFinderUrl,
    this.contractImageUrl,
    this.terms = const [],
    required this.createdAt,
    this.contractType,
  });

  bool get isActive => status == 'active';

  String get fullAddress {
    final parts = <String>[];
    if (zoneName != null && zoneName!.isNotEmpty) {
      parts.add(zoneName!);
    }
    if (blockNumber != null && blockNumber!.isNotEmpty) {
      parts.add('قطعة $blockNumber');
    }
    if (street != null && street!.isNotEmpty) {
      parts.add('شارع $street');
    }
    if (avenue != null && avenue!.isNotEmpty) {
      parts.add('جادة $avenue');
    }
    if (house != null && house!.isNotEmpty) {
      parts.add('منزل $house');
    }
    if (parts.isEmpty && addressDetails != null) return addressDetails!;
    return parts.join('، ');
  }
}

class ContractTerm {
  final String? id;
  final String content;
  final bool isExcluded;
  final int activationOrder;
  final List<ContractTermVisit> visits;

  const ContractTerm({
    this.id,
    required this.content,
    this.isExcluded = false,
    this.activationOrder = 0,
    this.visits = const [],
  });
}

class ContractTermVisit {
  final String? id;
  final String description;
  final bool isExcluded;

  const ContractTermVisit({
    this.id,
    required this.description,
    this.isExcluded = false,
  });
}
