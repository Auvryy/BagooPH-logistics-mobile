import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';
import 'scanner_screen.dart';

class HubSelectionScreen extends StatefulWidget {
  final StorageService storage;
  final ApiService api;
  const HubSelectionScreen({
    super.key,
    required this.storage,
    required this.api,
  });
  @override
  State<HubSelectionScreen> createState() => _HubSelectionScreenState();
}

class _HubSelectionScreenState extends State<HubSelectionScreen> {
  bool _busy = false;
  String? _error;
  Future<void> _select(int id) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.selectHub(id);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              ScannerScreen(storage: widget.storage, api: widget.api),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not select that assignment. Sign in again to refresh your hubs.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Choose your assigned hub'),
      automaticallyImplyLeading: false,
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Work at an authorized facility',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your company controls these assignments. Choose where you are working now.',
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            for (final hub in widget.api.hubs)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _select(hub['id'] as int),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(18),
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hub['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(hub['code'] as String),
                    ],
                  ),
                ),
              ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      await widget.api.logout();
                      if (!context.mounted) return;
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => LoginScreen(
                            storage: widget.storage,
                            api: widget.api,
                          ),
                        ),
                      );
                    },
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    ),
  );
}
