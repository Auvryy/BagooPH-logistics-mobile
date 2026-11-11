import 'dart:convert';
import 'dart:typed_data';

import 'package:bagoo_scanner_mobile/services/api_service.dart';
import 'package:bagoo_scanner_mobile/models/scan_result.dart';
import 'package:bagoo_scanner_mobile/services/storage_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReplyAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final ResponseBody Function(RequestOptions) reply;
  ReplyAdapter(this.reply);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return reply(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonReply(Object body, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

Map<String, dynamic> account({bool token = true, bool multiple = false}) => {
  'data': {
    if (token) 'token': '17|test-session',
    'user': {
      'role': 'logistics',
      'email': 'operator@bagoo.test',
      'name': 'Test Operator',
    },
    'hubs': [
      {'id': 7, 'name': 'Assigned origin', 'code': 'TEST-ORIGIN'},
      if (multiple)
        {'id': 8, 'name': 'Assigned destination', 'code': 'TEST-DEST'},
    ],
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    storage = await StorageService.init();
  });

  ApiService service(ReplyAdapter adapter) =>
      ApiService(storage, dio: Dio()..httpClientAdapter = adapter);

  test(
    'operator login requires nested token and uses only server assignments',
    () async {
      final adapter = ReplyAdapter((_) => jsonReply(account()));
      final api = service(adapter);
      expect(
        (await api.login(
          'operator@bagoo.test',
          'private-test-value',
        ))['success'],
        true,
      );
      expect(adapter.requests.single.path, '/api/v1/logistics/auth/tokens');
      expect(storage.getToken(), '17|test-session');
      expect(storage.getHubId(), 7);
      expect(
        (await SharedPreferences.getInstance()).getString('bagoo_auth_token'),
        isNull,
      );
      await expectLater(api.selectHub(999), throwsFormatException);
    },
  );

  test(
    'missing token and HTML login never create authenticated or demo state',
    () async {
      for (final body in [account(token: false), '<html>Login page</html>']) {
        final api = service(
          ReplyAdapter(
            (_) => body is String
                ? ResponseBody.fromString(body, 200)
                : jsonReply(body),
          ),
        );
        expect(
          (await api.login(
            'operator@bagoo.test',
            'private-test-value',
          ))['success'],
          false,
        );
        expect(storage.isLoggedIn, false);
        expect(storage.getHubId(), isNull);
      }
    },
  );

  test('multiple assigned hubs require selection and server changes remove credentials', () async {
    final api = service(
      ReplyAdapter((_) => jsonReply(account(multiple: true))),
    );
    await api.login('operator@bagoo.test', 'private-test-value');
    expect(storage.getHubId(), isNull);
    expect((await api.scanBarcode(barcode: 'TEST-PARCEL')).success, false);
    await api.selectHub(8);
    expect(storage.getHubId(), 8);
    await storage.setServerUrl('https://work.bagoo.test/');
    expect(storage.getServerUrl(), 'https://work.bagoo.test');
    expect(storage.isLoggedIn, false);
    expect(storage.getHubId(), isNull);
    await expectLater(
      storage.setServerUrl('https://user:secret@work.bagoo.test/path'),
      throwsFormatException,
    );
  });

  test('continuous scan inspects then confirms the server action and expected status', () async {
    final adapter = ReplyAdapter((request) {
      if (request.path.endsWith('/tokens')) return jsonReply(account());
      final input = request.data as Map;
      return jsonReply({
        'success': true,
        'message': 'Server guidance',
        'prompt': {
          'action': 'RECEIVE_PARCEL',
          'expected_status': 'PICKED_UP',
          'requires_confirmation': input['mode'] == 'inspect',
        },
        'delivery': {'id': 3, 'tracking_number': 'TEST-PARCEL'},
      });
    });
    final api = service(adapter);
    await api.login('operator@bagoo.test', 'private-test-value');
    final result = await api.scanBarcode(
      barcode: 'TEST-PARCEL',
      mode: 'confirm',
    );
    expect(result.success, true);
    final scans = adapter.requests
        .where((request) => request.path.endsWith('/scan'))
        .toList();
    expect(scans.length, 2);
    expect(scans.first.data['mode'], 'inspect');
    expect(scans.last.data['action'], 'RECEIVE_PARCEL');
    expect(scans.last.data['expected_status'], 'PICKED_UP');
    expect(scans.last.data['hub_id'], 7);
    expect(scans.last.headers['Authorization'], 'Bearer 17|test-session');
    expect(result.chute, isNull);
  });

  test(
    'HTML scan cannot become mock success and expired session clears hub state',
    () async {
      var expired = false;
      final api = service(
        ReplyAdapter((request) {
          if (request.path.endsWith('/tokens')) return jsonReply(account());
          if (expired) return jsonReply({'message': 'Session expired.'}, 401);
          return ResponseBody.fromString('<html>Session login</html>', 200);
        }),
      );
      await api.login('operator@bagoo.test', 'private-test-value');
      expect((await api.scanBarcode(barcode: 'TEST-PARCEL')).success, false);
      expect(storage.isDemoMode(), false);
      expired = true;
      expect((await api.scanBarcode(barcode: 'TEST-PARCEL')).success, false);
      expect(storage.getToken(), isNull);
      expect(storage.getHubId(), isNull);
    },
  );

  test('startup removes legacy plaintext tokens and rejects revoked secure sessions', () async {
    SharedPreferences.setMockInitialValues({
      'bagoo_auth_token': 'legacy',
      'bagoo_hub_id': 99,
    });
    FlutterSecureStorage.setMockInitialValues({
      'bagoo_auth_token': '17|old-session',
    });
    storage = await StorageService.init();
    expect(
      (await SharedPreferences.getInstance()).getString('bagoo_auth_token'),
      isNull,
    );
    final api = service(
      ReplyAdapter((_) => jsonReply({'message': 'Revoked'}, 401)),
    );
    expect(await api.restoreSession(), false);
    expect(storage.isLoggedIn, false);
    expect(storage.getHubId(), isNull);
  });

  test('logout revokes bearer session and invitation always requests operator identity', () async {
    final adapter = ReplyAdapter(
      (request) => jsonReply(
        request.path.endsWith('/tokens') ? account() : {'success': true},
      ),
    );
    final api = service(adapter);
    await api.login('operator@bagoo.test', 'private-test-value');
    await api.logout();
    expect(adapter.requests.last.method, 'DELETE');
    expect(adapter.requests.last.path, '/api/v1/logistics/auth/token');
    expect(storage.isLoggedIn, false);
    expect(storage.getHubId(), isNull);
    await api.invitation('send', {
      'email': 'operator@bagoo.test',
      'kind': 'rider',
    });
    expect(adapter.requests.last.data['kind'], 'operator');
  });
  test('real bag identification preserves server reference without inventing capacity or receipt', () {
    final result = ScanResult.fromJson({
      'success': true,
      'confirmed': false,
      'is_master_bag': true,
      'message': 'Continue in hub bag receiving.',
      'prompt': {'requires_confirmation': false},
      'bag': {
        'reference': 'BAG-TEST-01',
        'seal_number': 'TEST-SEAL',
        'parcel_count': 4,
        'destination_hub': 'Assigned destination',
      },
    }, 'BAG-TEST-01');
    expect(result.motherBagReference, 'BAG-TEST-01');
    expect(result.sealNumber, 'TEST-SEAL');
    expect(result.bagParcelCount, 4);
    expect(result.bagMaxParcels, isNull);
    expect(result.weightKg, isNull);
    expect(result.requiresConfirmation, false);
    expect(result.nextFacility, 'Assigned destination');
  });
}
