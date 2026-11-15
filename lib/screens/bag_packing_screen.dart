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
  final List<ManifestOption> manifests;

  const BagPackingScreen({
    super.key,
    required this.storage,
    required this.api,
    required this.bagId,
    this.initialBag,
    this.manifests = const [],
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
  List<ManifestOption> _manifests = const [];
  int? _selectedManifestId;
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
    _manifests = widget.manifests;
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
      List<ManifestOption> manifests = _manifests;
      if (manifests.isEmpty && bag.sourceHubId > 0) {
        try {
          final workspace = await widget.api.fetchMotherBags(hubId: bag.sourceHubId);
          manifests = workspace.manifests;
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _bag = bag;
        _manifests = manifests;
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: length,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'L (cm)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: width,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'W (cm)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: height,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

  Future<void> _loadToManifest() async {
    final bag = _bag;
    if (bag == null || _busy || _selectedManifestId == null) return;
    setState(() => _busy = true);
    final result = await widget.api.motherBagCommand(bag.id, 'load', {
      'version': bag.version,
      'barcode': bag.reference,
      'seal_number': bag.sealNumber ?? '',
      'manifest_id': _selectedManifestId,
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.bag != null) _bag = result.bag;
      _statusMessage = result.message;
      _statusIsError = !result.success;
    });
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
    final matchingManifests = _manifests
        .where(
          (m) =>
              m.sourceHubId == bag.sourceHubId &&
              m.destinationHubId == bag.destinationHubId,
        )
        .toList();
    final cap = bag.capacity;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bag.reference,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            Text(
              '${bag.source?.code ?? ''} -> ${bag.destination?.code ?? ''} · ${bag.status.toUpperCase()}',
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${cap.count} / ${cap.maxCount} parcels',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${cap.weightKg?.toStringAsFixed(1) ?? "?"} / ${cap.maxWeightKg.toStringAsFixed(0)} kg · ${bag.capacityPreset.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (cap.count / (cap.maxCount <= 0 ? 1 : cap.maxCount))
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
                      const Text(
                        'Continuous auto-pack',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Switch(
                        value: _continuousAutoAdd,
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) => setState(() => _continuousAutoAdd = v),
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
                  const Text(
                    'Seal & Ready for Dispatch',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Scan the printed security seal with the camera or type SL-XXXXX.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _sealController,
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
                                  });
                                },
                              ),
                        icon: const Icon(Icons.qr_code_scanner, size: 16),
                        label: const Text('Scan Seal'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: (_busy || activeParcels.isEmpty) ? null : _sealBag,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: const Text('Seal Bag (Ready for Dispatch)'),
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
                    'Sealed & Ready · ${bag.sealNumber ?? ""}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (matchingManifests.isNotEmpty) ...[
                    DropdownButtonFormField<int>(
                      initialValue: _selectedManifestId,
                      decoration: const InputDecoration(
                        labelText: 'Select Draft Manifest / Truck',
                        isDense: true,
                      ),
                      items: matchingManifests
                          .map(
                            (m) => DropdownMenuItem<int>(
                              value: m.id,
                              child: Text(
                                '${m.reference}${m.vehiclePlate != null ? " (${m.vehiclePlate})" : ""}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedManifestId = v),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed:
                          (_busy || _selectedManifestId == null) ? null : _loadToManifest,
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: const Text('Load Bag onto Manifest'),
                    ),
                  ] else
                    const Text(
                      'No draft manifest matches this bag route yet. Create a manifest on the hub portal or load at dispatch dock.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  item.status.replaceAll('_', ' '),
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
                              onPressed: _busy ? null : () => _revertParcel(item),
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
