class ScanResult {
  final bool success;
  final String barcode;
  final String? action;
  final String? nextStatus;
  final String? expectedStatus;
  final bool requiresConfirmation;
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
    this.expectedStatus,
    this.requiresConfirmation = false,
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
    Map<String, dynamic>? object(dynamic value) =>
        value is Map ? Map<String, dynamic>.from(value) : null;
    final delivery = object(json['delivery']) ?? object(json['data']);
    final prompt = object(json['prompt']) ?? object(delivery?['prompt']);
    final dws = object(delivery?['dws']);
    final bag = object(json['bag']) ?? object(delivery?['mother_bag_slotting']);
    final hop = object(json['next_hop']) ?? object(delivery?['next_hop']);
    final buyer = object(delivery?['buyer']);
    final success = json['success'] == true;
    String? text(dynamic value) =>
        value is String && value.isNotEmpty ? value : null;
    double? number(dynamic value) => value is num ? value.toDouble() : null;
    return ScanResult(
      success: success,
      barcode: scannedCode,
      action: text(prompt?['action']),
      nextStatus: text(prompt?['next_status']),
      expectedStatus: text(prompt?['expected_status']),
      requiresConfirmation: prompt?['requires_confirmation'] == true,
      message:
          text(json['message']) ??
          (success
              ? 'Waybill inspected.'
              : 'The server did not confirm this scan.'),
      isError: !success,
      chute: text(dws?['chute']),
      nextFacility:
          text(hop?['hub_name']) ??
          text(bag?['destination_hub']) ??
          text(dws?['next_facility_name']),
      recommendedBin:
          text(hop?['recommended_bin']) ?? text(delivery?['destination_bin']),
      motherBagReference: text(bag?['reference']),
      sealNumber: text(bag?['seal_number']),
      bagParcelCount: bag?['parcel_count'] is int
          ? bag!['parcel_count'] as int
          : null,
      bagMaxParcels: bag?['max_parcels'] is int
          ? bag!['max_parcels'] as int
          : null,
      weightKg: number(dws?['actual_weight_kg']),
      volumetricWeightKg: number(dws?['volumetric_weight_kg']),
      chargeableWeightKg: number(dws?['chargeable_weight_kg']),
      dimensions:
          dws?['length_cm'] is num &&
              dws?['width_cm'] is num &&
              dws?['height_cm'] is num
          ? '${dws!['length_cm']} × ${dws['width_cm']} × ${dws['height_cm']} cm'
          : null,
      destinationAddress:
          [
            text(buyer?['barangay']),
            text(buyer?['city']),
          ].whereType<String>().join(', ').isEmpty
          ? null
          : [
              text(buyer?['barangay']),
              text(buyer?['city']),
            ].whereType<String>().join(', '),
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
