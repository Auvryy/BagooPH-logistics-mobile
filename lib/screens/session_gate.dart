import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'hub_selection_screen.dart';
import 'login_screen.dart';
import 'scanner_screen.dart';

class SessionGate extends StatefulWidget {
  final StorageService storage;
  final ApiService api;
  const SessionGate({super.key, required this.storage, required this.api});
  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final Future<bool> _session;
  @override
  void initState() {
    super.initState();
    _session = widget.api.restoreSession();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _session,
    builder: (context, state) {
      if (state.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (state.data != true) {
        return LoginScreen(storage: widget.storage, api: widget.api);
      }
      if (!widget.storage.isDemoMode() && widget.storage.getHubId() == null) {
        return HubSelectionScreen(storage: widget.storage, api: widget.api);
      }
      return ScannerScreen(storage: widget.storage, api: widget.api);
    },
  );
}
