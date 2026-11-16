import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/mother_bag.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';

class BagPackingScreen extends StatefulWidget {
  final StorageService storage;
  final ApiService api;
  final String bagId;
  final MotherBagRecord? initialBag;
  final List<DispatchVehicle> vehicles;

  const BagPackingScreen({
    super.key,
    required this.storage,
    required this.api,
    required this.bagId,
    this.initialBag,
    this.vehicles = const [],
  });

  @override
  State<BagPackingScreen> createState() => _BagPackingScreenState();
}

class _BagPackingScreenState extends State<BagPackingScreen> {
  final _sealController = TextEditingController();
  final _manualController = TextEditingController();
  final _openTagController = TextEditingController();
  final _openSealController = TextEditingController();

  MobileScannerController? _scannerController;
  MotherBagRecord? _bag;
  List<DispatchVehicle> _vehicles = const [];
  int? _vehicleId;
  String? _dispatchToken;
  bool _loading = true;
  bool _busy = false;
  bool _cameraActive = false;
  bool _continuousAutoAdd = true;
  bool _sealIntact = true;
  String? _statusMessage;
  bool _statusIsError = false;
  String? _lastScannedCode;
  DateTime _lastScanTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _bag = widget.initialBag;
    _vehicles = widget.vehicles;
    _cameraActive = _bag?.status == 'open' && _bag?.canPack == true;
    if (_cameraActive) {
      _ensureScanner();
    }
    _refreshBag();
  }

  void _ensureScanner() {
    _scannerController ??= MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  void _disposeScanner() {
    _scannerController?.dispose();
    _scannerController = null;
  }

  @override
  void dispose() {
    _disposeScanner();
    _sealController.dispose();
    _manualController.dispose();
    _openTagController.dispose();
    _openSealController.dispose();
    super.dispose();
  }

  Future<void> _refreshBag() async {
    try {
      final bag = await widget.api.fetchMotherBag(widget.bagId);
      var vehicles = _vehicles;
      if (bag.canPack &&
          (bag.status == 'open' || bag.status == 'sealed') &&
          bag.sourceHubId > 0) {
        try {
          final workspace = await widget.api.fetchMotherBags(
            hubId: bag.sourceHubId,
          );
          vehicles = workspace.vehicles;
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _bag = bag;
        _vehicles = vehicles;
        _loading = false;
        _openTagController.text = bag.reference;
        if (bag.sealNumber != null && _openSealController.text.isEmpty) {
          _openSealController.text = bag.sealNumber!;
        }
        if (bag.status == 'open' && bag.canPack) {
          _cameraActive = true;
          _ensureScanner();
        } else {
          _cameraActive = false;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _statusMessage = error.toString();
        _statusIsError = true;
      });
    }
  }

  Future<void> _handleCameraDetect(BarcodeCapture capture) async {
    if (_busy || !_cameraActive || _bag == null || _bag!.status != 'open') {
      return;
    }
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;
      final now = DateTime.now();
      if (raw == _lastScannedCode &&
          now.difference(_lastScanTime).inMilliseconds < 1800) {
        return;
      }
      _lastScannedCode = raw;
      _lastScanTime = now;

      if (_continuousAutoAdd) {
        await _packBarcode(raw);
      } else {
        setState(() {
          _manualController.text = raw;
          _statusMessage = 'Captured $raw. Review and tap Add.';
          _statusIsError = false;
        });
        HapticFeedback.lightImpact();
      }
      break;
    }
  }

  Future<void> _packBarcode(
    String barcode, {
    Map<String, dynamic>? handling,
  }) async {
    final bag = _bag;
    final clean = barcode.trim();
    if (bag == null || clean.isEmpty || _busy) return;

    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    HapticFeedback.mediumImpact();

    final result = await widget.api.motherBagCommand(bag.id, 'add', {
      'version': bag.version,
      'barcode': clean,
      'handling': ?handling,
    });

    if (!mounted) return;
    if (result.needsMeasurements && handling == null) {
      setState(() => _busy = false);
      final readings = await _promptMeasurements(clean);
      if (readings != null && mounted) {
        await _packBarcode(clean, handling: readings);
      }
      return;
    }

    setState(() {
      _busy = false;
      if (result.bag != null) {
        _bag = result.bag;
      }
      _statusMessage = result.success
          ? 'Packed $clean (${result.bag?.parcelsCount ?? bag.parcelsCount} in bag)'
          : result.message;
      _statusIsError = !result.success;
      if (result.success) {
        _manualController.clear();
      }
    });
    if (result.success) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  Future<Map<String, dynamic>?> _promptMeasurements(String barcode) async {
    final weight = TextEditingController();
    final length = TextEditingController();
    final width = TextEditingController();
    final height = TextEditingController();
    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Measure outer package ($barcode)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter scale weight (kg) and box dimensions (cm) to pack safely.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: weight,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: length,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'L (cm)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: width,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'W (cm)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: height,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'H (cm)'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final w = double.tryParse(weight.text.trim());
              final l = double.tryParse(length.text.trim());
              final wi = double.tryParse(width.text.trim());
              final h = double.tryParse(height.text.trim());
              if (w == null || l == null || wi == null || h == null) return;
              Navigator.of(ctx).pop({
                'weight_kg': w,
                'length_cm': l,
                'width_cm': wi,
                'height_cm': h,
                'confirmed': true,
              });
            },
            child: const Text('Save & Pack'),
          ),
        ],
      ),
    );
    weight.dispose();
    length.dispose();
    width.dispose();
    height.dispose();
    return saved;
  }

  Future<void> _revertParcel(BagParcelItem item) async {
    final bag = _bag;
    if (bag == null || _busy) return;
    final reasonController = TextEditingController(text: 'Mis-scanned parcel');
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Revert ${item.trackingNumber}?'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Correction reason',
            hintText: 'Mis-scanned parcel',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(
              reasonController.text.trim().isEmpty
                  ? 'Mis-scanned parcel'
                  : reasonController.text.trim(),
            ),
            child: const Text('Revert scan'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || !mounted) return;

    setState(() => _busy = true);
    final result = await widget.api.motherBagCommand(bag.id, 'remove', {
      'version': bag.version,
      'barcode': item.trackingNumber,
      'notes': reason,
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.bag != null) _bag = result.bag;
      _statusMessage = result.success
          ? 'Reverted ${item.trackingNumber} out of bag.'
          : result.message;
      _statusIsError = !result.success;
    });
  }

  Future<void> _scanCodeSheet({
    required String title,
    required ValueChanged<String> onCaptured,
  }) async {
    final sheetScanner = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    bool popped = false;
    final code = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: 360,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: MobileScanner(
                controller: sheetScanner,
                onDetect: (capture) {
                  if (popped) return;
                  for (final barcode in capture.barcodes) {
                    final val = barcode.rawValue?.trim();
                    if (val != null && val.isNotEmpty) {
                      popped = true;
                      HapticFeedback.mediumImpact();
                      Navigator.of(ctx).pop(val);
                      break;
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
    await sheetScanner.dispose();
    if (code != null && mounted) {
      onCaptured(code);
    }
  }

  Future<void> _sealBag() async {
    final bag = _bag;
    final seal = _sealController.text.trim();
    if (bag == null || _busy) return;
    if (seal.isEmpty) {
      setState(() {
        _statusMessage = 'Scan or enter the printed seal number first.';
        _statusIsError = true;
      });
      return;
    }
    setState(() => _busy = true);
    final result = await widget.api.motherBagCommand(bag.id, 'seal', {
      'version': bag.version,
      'seal_number': seal,
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.bag != null) {
        _bag = result.bag;
        _cameraActive = false;
      }
      _statusMessage = result.message;
      _statusIsError = !result.success;
    });
  }

  /// Seal (when still open), put on the chosen truck and dispatch, all in one tap.
  Future<void> _dispatch(List<DispatchVehicle> choices) async {
    final bag = _bag;
    if (bag == null || _busy) return;
    final vehicleId = choices.any((v) => v.id == _vehicleId)
        ? _vehicleId
        : null;
    final seal = bag.status == 'open'
        ? _sealController.text.trim()
        : (bag.sealNumber ?? '');
    String? problem;
    if (bag.status == 'open' && seal.isEmpty) {
      problem = 'Scan or enter the printed seal number first.';
    } else if (vehicleId == null) {
      problem = 'Choose the truck carrying this bag.';
    }
    if (problem != null) {
      setState(() {
        _statusMessage = problem;
        _statusIsError = true;
      });
      return;
    }
    final token = _dispatchToken ??= widget.api.newRequestToken();
    setState(() => _busy = true);
    final result = await widget.api.dispatchMotherBag(
      bag.id,
      vehicleId: vehicleId!,
      requestToken: token,
      sealNumber: seal,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.success) _dispatchToken = null;
      if (result.bag != null) {
        _bag = result.bag;
        _cameraActive = false;
      }
      _statusMessage = result.message;
      _statusIsError = !result.success;
    });
  }

  Widget _truckPicker(List<DispatchVehicle> choices) {
    if (choices.isEmpty) {
      return const Text(
        'No van or truck with a driver is free at this hub. Ask the hub to assign one, then refresh.',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final vehicle in choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: vehicle.id == _vehicleId
                  ? AppColors.primary.withValues(alpha: 0.06)
                  : AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: vehicle.id == _vehicleId
                      ? AppColors.primary
                      : AppColors.border,
                  width: vehicle.id == _vehicleId ? 1.5 : 1,
                ),
              ),
              child: InkWell(
                key: ValueKey('truck-${vehicle.id}'),
                borderRadius: BorderRadius.circular(10),
                onTap: _busy
                    ? null
                    : () => setState(() {
                        _vehicleId = vehicle.id;
                        _dispatchToken = null;
                      }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        vehicle.id == _vehicleId
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: vehicle.id == _vehicleId
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicle.plate,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              [
                                vehicle.typeLabel,
                                if (vehicle.driver != null) vehicle.driver!,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openArrivingBag() async {
    final bag = _bag;
    if (bag == null || _busy) return;
    setState(() => _busy = true);
    final result = await widget.api.motherBagCommand(bag.id, 'open', {
      'version': bag.version,
      'barcode': _openTagController.text.trim(),
      'seal_number': _openSealController.text.trim(),
      'seal_intact': _sealIntact,
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.bag != null) _bag = result.bag;
      _statusMessage = result.message;
      _statusIsError = !result.success;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bag = _bag;
    if (_loading && bag == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mother Bag')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (bag == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mother Bag')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_statusMessage ?? 'Mother Bag unavailable.'),
          ),
        ),
      );
    }

    final activeParcels = bag.parcels.where((p) => !p.removed).toList();
    final trucks = DispatchVehicle.forLeg(
      _vehicles,
      bag.source,
      bag.destination,
    );
    if (_vehicleId == null && trucks.length == 1) _vehicleId = trucks.single.id;
    final destinationName =
        bag.destination?.code ?? bag.destination?.name ?? 'next hub';
    final cap = bag.capacity;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bag.reference,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            Text(
              '${bag.source?.code ?? ''} -> ${bag.destination?.code ?? ''} · ${bag.status.toUpperCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          if (bag.status == 'open' && bag.canPack)
            IconButton(
              icon: Icon(
                _cameraActive ? Icons.videocam : Icons.videocam_off_outlined,
                color: _cameraActive ? AppColors.success : AppColors.textMuted,
              ),
              tooltip: _cameraActive ? 'Pause camera' : 'Resume camera',
              onPressed: () {
                setState(() {
                  _cameraActive = !_cameraActive;
                  if (_cameraActive) _ensureScanner();
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : _refreshBag,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (_statusMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _statusIsError
                    ? AppColors.errorSurface
                    : AppColors.successSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _statusIsError ? AppColors.error : AppColors.success,
                ),
              ),
              child: Text(
                _statusMessage!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

          if (cap != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${cap.count} / ${cap.maxCount} parcels',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${cap.weightKg?.toStringAsFixed(1) ?? "?"} / ${cap.maxWeightKg.toStringAsFixed(0)} kg · ${bag.capacityPreset.toUpperCase()}',
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value:
                          (cap.count / (cap.maxCount <= 0 ? 1 : cap.maxCount))
                              .clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (bag.status == 'open' && bag.canPack) ...[
            if (_cameraActive && _scannerController != null)
              Container(
                height: 210,
                margin: const EdgeInsets.only(bottom: 10),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _busy ? AppColors.warning : AppColors.primary,
                    width: 2,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    MobileScanner(
                      controller: _scannerController!,
                      onDetect: _handleCameraDetect,
                    ),
                    Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _busy
                            ? 'Packing into ${bag.reference}...'
                            : (_continuousAutoAdd
                                  ? 'Continuous Camera: Point at parcels to auto-pack'
                                  : 'Point camera to capture waybill'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Continuous auto-pack',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Switch(
                        value: _continuousAutoAdd,
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) =>
                            setState(() => _continuousAutoAdd = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualController,
                          decoration: const InputDecoration(
                            hintText: 'Type or scan waybill (e.g. BGO-...)',
                            isDense: true,
                          ),
                          onSubmitted: _packBarcode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _packBarcode(_manualController.text),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Seal & dispatch to $destinationName',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _sealController,
                          onChanged: (_) => _dispatchToken = null,
                          decoration: const InputDecoration(
                            labelText: 'Seal number',
                            hintText: 'SL-XXXXX',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _scanCodeSheet(
                                title: 'Scan Printed Seal Barcode',
                                onCaptured: (code) {
                                  setState(() {
                                    _sealController.text = code;
                                    _dispatchToken = null;
                                  });
                                },
                              ),
                        icon: const Icon(Icons.qr_code_scanner, size: 16),
                        label: const Text('Scan Seal'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Truck',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  _truckPicker(trucks),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    key: const ValueKey('seal-and-dispatch'),
                    onPressed:
                        (_busy || activeParcels.isEmpty || trucks.isEmpty)
                        ? null
                        : () => _dispatch(trucks),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.local_shipping_outlined, size: 18),
                    label: const Text('Seal & dispatch'),
                  ),
                  TextButton(
                    onPressed: (_busy || activeParcels.isEmpty)
                        ? null
                        : _sealBag,
                    child: const Text('Seal only, dispatch later'),
                  ),
                ],
              ),
            ),
          ],

          if (bag.status == 'sealed' && bag.canPack)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Sealed · ${bag.sealNumber ?? ""}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pick the truck and dispatch to $destinationName.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _truckPicker(trucks),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    key: const ValueKey('dispatch-sealed'),
                    onPressed: (_busy || trucks.isEmpty)
                        ? null
                        : () => _dispatch(trucks),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.local_shipping_outlined, size: 18),
                    label: Text('Dispatch to $destinationName'),
                  ),
                ],
              ),
            ),

          if (bag.status == 'in_transit' && bag.canOpen)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Verify Arriving Bag & Seal',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _openTagController,
                    decoration: const InputDecoration(
                      labelText: 'Mother Bag Tag',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _openSealController,
                          decoration: const InputDecoration(
                            labelText: 'Physical Seal Number',
                            hintText: 'SL-XXXXX',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _scanCodeSheet(
                          title: 'Scan Arriving Seal',
                          onCaptured: (code) =>
                              setState(() => _openSealController.text = code),
                        ),
                        icon: const Icon(Icons.qr_code_scanner, size: 16),
                        label: const Text('Scan'),
                      ),
                    ],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _sealIntact,
                    onChanged: (v) => setState(() => _sealIntact = v ?? true),
                    title: const Text(
                      'Physical seal is intact and matches.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : _openArrivingBag,
                    child: const Text('Verify Seal & Open Bag'),
                  ),
                ],
              ),
            ),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recently Scanned in This Bag (${activeParcels.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (activeParcels.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No active parcels yet. Scan waybills above while bag stays open.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  for (final item in activeParcels)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.trackingNumber,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  item.status.replaceAll('_', ' '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (bag.status == 'open' && bag.canPack)
                            TextButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _revertParcel(item),
                              icon: const Icon(Icons.undo, size: 16),
                              label: const Text('Revert'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.error,
                              ),
                            ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
