class BagPreset {
  final String key;
  final String label;
  final int maxCount;
  final double maxWeightKg;
  final int maxVolumeCm3;

  const BagPreset({
    required this.key,
    required this.label,
    required this.maxCount,
    required this.maxWeightKg,
    required this.maxVolumeCm3,
  });

  double get maxVolumeM3 => maxVolumeCm3 / 1000000.0;

  factory BagPreset.fromJson(Map<String, dynamic> json) => BagPreset(
    key: (json['key'] as String?) ?? 'standard',
    label: (json['label'] as String?) ?? 'Standard Sack',
    maxCount: (json['max_count'] as num?)?.toInt() ?? 50,
    maxWeightKg: (json['max_weight_kg'] as num?)?.toDouble() ?? 25.0,
    maxVolumeCm3: (json['max_volume_cm3'] as num?)?.toInt() ?? 300000,
  );
}

class NextHubOption {
  final int id;
  final String name;
  final String code;
  final String tier;

  const NextHubOption({
    required this.id,
    required this.name,
    required this.code,
    required this.tier,
  });

  factory NextHubOption.fromJson(Map<String, dynamic> json) => NextHubOption(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: (json['name'] as String?) ?? '',
    code: (json['code'] as String?) ?? '',
    tier: (json['tier'] as String?) ?? '',
  );
}

class ManifestOption {
  final int id;
  final String reference;
  final int sourceHubId;
  final int destinationHubId;
  final String? vehiclePlate;
  final String? driverName;

  const ManifestOption({
    required this.id,
    required this.reference,
    required this.sourceHubId,
    required this.destinationHubId,
    this.vehiclePlate,
    this.driverName,
  });

  factory ManifestOption.fromJson(Map<String, dynamic> json) => ManifestOption(
    id: (json['id'] as num?)?.toInt() ?? 0,
    reference: (json['reference'] as String?) ?? '',
    sourceHubId: (json['source_hub_id'] as num?)?.toInt() ?? 0,
    destinationHubId: (json['destination_hub_id'] as num?)?.toInt() ?? 0,
    vehiclePlate: json['vehicle_plate'] as String?,
    driverName: json['driver_name'] as String?,
  );
}

class BagCapacity {
  final int count;
  final double? weightKg;
  final int? volumeCm3;
  final int maxCount;
  final double maxWeightKg;
  final int maxVolumeCm3;

  const BagCapacity({
    required this.count,
    required this.weightKg,
    required this.volumeCm3,
    required this.maxCount,
    required this.maxWeightKg,
    required this.maxVolumeCm3,
  });

  factory BagCapacity.fromJson(Map<String, dynamic> json) => BagCapacity(
    count: (json['count'] as num?)?.toInt() ?? 0,
    weightKg: (json['weight_kg'] as num?)?.toDouble(),
    volumeCm3: (json['volume_cm3'] as num?)?.toInt(),
    maxCount: (json['max_count'] as num?)?.toInt() ?? 50,
    maxWeightKg: (json['max_weight_kg'] as num?)?.toDouble() ?? 25.0,
    maxVolumeCm3: (json['max_volume_cm3'] as num?)?.toInt() ?? 300000,
  );
}

class BagParcelItem {
  final int id;
  final String trackingNumber;
  final String status;
  final bool removed;
  final bool received;

  const BagParcelItem({
    required this.id,
    required this.trackingNumber,
    required this.status,
    required this.removed,
    required this.received,
  });

  factory BagParcelItem.fromJson(Map<String, dynamic> json) => BagParcelItem(
    id: (json['id'] as num?)?.toInt() ?? 0,
    trackingNumber: (json['tracking_number'] as String?) ?? '',
    status: (json['status'] as String?) ?? '',
    removed: json['removed'] == true,
    received: json['received'] == true,
  );
}

class MotherBagRecord {
  final String id;
  final String reference;
  final String status;
  final String? sealNumber;
  final int version;
  final int sourceHubId;
  final int destinationHubId;
  final int? manifestId;
  final int parcelsCount;
  final String capacityPreset;
  final String? physicalTag;
  final bool canPack;
  final bool canOpen;
  final NextHubOption? source;
  final NextHubOption? destination;
  final BagCapacity? capacity;
  final List<BagParcelItem> parcels;

  const MotherBagRecord({
    required this.id,
    required this.reference,
    required this.status,
    required this.sealNumber,
    required this.version,
    required this.sourceHubId,
    required this.destinationHubId,
    required this.manifestId,
    required this.parcelsCount,
    required this.capacityPreset,
    required this.physicalTag,
    required this.canPack,
    required this.canOpen,
    required this.source,
    required this.destination,
    required this.capacity,
    required this.parcels,
  });

  factory MotherBagRecord.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? mapOf(dynamic value) =>
        value is Map ? Map<String, dynamic>.from(value) : null;
    final parcelsJson = json['parcels'] is List
        ? json['parcels'] as List
        : const [];

    return MotherBagRecord(
      id: (json['id']?.toString()) ?? '',
      reference: (json['reference'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'open',
      sealNumber: json['seal_number'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 1,
      sourceHubId: (json['source_hub_id'] as num?)?.toInt() ?? 0,
      destinationHubId: (json['destination_hub_id'] as num?)?.toInt() ?? 0,
      manifestId: (json['manifest_id'] as num?)?.toInt(),
      parcelsCount: (json['parcels_count'] as num?)?.toInt() ?? 0,
      capacityPreset: (json['capacity_preset'] as String?) ?? 'standard',
      physicalTag: json['physical_tag'] as String?,
      canPack: json['can_pack'] == true,
      canOpen: json['can_open'] == true,
      source: mapOf(json['source']) != null
          ? NextHubOption.fromJson(mapOf(json['source'])!)
          : null,
      destination: mapOf(json['destination']) != null
          ? NextHubOption.fromJson(mapOf(json['destination'])!)
          : null,
      capacity: mapOf(json['capacity']) != null
          ? BagCapacity.fromJson(mapOf(json['capacity'])!)
          : null,
      parcels: parcelsJson
          .map((item) => mapOf(item))
          .whereType<Map<String, dynamic>>()
          .map(BagParcelItem.fromJson)
          .toList(),
    );
  }
}

class BagWorkspaceData {
  final String jobRole;
  final bool canIntake;
  final bool canPackDispatch;
  final List<MotherBagRecord> bags;
  final List<NextHubOption> nextHubs;
  final List<ManifestOption> manifests;
  final List<BagPreset> presets;

  const BagWorkspaceData({
    required this.jobRole,
    required this.canIntake,
    required this.canPackDispatch,
    required this.bags,
    required this.nextHubs,
    required this.manifests,
    required this.presets,
  });

  factory BagWorkspaceData.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> mapOf(dynamic value) =>
        value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
    List<Map<String, dynamic>> listOf(dynamic value) => value is List
        ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : const [];

    final hub = mapOf(json['hub']);
    return BagWorkspaceData(
      jobRole: (hub['job_role'] as String?) ?? 'all',
      canIntake: hub['can_intake'] != false,
      canPackDispatch: hub['can_pack_dispatch'] != false,
      bags: listOf(json['bags']).map(MotherBagRecord.fromJson).toList(),
      nextHubs: listOf(json['next_hubs']).map(NextHubOption.fromJson).toList(),
      manifests: listOf(json['manifests']).map(ManifestOption.fromJson).toList(),
      presets: listOf(json['presets']).map(BagPreset.fromJson).toList(),
    );
  }
}

class BagCommandResult {
  final bool success;
  final String message;
  final bool needsMeasurements;
  final MotherBagRecord? bag;

  const BagCommandResult({
    required this.success,
    required this.message,
    this.needsMeasurements = false,
    this.bag,
  });
}
