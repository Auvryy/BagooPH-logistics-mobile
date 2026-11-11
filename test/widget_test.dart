import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bagoo_scanner_mobile/main.dart';
import 'package:bagoo_scanner_mobile/models/scan_result.dart';
import 'package:bagoo_scanner_mobile/services/api_service.dart';
import 'package:bagoo_scanner_mobile/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ScanResult mock returns expected chute and mother bag data', () {
    final parcelResult = ScanResult.mock('BG-DEL-10293');
    expect(parcelResult.success, isTrue);
    expect(parcelResult.isError, isFalse);
    expect(parcelResult.chute, 'CHUTE-03');
    expect(parcelResult.recommendedBin, 'BIN-STACRUZ-01');
    expect(parcelResult.motherBagReference, contains('BAG-'));

    final motherBagResult = ScanResult.mock('MB-20261108-001');
    expect(motherBagResult.success, isTrue);
    expect(motherBagResult.chute, 'DOCK-BAY-02');
    expect(motherBagResult.action, 'CONSOLIDATE_MOTHER_BAG');

    final errResult = ScanResult.mock('ERR-BACKHAUL');
    expect(errResult.success, isFalse);
    expect(errResult.isError, isTrue);
    expect(errResult.chute, 'REJECT / EXCEPTION');
  });

  testWidgets('BagooScannerApp renders login screen when unauthenticated', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final storage = await StorageService.init();
    final api = ApiService(storage);

    await tester.pumpWidget(BagooScannerApp(storage: storage, api: api));
    await tester.pumpAndSettle();

    expect(find.text('BAGOO TERMINAL'), findsOneWidget);
    expect(find.text('Hub Scan Station'), findsOneWidget);
    expect(find.text('Sign In to Facility Station'), findsOneWidget);
    expect(find.text('Open Instant Offline Terminal (Demo)'), findsOneWidget);
  });
}
