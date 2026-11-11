import 'dart:async';

import 'package:dio/dio.dart';

import '../models/scan_result.dart';
import 'storage_service.dart';

class ApiService {
  final StorageService storage;
  final Dio _dio;
  List<Map<String, dynamic>> _hubs = [];
  List<Map<String, dynamic>> get hubs => List.unmodifiable(_hubs);

  ApiService(this.storage, {Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: storage.getServerUrl(),
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );
  }

  void updateBaseUrl(String url) {
    _dio.options.baseUrl = url;
    _hubs = [];
  }

  Options get _authorized =>
      Options(headers: {'Authorization': 'Bearer ${storage.getToken()}'});
  Map<String, dynamic> _object(dynamic value) {
    if (value is! Map) {
      throw const FormatException(
        'The server did not return a valid response.',
      );
    }
    return Map<String, dynamic>.from(value);
  }

  String _message(Object error) {
    if (error is DioException) {
      final body = error.response?.data;
      if (body is Map) {
        final errors = body['errors'];
        if (errors is Map) {
          for (final values in errors.values) {
            if (values is List && values.isNotEmpty && values.first is String) {
              return values.first as String;
            }
          }
        }
        final message = body['message'] ?? body['error'];
        if (message is String) return message;
      }
      return 'Could not reach the work server. Check the connection and try again.';
    }
    if (error is FormatException) return error.message;
    return 'Could not complete the request. Please try again.';
  }

  Future<void> _acceptResource(Map<String, dynamic> resource) async {
    final user = _object(resource['user']);
    final values = resource['hubs'];
    if (user['role'] != 'logistics' || values is! List || values.isEmpty) {
      throw const FormatException(
        'No active operator hub assignment is available. Contact your company owner.',
      );
    }
    final hubs = values.map(_object).toList();
    if (hubs.any(
      (hub) =>
          hub['id'] is! int ||
          (hub['id'] as int) <= 0 ||
          hub['name'] is! String ||
          hub['code'] is! String,
    )) {
      throw const FormatException(
        'The server returned an invalid hub assignment.',
      );
    }
    _hubs = hubs;
    await storage.setUserEmail(user['email'] as String?);
    await storage.setUserName(user['name'] as String?);
    final selected = hubs
        .where((hub) => hub['id'] == storage.getHubId())
        .firstOrNull;
    if (selected != null) {
      await selectHub(selected['id'] as int);
    } else if (hubs.length == 1) {
      await selectHub(hubs.single['id'] as int);
    } else {
      await storage.setHubId(null);
      await storage.setHubName('Choose an assigned hub');
    }
  }

  Future<void> selectHub(int id) async {
    final hub = _hubs.where((hub) => hub['id'] == id).firstOrNull;
    if (hub == null) {
      throw const FormatException('Choose one of your assigned hubs.');
    }
    await storage.setHubId(id);
    await storage.setHubName(hub['name'] as String);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    await storage.clearAuth();
    _hubs = [];
    try {
      final response = await _dio.post(
        '/api/v1/logistics/auth/tokens',
        data: {
          'email': email.trim(),
          'password': password,
          'device_name': 'Bagoo Mobile Barcode Terminal',
        },
      );
      final data = _object(_object(response.data)['data']);
      final token = data['token'];
      if (token is! String || token.isEmpty) {
        throw const FormatException(
          'The server did not issue an operator session.',
        );
      }
      await _acceptResource(data);
      await storage.setToken(token);
      return {'success': true};
    } catch (error) {
      await storage.clearAuth();
      _hubs = [];
      final body = error is DioException ? error.response?.data : null;
      return {
        'success': false,
        'message': _message(error),
        'activation_required':
            body is Map && body['activation_required'] == true,
      };
    }
  }

  Future<bool> restoreSession() async {
    if (storage.isDemoMode()) return true;
    if (storage.getToken() == null) return false;
    try {
      final response = await _dio.get(
        '/api/v1/logistics/session',
        options: _authorized,
      );
      await _acceptResource(_object(_object(response.data)['data']));
      return true;
    } catch (_) {
      await storage.clearAuth();
      _hubs = [];
      return false;
    }
  }

  Future<void> logout() async {
    try {
      if (!storage.isDemoMode() && storage.getToken() != null) {
        await _dio.delete('/api/v1/logistics/auth/token', options: _authorized);
      }
    } catch (_) {
      // Local sign-out still removes all account and hub state if disconnected.
    } finally {
      await storage.clearAuth();
      _hubs = [];
    }
  }

  Future<Map<String, dynamic>> invitation(
    String action,
    Map<String, dynamic> input,
  ) async {
    if (!['send', 'verify', 'complete'].contains(action)) {
      throw ArgumentError.value(action);
    }
    try {
      final response = await _dio.post(
        '/api/v1/logistics/activation/$action',
        data: {...input, 'kind': 'operator'},
      );
      return _object(response.data);
    } catch (error) {
      return {'success': false, 'message': _message(error)};
    }
  }

  Future<ScanResult> scanBarcode({
    required String barcode,
    String mode = 'inspect',
    String? action,
    String? expectedStatus,
  }) async {
    final clean = barcode.trim();
    if (clean.isEmpty) return ScanResult.error(clean, 'Empty barcode scanned.');
    if (storage.isDemoMode()) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      return ScanResult.mock(clean);
    }
    final hub = storage.getHubId();
    if (storage.getToken() == null ||
        hub == null ||
        !_hubs.any((item) => item['id'] == hub)) {
      return ScanResult.error(
        clean,
        'Sign in and choose an assigned hub before scanning.',
      );
    }
    try {
      Future<Map<String, dynamic>> send(
        String scanMode, {
        String? nextAction,
        String? status,
      }) async {
        final response = await _dio.post(
          '/api/v1/logistics/scan',
          options: _authorized,
          data: {
            'barcode': clean,
            'hub_id': hub,
            'mode': scanMode,
            if (scanMode == 'confirm') 'action': nextAction,
            if (scanMode == 'confirm') 'expected_status': status,
          },
        );
        return _object(response.data);
      }

      if (mode == 'confirm' && action == null) {
        final preview = await send('inspect');
        final result = ScanResult.fromJson(preview, clean);
        if (!result.success || !result.requiresConfirmation) return result;
        if (result.action == null || result.expectedStatus == null) {
          return ScanResult.error(
            clean,
            'The server did not provide a valid handover confirmation. Scan again.',
          );
        }
        return ScanResult.fromJson(
          await send(
            'confirm',
            nextAction: result.action,
            status: result.expectedStatus,
          ),
          clean,
        );
      }
      if (mode == 'confirm' && (action == null || expectedStatus == null)) {
        return ScanResult.error(
          clean,
          'Inspect the parcel before confirming custody.',
        );
      }
      return ScanResult.fromJson(
        await send(mode, nextAction: action, status: expectedStatus),
        clean,
      );
    } catch (error) {
      if (error is DioException && error.response?.statusCode == 401) {
        await storage.clearAuth();
        _hubs = [];
      }
      return ScanResult.error(clean, _message(error));
    }
  }
}
