import 'dart:async';
import 'package:dio/dio.dart';
import '../models/scan_result.dart';
import 'storage_service.dart';

class ApiService {
  final StorageService storage;
  late final Dio _dio;

  ApiService(this.storage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: storage.getServerUrl(),
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 8),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  void updateBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    if (storage.isDemoMode()) {
      await Future.delayed(const Duration(milliseconds: 300));
      return {
        'success': true,
        'token': 'demo_operator_token_${DateTime.now().millisecondsSinceEpoch}',
        'user': {
          'name': 'Warehouse Operator (Demo)',
          'email': email.isEmpty ? 'operator@bagoo.test' : email,
          'role': 'logistics',
        },
        'hub': {
          'id': 1,
          'name': 'Laguna Regional Mother Hub',
          'code': 'BGO-LAG-MH01',
        },
      };
    }

    try {
      final response = await _dio.post(
        '/api/v1/auth/tokens',
        data: {
          'email': email.trim(),
          'password': password,
          'device_name': 'Bagoo Mobile Barcode Terminal',
        },
      );

      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String? ?? data['access_token'] as String?;

      if (token != null) {
        await storage.setToken(token);
        await storage.setUserEmail(email);
        final user = data['user'] as Map<String, dynamic>?;
        if (user != null) {
          await storage.setUserName(user['name'] as String? ?? 'Operator');
        }
      }

      return {
        'success': true,
        'token': token,
        'data': data,
      };
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ??
          e.response?.data?['error'] ??
          e.message ??
          'Authentication failed. Check server connection.';
      return {
        'success': false,
        'message': message.toString(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<ScanResult> scanBarcode({
    required String barcode,
    String mode = 'inspect',
    String? action,
    String? expectedStatus,
  }) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) {
      return ScanResult.error(cleanBarcode, 'Empty barcode scanned.');
    }

    if (storage.isDemoMode()) {
      await Future.delayed(const Duration(milliseconds: 180));
      return ScanResult.mock(cleanBarcode);
    }

    try {
      final token = storage.getToken();
      final hubId = storage.getHubId() ?? 1;

      final options = Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'X-Requested-With': 'XMLHttpRequest',
        },
      );

      final payload = <String, dynamic>{
        'barcode': cleanBarcode,
        'hub_id': hubId,
        'mode': mode,
      };

      if (mode == 'confirm') {
        payload['action'] = action;
        payload['expected_status'] = expectedStatus;
      }

      final response = await _dio.post(
        '/hub/scan',
        data: payload,
        options: options,
      );

      if (response.data is Map<String, dynamic>) {
        return ScanResult.fromJson(response.data as Map<String, dynamic>, cleanBarcode);
      }

      return ScanResult.mock(cleanBarcode);
    } on DioException catch (e) {
      final dynamic err = e.response?.data?['error'] ??
          e.response?.data?['message'] ??
          e.message;
      return ScanResult.error(
        cleanBarcode,
        err?.toString() ?? 'Network error connecting to Hub scan server.',
      );
    } catch (e) {
      return ScanResult.error(cleanBarcode, e.toString());
    }
  }
}
