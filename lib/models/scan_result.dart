class ScanResult {
  final bool success;
  final String barcode;
  final String? action;
  final String? nextStatus;
  final String message;
  final bool isError;
  final String? chute;
  final String? nextFacility;
  final String? recommendedBin;
  final String? motherBagReference;
  final String? sealNumber;
  final int? bagParcelCount;
  final int? bagMaxParcels;
  final double? weightKg;
  final double? volumetricWeightKg;
  final double? chargeableWeightKg;
  final String? dimensions;
  final String? destinationAddress;

  const ScanResult({
    required this.success,
    required this.barcode,
    this.action,
    this.nextStatus,
    required this.message,
    this.isError = false,
    this.chute,
    this.nextFacility,
    this.recommendedBin,
    this.motherBagReference,
    this.sealNumber,
    this.bagParcelCount,
    this.bagMaxParcels,
    this.weightKg,
    this.volumetricWeightKg,
    this.chargeableWeightKg,
    this.dimensions,
    this.destinationAddress,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json, String scannedCode) {
    final success = json['success'] == true;
    final data = json['data'] as Map<String, dynamic>?;
    final dws = data?['dws'] as Map<String, dynamic>?;
    final motherBag = data?['mother_bag_slotting'] as Map<String, dynamic>?;
    final nextHop = data?['next_hop'] as Map<String, dynamic>?;

    return ScanResult(
      success: success,
      barcode: scannedCode,
      action: data?['prompt']?['action'] as String? ?? 'INSPECT_WAYBILL',
      nextStatus: data?['prompt']?['next_status'] as String?,
      message: (json['message'] as String?) ??
          (success ? 'Parcel verified successfully.' : 'Scan failed.'),
      isError: !success,
      chute: dws?['chute'] as String? ?? 'CHUTE-01',
      nextFacility: nextHop?['hub_name'] as String? ??
          dws?['next_facility_name'] as String? ??
          'Destination Station',
      recommendedBin: nextHop?['recommended_bin'] as String? ?? 'BIN-DEFAULT',
      motherBagReference: motherBag?['reference'] as String?,
      sealNumber: motherBag?['seal_number'] as String?,
      bagParcelCount: motherBag?['parcel_count'] as int?,
      bagMaxParcels: motherBag?['max_parcels'] as int? ?? 50,
      weightKg: (dws?['actual_weight_kg'] as num?)?.toDouble() ?? 0.8,
      volumetricWeightKg:
          (dws?['volumetric_weight_kg'] as num?)?.toDouble() ?? 1.2,
      chargeableWeightKg:
          (dws?['chargeable_weight_kg'] as num?)?.toDouble() ?? 1.2,
      dimensions: dws != null
          ? '${dws['length_cm']}x${dws['width_cm']}x${dws['height_cm']} cm'
          : '25x18x12 cm',
      destinationAddress: data?['order']?['destination_barangay'] as String? ??
          'Santa Cruz, Laguna',
    );
  }

  factory ScanResult.error(String barcode, String errorMessage) {
    return ScanResult(
      success: false,
      barcode: barcode,
      message: errorMessage,
      isError: true,
      chute: 'REJECT / EXCEPTION',
      nextFacility: 'Exception Staging Bin',
      recommendedBin: 'BIN-EXCEPTION',
    );
  }

  /// High-impact simulated response for offline demonstrations and hardware testing
  factory ScanResult.mock(String barcode) {
    final clean = barcode.trim().toUpperCase();
    final isMotherBag = clean.startsWith('MB-') || clean.startsWith('BAG-');
    final isSeal = clean.startsWith('SL-');

    if (clean.contains('ERR') || clean.contains('FAIL')) {
      return ScanResult.error(
        barcode,
        'Routing Violation: Facility anti-backhaul guard rejected backward transport.',
      );
    }

    if (isMotherBag) {
      return ScanResult(
        success: true,
        barcode: barcode,
        action: 'CONSOLIDATE_MOTHER_BAG',
        nextStatus: 'sealed_and_staged',
        message: 'Mother Bag container verified. Ready for corridor linehaul loading.',
        chute: 'DOCK-BAY-02',
        nextFacility: 'Cavite Regional Mother Hub',
        recommendedBin: 'PALLET-CORRIDOR-04',
        motherBagReference: clean,
        sealNumber: 'SL-884019',
        bagParcelCount: 42,
        bagMaxParcels: 50,
        weightKg: 21.4,
        volumetricWeightKg: 24.0,
        chargeableWeightKg: 24.0,
        dimensions: '80x60x50 cm',
        destinationAddress: 'Corridor: Laguna -> Cavite Linehaul',
      );
    }

    if (isSeal) {
      return ScanResult(
        success: true,
        barcode: barcode,
        action: 'VERIFY_SECURITY_SEAL',
        nextStatus: 'seal_matched',
        message: 'Tamper-evident security seal logged in manifest chain.',
        chute: 'GATE-01',
        nextFacility: 'Corridor Security Bay',
        recommendedBin: 'SEAL-OK',
        sealNumber: clean,
      );
    }

    // Individual Parcel Waybill
    return ScanResult(
      success: true,
      barcode: barcode,
      action: 'SLOT_TO_MOTHER_BAG',
      nextStatus: 'arrived_at_hub',
      message: 'Induction verified. Place parcel into outbound Mother Bag.',
      chute: 'CHUTE-03',
      nextFacility: 'Santa Cruz Bayan Hub',
      recommendedBin: 'BIN-STACRUZ-01',
      motherBagReference: 'BAG-20261108-0082',
      sealNumber: 'SL-492102',
      bagParcelCount: 28,
      bagMaxParcels: 50,
      weightKg: 1.4,
      volumetricWeightKg: 1.8,
      chargeableWeightKg: 1.8,
      dimensions: '30x20x15 cm',
      destinationAddress: 'Brgy. Sto. Angel Sur, Sta. Cruz, Laguna',
    );
  }
}
