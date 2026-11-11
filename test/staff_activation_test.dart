import 'package:bagoo_scanner_mobile/screens/staff_activation_screen.dart';
import 'package:bagoo_scanner_mobile/screens/hub_selection_screen.dart';
import 'package:bagoo_scanner_mobile/services/api_service.dart';
import 'package:bagoo_scanner_mobile/services/storage_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_api_test.dart' show ReplyAdapter, jsonReply, account;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    storage = await StorageService.init();
  });

  testWidgets(
    'worker reviews the verified assignment and must consent before activation',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final adapter = ReplyAdapter(
        (request) => jsonReply({
          'success': true,
          'message': 'Ready',
          if (request.path.endsWith('/verify')) ...{
            'token': 'verified-token',
            'assignment_token': 'assignment-signature',
            'assignment': {'company': 'Test Logistics', 'hub': 'Test Origin'},
          },
        }),
      );
      final api = ApiService(storage, dio: Dio()..httpClientAdapter = adapter);
      await tester.pumpWidget(
        MaterialApp(home: StaffActivationScreen(api: api)),
      );
      await tester.enterText(find.byType(TextField).first, 'worker@bagoo.test');
      await tester.tap(find.text('Email setup code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '123456');
      await tester.tap(find.text('Verify code'));
      await tester.pumpAndSettle();
      expect(
        find.text('Test Logistics\nTest Origin\nHub operator'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'Worker-Own-Secret!4826',
      );
      await tester.enterText(
        find.byType(TextField).at(2),
        'Worker-Own-Secret!4826',
      );
      await tester.tap(find.text('Activate my work account'));
      await tester.pumpAndSettle();
      expect(adapter.requests.length, 2);
      expect(find.textContaining('Accept the assignment'), findsOneWidget);
      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.text('Activate my work account'));
      await tester.pumpAndSettle();
      expect(
        adapter.requests.last.path,
        '/api/v1/logistics/activation/complete',
      );
      expect(adapter.requests.last.data['assignment_confirmed'], true);
      expect(
        adapter.requests.last.data['assignment_token'],
        'assignment-signature',
      );
      expect(adapter.requests.last.data['kind'], 'operator');
      expect(find.text('Return to sign in'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(storage.isLoggedIn, false);
    },
  );

  testWidgets(
    'email errors remain recoverable without advancing to password setup',
    (tester) async {
      final adapter = ReplyAdapter(
        (_) => jsonReply({
          'success': false,
          'message': 'Email delivery unavailable.',
        }, 503),
      );
      final api = ApiService(storage, dio: Dio()..httpClientAdapter = adapter);
      await tester.pumpWidget(
        MaterialApp(
          home: StaffActivationScreen(api: api, email: 'worker@bagoo.test'),
        ),
      );
      await tester.tap(find.text('Email setup code'));
      await tester.pumpAndSettle();
      expect(find.text('Email delivery unavailable.'), findsOneWidget);
      expect(find.text('Verify code'), findsNothing);
      expect(find.text('Email setup code'), findsOneWidget);
      expect(storage.isLoggedIn, false);
    },
  );

  testWidgets(
    'hub chooser lists server assignments without starting the camera',
    (tester) async {
      final api = ApiService(
        storage,
        dio: Dio()
          ..httpClientAdapter = ReplyAdapter(
            (_) => jsonReply(account(multiple: true)),
          ),
      );
      await tester.runAsync(
        () => api.login('worker@bagoo.test', 'private-test-value'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: HubSelectionScreen(storage: storage, api: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Assigned origin'), findsOneWidget);
      expect(find.text('Assigned destination'), findsOneWidget);
      expect(find.text('TEST-ORIGIN'), findsOneWidget);
      expect(storage.getHubId(), isNull);
    },
  );
}
