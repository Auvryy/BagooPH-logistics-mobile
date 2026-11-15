import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/bagoo_logistics_logo.dart';
import 'hub_selection_screen.dart';
import 'login_screen.dart';
import 'mother_bags_screen.dart';
import 'scanner_screen.dart';

class HubWorkspaceScreen extends StatefulWidget {
  final StorageService storage;
  final ApiService api;

  const HubWorkspaceScreen({
    super.key,
    required this.storage,
    required this.api,
  });

  @override
  State<HubWorkspaceScreen> createState() => _HubWorkspaceScreenState();
}

class _HubWorkspaceScreenState extends State<HubWorkspaceScreen> {
  late int _tabIndex;

  @override
  void initState() {
    super.initState();
    _tabIndex = (!widget.api.canIntake && widget.api.canPackDispatch) ? 1 : 0;
  }

  Future<void> _logout() async {
    await widget.api.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(storage: widget.storage, api: widget.api),
      ),
    );
  }

  void _switchHub() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            HubSelectionScreen(storage: widget.storage, api: widget.api),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.api.activeJobRole;
    final canIntake = widget.api.canIntake;
    final canPack = widget.api.canPackDispatch;
    final hubName = widget.storage.getHubName();

    if (canIntake && !canPack) {
      return ScannerScreen(storage: widget.storage, api: widget.api);
    }

    if (!canIntake && canPack) {
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const BagooLogisticsMark(size: 28, borderRadius: 7),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hubName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'LOCKED: ${widget.api.jobRoleLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (!widget.storage.isDemoMode() && widget.api.hubs.length > 1)
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                tooltip: 'Switch Hub',
                onPressed: _switchHub,
              ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign Out',
              onPressed: _logout,
            ),
          ],
        ),
        body: MotherBagsScreen(storage: widget.storage, api: widget.api),
      );
    }

    return Scaffold(
      appBar: _tabIndex == 1
          ? AppBar(
              title: Row(
                children: [
                  const BagooLogisticsMark(size: 28, borderRadius: 7),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$hubName · Mother Bags',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'ROLE: ${role.toUpperCase()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                if (!widget.storage.isDemoMode() && widget.api.hubs.length > 1)
                  IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    tooltip: 'Switch Hub',
                    onPressed: _switchHub,
                  ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Sign Out',
                  onPressed: _logout,
                ),
              ],
            )
          : null,
      body: _tabIndex == 0
          ? ScannerScreen(storage: widget.storage, api: widget.api)
          : MotherBagsScreen(storage: widget.storage, api: widget.api),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.2),
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Entry Intake',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Mother Bags',
          ),
        ],
      ),
    );
  }
}
