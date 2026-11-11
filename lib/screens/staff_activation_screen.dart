import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';

class StaffActivationScreen extends StatefulWidget {
  final ApiService api;
  final String email;
  const StaffActivationScreen({super.key, required this.api, this.email = ''});
  @override
  State<StaffActivationScreen> createState() => _StaffActivationScreenState();
}

class _StaffActivationScreenState extends State<StaffActivationScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  Map<String, dynamic>? _assignment;
  String? _token;
  String? _assignmentToken;
  bool _sent = false, _busy = false, _accepted = false, _done = false;
  String? _error, _notice;
  @override
  void initState() {
    super.initState();
    _email.text = widget.email;
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit(String action) async {
    if (_busy) return;
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Enter the email your company invited.');
      return;
    }
    if (action == 'complete' &&
        (!_accepted ||
            _password.text != _confirmation.text ||
            _password.text.length < 12)) {
      setState(
        () => _error = 'Accept the assignment and enter matching passwords of at least 12 characters.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final result = await widget.api.invitation(action, {
        'email': _email.text.trim(),
        if (action == 'verify') 'code': _code.text,
        if (action == 'complete') ...{
          'token': _token,
          'assignment_token': _assignmentToken,
          'password': _password.text,
          'password_confirmation': _confirmation.text,
          'assignment_confirmed': _accepted,
        },
      });
      if (!mounted) return;
      if (result['success'] != true) {
        setState(
          () => _error =
              result['message'] as String? ?? 'Setup failed. Please try again.',
        );
        return;
      }
      setState(() {
        _notice = result['message'] as String?;
        if (action == 'send') {
          _sent = true;
          _token = null;
          _assignment = null;
          _code.clear();
        }
        if (action == 'verify') {
          if (result['token'] is! String ||
              result['assignment_token'] is! String ||
              result['assignment'] is! Map) {
            _error = 'The server did not return a valid assignment. Request another code.';
          } else {
            _token = result['token'] as String;
            _assignmentToken = result['assignment_token'] as String;
            _assignment = Map<String, dynamic>.from(
              result['assignment'] as Map,
            );
            _accepted = false;
          }
        }
        if (action == 'complete') {
          _done = true;
          _token = null;
          _code.clear();
        }
      });
    } finally {
      if (action == 'complete') {
        _password.clear();
        _confirmation.clear();
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Set up work account')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.mail_outline, color: AppColors.primary, size: 40),
            const SizedBox(height: 16),
            const Text(
              'Your own operator account',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Verify your invitation, review the assigned company and hub, then choose a password only you know.',
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            if (_notice != null)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_notice!),
                ),
              ),
            if (_done)
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Return to sign in'),
              )
            else ...[
              TextField(
                controller: _email,
                enabled: !_busy && _token == null,
                maxLength: 255,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Invited work email',
                ),
                onChanged: (_) => setState(() {
                  _sent = false;
                  _code.clear();
                }),
              ),
              if (_token == null) ...[
                FilledButton(
                  onPressed: _busy ? null : () => _submit('send'),
                  child: Text(_sent ? 'Resend setup code' : 'Email setup code'),
                ),
                if (_sent) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _code,
                    enabled: !_busy,
                    maxLength: 6,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Six-digit code',
                    ),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : () => _submit('verify'),
                    child: const Text('Verify code'),
                  ),
                ],
              ],
              if (_token != null && _assignment != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '${_assignment!['company']}\n${_assignment!['hub']}\nHub operator',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  enabled: !_busy,
                  maxLength: 128,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                TextField(
                  controller: _confirmation,
                  enabled: !_busy,
                  maxLength: 128,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                  ),
                ),
                const Text(
                  '12–128 characters, uppercase, lowercase, a number and a symbol.',
                ),
                CheckboxListTile(
                  value: _accepted,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _accepted = value ?? false),
                  title: const Text(
                    'I accept this company and hub assignment.',
                  ),
                ),
                FilledButton(
                  onPressed: _busy ? null : () => _submit('complete'),
                  child: const Text('Activate my work account'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _token = null;
                          _assignmentToken = null;
                          _assignment = null;
                          _password.clear();
                          _confirmation.clear();
                          _code.clear();
                          _accepted = false;
                        }),
                  child: const Text('Request another code or correct details'),
                ),
              ],
            ],
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    ),
  );
}
