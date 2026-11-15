import 'package:bagoo_scanner_mobile/models/mother_bag.dart';
import 'package:bagoo_scanner_mobile/models/scan_result.dart';
import 'package:bagoo_scanner_mobile/screens/bag_packing_screen.dart';
import 'package:bagoo_scanner_mobile/screens/hub_workspace_screen.dart';
import 'package:bagoo_scanner_mobile/screens/mother_bags_screen.dart';
import 'package:bagoo_scanner_mobile/services/api_service.dart';
import 'package:bagoo_scanner_mobile/services/storage_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_api_test.dart';

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
    'worker exclusive role flags drive intake vs pack_dispatch access',
    () async {
      final adapter = ReplyAdapter((request) {
        if (request.path.endsWith('/tokens')) {
          return jsonReply({
            'data': {
              'token': '22|role-session',
              'user': {
                'role': 'logistics',
                'email': 'packer@bagoo.test',
                'name': 'Packer Worker',
              },
              'hubs': [
                {
                  'id': 11,
                  'name': 'Los Banos Bayan Hub',
                  'code': 'BH-LBN-01',
                  'tier': 'local_bayan_hub',
                  'job_role': 'pack_dispatch',
                  'can_intake': false,
                  'can_pack_dispatch': true,
                },
              ],
            },
          });
        }
        return jsonReply({'data': {}});
      });

      final api = service(adapter);
      await api.login('packer@bagoo.test', 'Password1234');
      expect(api.activeJobRole, 'pack_dispatch');
      expect(api.canIntake, false);
      expect(api.canPackDispatch, true);
      expect(api.jobRoleLabel, 'PACK & DISPATCH ONLY');
    },
  );

  test('mother bag API parses presets, creates bag, handles needs_measurements, and reverts/seals', () async {
    final adapter = ReplyAdapter((request) {
      if (request.path.endsWith('/tokens')) {
        return jsonReply(account());
      }
      if (request.method == 'GET' &&
          request.path == '/api/v1/logistics/mother-bags') {
        return jsonReply({
          'data': {
            'hub': {
              'id': 7,
              'name': 'Assigned origin',
              'code': 'TEST-ORIGIN',
              'tier': 'local_bayan_hub',
              'job_role': 'pack_dispatch',
              'can_intake': false,
              'can_pack_dispatch': true,
            },
            'bags': [],
            'next_hubs': [
              {
                'id': 8,
                'name': 'Laguna Mother Hub',
                'code': 'MH-LAG-01',
                'tier': 'regional_mother_hub',
              },
            ],
            'manifests': [],
            'presets': [
              {
                'key': 'standard',
                'label': 'Standard Sack (50 parcels · 25 kg · 0.30 m³)',
                'max_count': 50,
                'max_weight_kg': 25,
                'max_volume_cm3': 300000,
              },
            ],
          },
        });
      }
      if (request.method == 'POST' &&
          request.path == '/api/v1/logistics/mother-bags') {
        return jsonReply({
          'message': 'Mother Bag created.',
          'data': {
            'id': 'bag-uuid-1',
            'reference': 'BAG-001',
            'status': 'open',
            'version': 1,
            'source_hub_id': 7,
            'destination_hub_id': 8,
            'parcels_count': 0,
            'capacity_preset': 'custom',
            'can_pack': true,
            'can_open': false,
            'parcels': [],
          },
        }, 201);
      }
      if (request.path == '/api/v1/logistics/mother-bags/bag-uuid-1/add' &&
          request.data['handling'] == null) {
        return jsonReply({
          'message': 'Measure this outer package first.',
          'needs_measurements': true,
        }, 422);
      }
      return jsonReply({
        'message': 'OK',
        'data': {
          'id': 'bag-uuid-1',
          'reference': 'BAG-001',
          'status': request.path.endsWith('/seal') ? 'sealed' : 'open',
          'seal_number': request.path.endsWith('/seal') ? 'SL-9001' : null,
          'version': 2,
          'source_hub_id': 7,
          'destination_hub_id': 8,
          'parcels_count': request.path.endsWith('/remove') ? 0 : 1,
          'capacity_preset': 'custom',
          'can_pack': true,
          'can_open': false,
          'parcels': [],
        },
      });
    });

    final api = service(adapter);
    await api.login('operator@bagoo.test', 'Password1234');

    final workspace = await api.fetchMotherBags(hubId: 7);
    expect(workspace.nextHubs.single.name, 'Laguna Mother Hub');
    expect(workspace.presets.single.key, 'standard');

    final created = await api.createMotherBag(
      sourceHubId: 7,
      destinationHubId: 8,
      capacityPreset: 'custom',
      maxCount: 75,
      maxWeightKg: 40,
      maxVolumeM3: 0.45,
    );
    expect(created.success, true);
    expect(created.bag?.reference, 'BAG-001');

    final needsMeasure = await api.motherBagCommand('bag-uuid-1', 'add', {
      'version': 1,
      'barcode': 'BGO-123',
    });
    expect(needsMeasure.success, false);
    expect(needsMeasure.needsMeasurements, true);

    final added = await api.motherBagCommand('bag-uuid-1', 'add', {
      'version': 1,
      'barcode': 'BGO-123',
      'handling': {
        'weight_kg': 1.5,
        'length_cm': 20,
        'width_cm': 15,
        'height_cm': 10,
        'confirmed': true,
      },
    });
    expect(added.success, true);

    final reverted = await api.motherBagCommand('bag-uuid-1', 'remove', {
      'version': 2,
      'barcode': 'BGO-123',
      'notes': 'Mis-scanned parcel',
    });
    expect(reverted.success, true);
    expect(reverted.bag?.parcelsCount, 0);

    final sealed = await api.motherBagCommand('bag-uuid-1', 'seal', {
      'version': 2,
      'seal_number': 'SL-9001',
    });
    expect(sealed.success, true);
    expect(sealed.bag?.status, 'sealed');
    expect(sealed.bag?.sealNumber, 'SL-9001');
  });

  test(
    'ScanResult extracts bagId and isMasterBag for arriving Mother Bags',
    () {
      final result = ScanResult.fromJson({
        'success': true,
        'is_master_bag': true,
        'message': 'Open Mother Bag verification.',
        'prompt': {'requires_confirmation': false},
        'bag': {
          'id': 'bag-xyz-99',
          'reference': 'BAG-INCOMING-99',
          'seal_number': 'SL-55555',
          'parcel_count': 12,
        },
      }, 'BAG-INCOMING-99');
      expect(result.isMasterBag, true);
      expect(result.bagId, 'bag-xyz-99');
      expect(result.sealNumber, 'SL-55555');
    },
  );

  testWidgets('long hub names and capacity presets do not overflow at 320px width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const longHubName =
        'Calamba City / Batangas / Laguna Mega Consolidation Mother Hub Facility';
    const longNextHub =
        'San Pablo / Lipa / Quezon Ultra Regional Transfer Sorting Hub Center';
    const longPresetLabel =
        'Extra Large Heavy-Duty Oversized Consolidation Cage Preset (200 parcels · 99.5 kg · 1.25 m³)';

    final adapter = ReplyAdapter((request) {
      if (request.path.endsWith('/tokens')) {
        return jsonReply({
          'data': {
            'token': '22|role-session',
            'user': {
              'role': 'logistics',
              'email': 'packer@bagoo.test',
              'name': 'Packer Worker With Very Long Full Name',
            },
            'hubs': [
              {
                'id': 11,
                'name': longHubName,
                'code': 'BH-LBN-ULTRA-01',
                'tier': 'local_bayan_hub',
                'job_role': 'pack_dispatch',
                'can_intake': false,
                'can_pack_dispatch': true,
              },
            ],
          },
        });
      }
      if (request.path == '/api/v1/logistics/mother-bags') {
        return jsonReply({
          'data': {
            'hub': {
              'id': 11,
              'name': longHubName,
              'code': 'BH-LBN-ULTRA-01',
              'tier': 'local_bayan_hub',
              'job_role': 'pack_dispatch',
              'can_intake': false,
              'can_pack_dispatch': true,
            },
            'bags': [
              {
                'id': 'bag-long-1',
                'reference': 'MB-20261115-LONG-CONSOLIDATION-0001',
                'status': 'open',
                'seal_number': 'SL-LONG-99887766',
                'version': 1,
                'source_hub_id': 11,
                'destination_hub_id': 8,
                'capacity_preset': 'ultra_extra_heavy_cage_preset',
                'parcels_count': 5,
                'can_pack': true,
                'can_open': false,
                'source': {
                  'id': 11,
                  'name': longHubName,
                  'code': 'BH-LBN-ULTRA-01',
                },
                'destination': {
                  'id': 8,
                  'name': longNextHub,
                  'code': 'MH-QUEZON-01',
                },
                'capacity': {
                  'count': 5,
                  'weight_kg': 18.4,
                  'max_count': 200,
                  'max_weight_kg': 99.5,
                  'max_volume_cm3': 1250000,
                },
                'parcels': [],
              },
            ],
            'next_hubs': [
              {
                'id': 8,
                'name': longNextHub,
                'code': 'MH-QUEZON-01',
                'tier': 'regional_mother_hub',
              },
            ],
            'manifests': [],
            'presets': [
              {
                'key': 'standard',
                'label': longPresetLabel,
                'max_count': 200,
                'max_weight_kg': 99.5,
                'max_volume_cm3': 1250000,
              },
            ],
          },
        });
      }
      if (request.path == '/api/v1/logistics/mother-bags/bag-long-1') {
        return jsonReply({
          'data': {
            'id': 'bag-long-1',
            'reference': 'MB-20261115-LONG-CONSOLIDATION-0001',
            'status': 'sealed',
            'seal_number': 'SL-LONG-99887766',
            'version': 2,
            'source_hub_id': 11,
            'destination_hub_id': 8,
            'capacity_preset': 'ultra_extra_heavy_cage_preset',
            'parcels_count': 5,
            'can_pack': true,
            'can_open': false,
            'source': {
              'id': 11,
              'name': longHubName,
              'code': 'BH-LBN-ULTRA-01',
            },
            'destination': {
              'id': 8,
              'name': longNextHub,
              'code': 'MH-QUEZON-01',
            },
            'capacity': {
              'count': 5,
              'weight_kg': 18.4,
              'max_count': 200,
              'max_weight_kg': 99.5,
              'max_volume_cm3': 1250000,
            },
            'parcels': [
              {
                'id': 1,
                'tracking_number': 'BGO-WAYBILL-VERY-LONG-TRACKING-00001',
                'status': 'in_transit_to_mother_hub',
                'removed': false,
                'received': false,
              },
            ],
          },
        });
      }
      return jsonReply({'data': {}});
    });

    final api = service(adapter);
    await tester.runAsync(() => api.login('packer@bagoo.test', 'Password1234'));

    await tester.pumpWidget(
      MaterialApp(
        home: HubWorkspaceScreen(storage: storage, api: api),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(MotherBagsScreen), findsOneWidget);
    expect(find.text('Prepare & Open Mother Bag'), findsOneWidget);
    expect(find.text('MB-20261115-LONG-CONSOLIDATION-0001'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: BagPackingScreen(
          storage: storage,
          api: api,
          bagId: 'bag-long-1',
          manifests: [
            ManifestOption(
              id: 99,
              reference: 'MAN-20261115-LONG-TRUCK-DISPATCH-0099',
              sourceHubId: 11,
              destinationHubId: 8,
              vehiclePlate: 'ABC-123456-ISUZU-WINGVAN',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Sealed & Ready'), findsOneWidget);
    expect(
      find.textContaining('BGO-WAYBILL-VERY-LONG-TRACKING-00001'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
