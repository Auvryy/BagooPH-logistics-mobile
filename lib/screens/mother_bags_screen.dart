import 'package:flutter/material.dart';

import '../models/mother_bag.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/number_formatters.dart';
import 'bag_packing_screen.dart';

class MotherBagsScreen extends StatefulWidget {
  final StorageService storage;
  final ApiService api;

  const MotherBagsScreen({super.key, required this.storage, required this.api});

  @override
  State<MotherBagsScreen> createState() => _MotherBagsScreenState();
}

class _MotherBagsScreenState extends State<MotherBagsScreen> {
  BagWorkspaceData? _workspace;
  bool _loading = true;
  bool _creating = false;
  String? _error;

  int? _nextHubId;
  String _preset = 'standard';
  final _maxCount = TextEditingController(text: '50');
  final _maxWeight = TextEditingController(text: '25');
  final _maxVolume = TextEditingController(text: '0.30');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _maxCount.dispose();
    _maxWeight.dispose();
    _maxVolume.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.fetchMotherBags();
      if (!mounted) return;
      setState(() {
        _workspace = data;
        _loading = false;
        if (_nextHubId == null ||
            !data.nextHubs.any((hub) => hub.id == _nextHubId)) {
          _nextHubId = data.nextHubs.isNotEmpty ? data.nextHubs.first.id : null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _createBag() async {
    final hubId = widget.storage.getHubId();
    final destinationId = _nextHubId;
    if (hubId == null || destinationId == null || _creating) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    final result = await widget.api.createMotherBag(
      sourceHubId: hubId,
      destinationHubId: destinationId,
      capacityPreset: _preset,
      maxCount: int.tryParse(_maxCount.text.trim()),
      maxWeightKg: double.tryParse(_maxWeight.text.trim()),
      maxVolumeM3: double.tryParse(_maxVolume.text.trim()),
    );
    if (!mounted) return;
    setState(() => _creating = false);
    if (!result.success || result.bag == null) {
      setState(() => _error = result.message);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BagPackingScreen(
          storage: widget.storage,
          api: widget.api,
          bagId: result.bag!.id,
          initialBag: result.bag,
          vehicles: _workspace?.vehicles ?? const [],
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final hubName = widget.storage.getHubName();
    final workspace = _workspace;
    final canPack = workspace?.canPackDispatch ?? widget.api.canPackDispatch;

    if (_loading && workspace == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

          if (canPack && workspace != null)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Prepare & Open Mother Bag',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sending Hub: $hubName (Auto-selected)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _nextHubId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Next Hub',
                      isDense: true,
                    ),
                    selectedItemBuilder: (context) => workspace.nextHubs
                        .map(
                          (hub) => Text(
                            '${hub.name} (${hub.code})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                        .toList(),
                    items: workspace.nextHubs
                        .map(
                          (hub) => DropdownMenuItem<int>(
                            value: hub.id,
                            child: Text(
                              '${hub.name} (${hub.code})',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _nextHubId = value),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _preset,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Capacity Preset',
                      isDense: true,
                    ),
                    selectedItemBuilder: (context) => [
                      for (final p in workspace.presets)
                        Text(
                          p.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const Text(
                        'Custom limits',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    items: [
                      for (final p in workspace.presets)
                        DropdownMenuItem(
                          value: p.key,
                          child: Text(
                            p.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const DropdownMenuItem(
                        value: 'custom',
                        child: Text(
                          'Custom limits',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _preset = value;
                        final match = workspace.presets
                            .where((item) => item.key == value)
                            .firstOrNull;
                        if (match != null) {
                          _maxCount.text = '${match.maxCount}';
                          _maxWeight.text = match.maxWeightKg.toStringAsFixed(
                            0,
                          );
                          _maxVolume.text = match.maxVolumeM3.toStringAsFixed(
                            2,
                          );
                        }
                      });
                    },
                  ),
                  if (_preset == 'custom') ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _maxCount,
                            keyboardType: TextInputType.number,
                            inputFormatters: wholeNumberFormatters,
                            decoration: const InputDecoration(
                              labelText: 'Max parcels',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _maxWeight,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: decimalFormatters(),
                            decoration: const InputDecoration(
                              labelText: 'Max kg',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _maxVolume,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: decimalFormatters(),
                            decoration: const InputDecoration(
                              labelText: 'Max m³',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: (_creating || _nextHubId == null)
                        ? null
                        : _createBag,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.add_box_outlined),
                    label: Text(
                      _creating
                          ? 'Opening bag...'
                          : 'Create Bag & Start Camera Scan',
                    ),
                  ),
                ],
              ),
            )
          else if (!canPack)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.warningSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning),
              ),
              child: const Text(
                'Your job is locked to Entry / Intake. You can verify arriving bag seals below, while creating/packing bags is disabled.',
                style: TextStyle(fontSize: 12),
              ),
            ),

          const Text(
            'Active & Arriving Bags',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (workspace == null || workspace.bags.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No Mother Bags queued for this hub yet.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else
            for (final bag in workspace.bags)
              Card(
                color: AppColors.surface,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: ListTile(
                  title: Text(
                    bag.reference,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    '${bag.source?.code ?? ''} -> ${bag.destination?.code ?? ''} · ${bag.parcelsCount} parcels${bag.sealNumber != null ? " · Seal ${bag.sealNumber}" : ""}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: bag.status == 'open'
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      bag.status.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BagPackingScreen(
                          storage: widget.storage,
                          api: widget.api,
                          bagId: bag.id,
                          initialBag: bag,
                          vehicles: workspace.vehicles,
                        ),
                      ),
                    );
                    if (mounted) _load();
                  },
                ),
              ),
        ],
      ),
    );
  }
}
