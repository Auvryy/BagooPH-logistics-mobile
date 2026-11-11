import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import 'scanner_screen.dart';
import 'hub_selection_screen.dart';
import 'staff_activation_screen.dart';

class LoginScreen extends StatefulWidget {
  final StorageService storage;
  final ApiService api;

  const LoginScreen({super.key, required this.storage, required this.api});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _showServerConfig = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.storage.getUserEmail() ?? '';
    _serverController.text = widget.storage.getServerUrl();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin({bool demo = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (demo) {
        await widget.storage.clearAuth();
        await widget.storage.setDemoMode(true);
        await widget.storage.setUserEmail('operator.demo@bagoo.ph');
        await widget.storage.setUserName('Station Operator (Demo)');
        await widget.storage.setHubName('Laguna Regional Mother Hub');
        await widget.storage.setHubId(1);
        if (mounted) {
          _navigateToScanner();
        }
        return;
      }

      final serverUrl = _serverController.text.trim();
      if (serverUrl.isNotEmpty) {
        await widget.storage.setServerUrl(serverUrl);
        widget.api.updateBaseUrl(widget.storage.getServerUrl());
      }

      await widget.storage.setDemoMode(false);
      final result = await widget.api.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;
      if (result['success'] == true) {
        if (mounted) {
          _navigateToScanner();
        }
      } else {
        setState(() {
          _errorMessage = result['message'] as String? ?? 'Login failed.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _passwordController.clear();
        });
      }
    }
  }

  void _navigateToScanner() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            !widget.storage.isDemoMode() && widget.storage.getHubId() == null
            ? HubSelectionScreen(storage: widget.storage, api: widget.api)
            : ScannerScreen(storage: widget.storage, api: widget.api),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 32.0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            try {
                              await widget.storage.setServerUrl(
                                _serverController.text.trim(),
                              );
                              widget.api.updateBaseUrl(
                                widget.storage.getServerUrl(),
                              );
                              if (!context.mounted) return;
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => StaffActivationScreen(
                                    api: widget.api,
                                    email: _emailController.text.trim(),
                                  ),
                                ),
                              );
                            } catch (_) {
                              if (mounted) {
                                setState(
                                  () => _errorMessage = 'Check the work server address before account setup.',
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.mark_email_read_outlined),
                    label: const Text('Activate an invited work account'),
                  ),
                  // Industrial Header Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.primaryDark),
                        ),
                        child: const Text(
                          'BAGOO TERMINAL',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title
                  const Text(
                    'Hub Scan Station',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign in to your facility account or start instant offline scanning.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Form Container
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.errorSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.error),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFCA5A5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Email Field
                        const Text(
                          'OPERATOR EMAIL',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailController,
                          enabled: !_isLoading,
                          maxLength: 255,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surfaceElevated,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        const Text(
                          'PASSWORD',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          enabled: !_isLoading,
                          maxLength: 128,
                          obscureText: true,
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surfaceElevated,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Server URL Config Toggle
                        InkWell(
                          onTap: () => setState(
                            () => _showServerConfig = !_showServerConfig,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  _showServerConfig
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _showServerConfig
                                      ? 'Hide Server Configuration'
                                      : 'Server Host URL Options',
                                  style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (_showServerConfig) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: _serverController,
                            enabled: !_isLoading,
                            maxLength: 2048,
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              labelText: 'API HOST URL',
                              labelStyle: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                              hintText: 'http://10.0.2.2:8000',
                              hintStyle: const TextStyle(
                                color: AppColors.textMuted,
                              ),
                              filled: true,
                              fillColor: AppColors.surfaceElevated,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Sign In Button
                        ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () => _handleLogin(demo: false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Sign In to Facility Station',
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 12),

                        // Demo / Fast Test Button
                        OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () => _handleLogin(demo: true),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(
                              color: AppColors.borderLight,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Open Instant Offline Terminal (Demo)',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'BagooPH Logistics Hardware & Mobile Protocol v1.0',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
