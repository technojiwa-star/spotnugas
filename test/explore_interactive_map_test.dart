import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spot_nugas/config/geoapify_config.dart';
import 'package:spot_nugas/constants/app_location.dart';
import 'package:spot_nugas/models/place.dart';
import 'package:spot_nugas/providers/location_provider.dart';
import 'package:spot_nugas/providers/place_provider.dart';
import 'package:spot_nugas/repositories/place_repository.dart';
import 'package:spot_nugas/screens/explore_map_screen.dart';
import 'package:spot_nugas/screens/place_detail_screen.dart';
import 'package:spot_nugas/services/device_location_service.dart';
import 'package:spot_nugas/services/reverse_geocoding_service.dart';

class TestMockLocationService implements DeviceLocationService {
  DeviceLocationResult result;

  TestMockLocationService({DeviceLocationResult? result})
    : result =
          result ??
          DeviceLocationResult.success(
            const GeoCoordinates(-6.2297, 106.8295),
            isApproximate: false,
          );

  @override
  Future<bool> isLocationServiceEnabled() async =>
      result.status != LocationPermissionStatus.serviceDisabled;

  @override
  Future<LocationPermissionStatus> checkPermission() async => result.status;

  @override
  Future<LocationPermissionStatus> requestPermission() async => result.status;

  @override
  Future<DeviceLocationResult> getCurrentLocation({
    Duration timeout = const Duration(seconds: 8),
  }) async => result;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

class TestMockReverseGeocodingService implements ReverseGeocodingService {
  String resolvedLabel;
  TestMockReverseGeocodingService({this.resolvedLabel = 'Jakarta Selatan'});

  @override
  Future<String?> reverseGeocode(GeoCoordinates coords) async => resolvedLabel;

  @override
  void clearCache() {}
}

class TestPlaceRepository implements PlaceRepository {
  final List<Place> testPlaces;
  int getNearbyPlacesCallCount = 0;
  GeoCoordinates? lastOrigin;

  TestPlaceRepository({required this.testPlaces});

  @override
  Future<List<Place>> getNearbyPlaces({
    required GeoCoordinates origin,
    double radiusKm = 5.0,
    int? limit,
  }) async {
    getNearbyPlacesCallCount++;
    lastOrigin = origin;
    return testPlaces;
  }

  @override
  Future<List<Place>> searchPlaces(PlaceSearchQuery query) async {
    return testPlaces;
  }

  @override
  Future<Place?> getPlaceById(String id) async {
    for (final p in testPlaces) {
      if (p.id == id || p.geoapifyPlaceId == id) return p;
    }
    return null;
  }

  void clearCache() {}
}

List<Place> _createSamplePlaces() {
  return [
    Place(
      id: 'geoapify:place_cafe_1',
      source: PlaceSource.geoapify,
      geoapifyPlaceId: 'place_cafe_1',
      name: 'Kopi Kenangan Senopati',
      category: 'Cafe',
      latitude: -6.2290,
      longitude: 106.8290,
      studyScore: 4.8,
      priceLevel: PlacePriceLevel.inexpensive,
      isOpenNow: true,
      facilities: const [PlaceFacility.wifi, PlaceFacility.powerOutlet],
      atmosphere: const [PlaceAtmosphere.calm],
      tags: const ['cafe', 'wifi', 'colokan'],
      distanceKm: 0.1,
    ),
    Place(
      id: 'geoapify:place_coworking_2',
      source: PlaceSource.geoapify,
      geoapifyPlaceId: 'place_coworking_2',
      name: 'GoWork Pacific Place',
      category: 'Coworking Space',
      latitude: -6.2305,
      longitude: 106.8300,
      studyScore: 4.9,
      priceLevel: PlacePriceLevel.moderate,
      isOpenNow: true,
      facilities: const [PlaceFacility.wifi, PlaceFacility.powerOutlet],
      atmosphere: const [PlaceAtmosphere.calm],
      tags: const ['coworking', 'wifi', 'colokan'],
      distanceKm: 0.2,
    ),
    Place(
      id: 'geoapify:place_library_3',
      source: PlaceSource.geoapify,
      geoapifyPlaceId: 'place_library_3',
      name: 'Perpustakaan Nasional RI',
      category: 'Perpustakaan',
      latitude: -6.2295,
      longitude: 106.8280,
      studyScore: 4.7,
      priceLevel: PlacePriceLevel.free,
      isOpenNow: false,
      facilities: const [PlaceFacility.wifi, PlaceFacility.quietZone],
      atmosphere: const [PlaceAtmosphere.silent],
      tags: const ['library', 'perpustakaan', 'tenang'],
      distanceKm: 0.2,
    ),
  ];
}

Widget _buildTestApp({
  required Widget home,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      currentLocationProvider.overrideWith(
        (ref) => LocationNotifier(
          locationService: TestMockLocationService(),
          reverseGeocodingService: TestMockReverseGeocodingService(),
          initialState: LocationState.jakarta(),
        ),
      ),
      ...overrides,
    ],
    child: MaterialApp(home: home),
  );
}

void main() {
  group('Phase F1: Interactive Maps & Real Venue Markers Tests', () {
    testWidgets('1. Displays FlutterMap, TileLayer, and attribution', (
      WidgetTester tester,
    ) async {
      final samplePlaces = _createSamplePlaces();
      final testRepo = TestPlaceRepository(testPlaces: samplePlaces);

      await tester.pumpWidget(
        _buildTestApp(
          home: const ExploreMapScreen(),
          overrides: [placeRepositoryProvider.overrideWithValue(testRepo)],
        ),
      );
      await tester.pumpAndSettle();

      // Verify FlutterMap is mounted
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(TileLayer), findsOneWidget);

      // Verify attribution is displayed
      expect(find.text(GeoapifyConfig.attributionText), findsOneWidget);

      // Verify User GPS Indicator
      expect(find.text('Kamu di sini'), findsOneWidget);
    });

    testWidgets(
      '2. Creates real venue markers with correct category icons and scores',
      (WidgetTester tester) async {
        final samplePlaces = _createSamplePlaces();
        final testRepo = TestPlaceRepository(testPlaces: samplePlaces);

        await tester.pumpWidget(
          _buildTestApp(
            home: const ExploreMapScreen(),
            overrides: [placeRepositoryProvider.overrideWithValue(testRepo)],
          ),
        );
        await tester.pumpAndSettle();

        // Verify all 3 sample venue markers are created
        expect(
          find.byKey(const Key('marker_geoapify:place_cafe_1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('marker_geoapify:place_coworking_2')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('marker_geoapify:place_library_3')),
          findsOneWidget,
        );

        // Verify place names rendered in marker pills
        expect(find.text('Kopi Kenangan Senopati'), findsWidgets);
        expect(find.text('GoWork Pacific Place'), findsWidgets);
        expect(find.text('Perpustakaan Nasional RI'), findsWidgets);

        // Verify category icons
        expect(find.byIcon(Icons.coffee_rounded), findsWidgets);
        expect(find.byIcon(Icons.work_outline_rounded), findsWidgets);
        expect(find.byIcon(Icons.local_library_rounded), findsWidgets);
      },
    );

    testWidgets(
      '3. Map center reflects active location and recenters correctly',
      (WidgetTester tester) async {
        final samplePlaces = _createSamplePlaces();
        final testRepo = TestPlaceRepository(testPlaces: samplePlaces);
        final mockLocation = TestMockLocationService();
        final mockReverse = TestMockReverseGeocodingService(
          resolvedLabel: 'Jakarta Selatan',
        );

        await tester.pumpWidget(
          _buildTestApp(
            home: const ExploreMapScreen(),
            overrides: [
              placeRepositoryProvider.overrideWithValue(testRepo),
              deviceLocationServiceProvider.overrideWithValue(mockLocation),
              reverseGeocodingServiceProvider.overrideWithValue(mockReverse),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Find FlutterMap and verify camera initial center
        final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
        expect(
          flutterMap.options.initialCenter.latitude,
          closeTo(-6.2297, 0.01),
        );
        expect(
          flutterMap.options.initialCenter.longitude,
          closeTo(106.8295, 0.01),
        );

        // Tap recenter button
        await tester.tap(find.byIcon(Icons.my_location_rounded));
        await tester.pumpAndSettle();

        // Verify SnackBar notice appears
        expect(find.textContaining('Lokasi dipusatkan ke'), findsOneWidget);
      },
    );

    testWidgets(
      '4. Synchronizes map when city changes from Jakarta to Bandung',
      (WidgetTester tester) async {
        final samplePlaces = _createSamplePlaces();
        final testRepo = TestPlaceRepository(testPlaces: samplePlaces);
        final mockLocation = TestMockLocationService();
        final mockReverse = TestMockReverseGeocodingService(
          resolvedLabel: 'Jakarta Selatan',
        );

        late ProviderContainer container;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              placeRepositoryProvider.overrideWithValue(testRepo),
              deviceLocationServiceProvider.overrideWithValue(mockLocation),
              reverseGeocodingServiceProvider.overrideWithValue(mockReverse),
            ],
            child: Consumer(
              builder: (context, ref, child) {
                container = ProviderScope.containerOf(context);
                return const MaterialApp(home: ExploreMapScreen());
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        final initialCalls = testRepo.getNearbyPlacesCallCount;

        // Update location manually to Bandung
        container
            .read(currentLocationProvider.notifier)
            .setManualLocation(AppLocation.bandung, AppLocation.bandungLabel);
        await tester.pumpAndSettle();

        // Verify repository re-queried for Bandung origin
        expect(testRepo.getNearbyPlacesCallCount, greaterThan(initialCalls));
        expect(testRepo.lastOrigin?.latitude, closeTo(-6.9175, 0.01));
        expect(testRepo.lastOrigin?.longitude, closeTo(107.6191, 0.01));
      },
    );

    testWidgets('5. Tapping a marker updates preview card and selected state', (
      WidgetTester tester,
    ) async {
      final samplePlaces = _createSamplePlaces();
      final testRepo = TestPlaceRepository(testPlaces: samplePlaces);

      await tester.pumpWidget(
        _buildTestApp(
          home: const ExploreMapScreen(),
          overrides: [placeRepositoryProvider.overrideWithValue(testRepo)],
        ),
      );
      await tester.pumpAndSettle();

      // Initial place in preview card is first place
      expect(find.text('Kopi Kenangan Senopati'), findsWidgets);

      // Tap second marker (GoWork)
      await tester.tap(
        find.byKey(const Key('marker_geoapify:place_coworking_2')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // Preview card now shows GoWork Pacific Place
      expect(find.text('GoWork Pacific Place'), findsWidgets);
      expect(find.text('Lihat Detail'), findsOneWidget);
      expect(find.text('Rute'), findsOneWidget);
    });

    testWidgets(
      '6. Navigates to PlaceDetailScreen while preserving canonical identity',
      (WidgetTester tester) async {
        final samplePlaces = _createSamplePlaces();
        final testRepo = TestPlaceRepository(testPlaces: samplePlaces);

        await tester.pumpWidget(
          _buildTestApp(
            home: const ExploreMapScreen(),
            overrides: [placeRepositoryProvider.overrideWithValue(testRepo)],
          ),
        );
        await tester.pumpAndSettle();

        // Tap 'Lihat Detail' on current preview card
        await tester.tap(find.text('Lihat Detail'));
        await tester.pumpAndSettle();

        // PlaceDetailScreen is pushed
        expect(find.byType(PlaceDetailScreen), findsOneWidget);

        final detailScreen = tester.widget<PlaceDetailScreen>(
          find.byType(PlaceDetailScreen),
        );
        expect(detailScreen.place.id, 'geoapify:place_cafe_1');
        expect(detailScreen.place.geoapifyPlaceId, 'place_cafe_1');
        expect(detailScreen.place.name, 'Kopi Kenangan Senopati');
      },
    );

    testWidgets(
      '7. Responsive map layout on small Android screen (360x640) has zero overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final samplePlaces = _createSamplePlaces();
        final testRepo = TestPlaceRepository(testPlaces: samplePlaces);

        await tester.pumpWidget(
          _buildTestApp(
            home: const ExploreMapScreen(),
            overrides: [placeRepositoryProvider.overrideWithValue(testRepo)],
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Lihat Detail'), findsOneWidget);
        expect(find.text('Rute'), findsOneWidget);

        // Zoom in and out without overflow
        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.remove_rounded));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('8. Gracefully handles location permission fallback', (
      WidgetTester tester,
    ) async {
      final deniedLocation = TestMockLocationService(
        result: DeviceLocationResult.failure(
          LocationPermissionStatus.denied,
          message: 'Permission denied',
        ),
      );
      final samplePlaces = _createSamplePlaces();
      final testRepo = TestPlaceRepository(testPlaces: samplePlaces);

      await tester.pumpWidget(
        _buildTestApp(
          home: const ExploreMapScreen(),
          overrides: [
            placeRepositoryProvider.overrideWithValue(testRepo),
            deviceLocationServiceProvider.overrideWithValue(deniedLocation),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Even if permission is denied, map renders fallback coordinates safely
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('9. Category filter chips filter venue markers accordingly', (
      WidgetTester tester,
    ) async {
      final samplePlaces = _createSamplePlaces();
      final testRepo = TestPlaceRepository(testPlaces: samplePlaces);

      await tester.pumpWidget(
        _buildTestApp(
          home: const ExploreMapScreen(),
          overrides: [placeRepositoryProvider.overrideWithValue(testRepo)],
        ),
      );
      await tester.pumpAndSettle();

      // Filter by 'Harga Hemat' (cafe_1 is inexpensive, library_3 is free, coworking_2 is moderate)
      await tester.tap(find.text('Harga Hemat'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('marker_geoapify:place_cafe_1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('marker_geoapify:place_library_3')),
        findsOneWidget,
      );
      // Coworking is moderate price (not hemat)
      expect(
        find.byKey(const Key('marker_geoapify:place_coworking_2')),
        findsNothing,
      );

      // Return to 'Semua'
      await tester.tap(find.text('Semua'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('marker_geoapify:place_coworking_2')),
        findsOneWidget,
      );
    });

    testWidgets('10. Toggle between Map view and List view', (
      WidgetTester tester,
    ) async {
      final samplePlaces = _createSamplePlaces();
      final testRepo = TestPlaceRepository(testPlaces: samplePlaces);

      await tester.pumpWidget(
        _buildTestApp(
          home: const ExploreMapScreen(),
          overrides: [placeRepositoryProvider.overrideWithValue(testRepo)],
        ),
      );
      await tester.pumpAndSettle();

      // Initially map view
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('List'), findsOneWidget);

      // Tap toggle to list view
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();

      // Now in List view
      expect(find.byType(FlutterMap), findsNothing);
      expect(find.text('Peta'), findsOneWidget);

      // Toggle back to map
      await tester.tap(find.text('Peta'));
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets(
      '11. Unrated venues show "Belum Dinilai" and rated venues show legitimate scores',
      (WidgetTester tester) async {
        final mixedPlaces = [
          Place(
            id: 'geoapify:place_rated',
            source: PlaceSource.geoapify,
            geoapifyPlaceId: 'place_rated',
            name: 'Kopi Kenangan Senopati',
            category: 'Cafe',
            latitude: -6.2290,
            longitude: 106.8290,
            studyScore: 4.8,
            priceLevel: PlacePriceLevel.inexpensive,
            isOpenNow: true,
            distanceKm: 0.1,
          ),
          Place(
            id: 'geoapify:place_unrated',
            source: PlaceSource.geoapify,
            geoapifyPlaceId: 'place_unrated',
            name: 'Warung Kopi Baru',
            category: 'Cafe',
            latitude: -6.2300,
            longitude: 106.8300,
            studyScore: null,
            communityRating: null,
            priceLevel: PlacePriceLevel.inexpensive,
            isOpenNow: true,
            distanceKm: 0.2,
          ),
        ];

        final testRepo = TestPlaceRepository(testPlaces: mixedPlaces);

        await tester.pumpWidget(
          _buildTestApp(
            home: const ExploreMapScreen(),
            overrides: [placeRepositoryProvider.overrideWithValue(testRepo)],
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initially, first place is selected (rated)
        expect(find.text('Skor Nugas 4.8'), findsOneWidget);
        expect(find.text('4.8'), findsWidgets);
        expect(find.text('Skor Nugas 0.0'), findsNothing);

        // 2. Tap second marker (unrated place)
        await tester.tap(
          find.byKey(const Key('marker_geoapify:place_unrated')),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();

        // Preview card now displays 'Belum Dinilai' instead of 'Skor Nugas 0.0'
        expect(find.text('Warung Kopi Baru'), findsWidgets);
        expect(find.text('Belum Dinilai'), findsWidgets);
        expect(find.text('Skor Nugas 0.0'), findsNothing);
        expect(find.text('Nugas'), findsNothing);
      },
    );

    testWidgets(
      '12. At low zoom, groups nearby markers into a cluster without duplicate IDs',
      (WidgetTester tester) async {
        final samplePlaces = _createSamplePlaces();
        final testRepo = TestPlaceRepository(testPlaces: samplePlaces);

        await tester.pumpWidget(
          _buildTestApp(
            home: const ExploreMapScreen(),
            overrides: [placeRepositoryProvider.overrideWithValue(testRepo)],
          ),
        );
        await tester.pumpAndSettle();

        // At zoom 14 (initial), individual markers exist
        expect(
          find.byKey(const Key('marker_geoapify:place_cafe_1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('marker_geoapify:place_coworking_2')),
          findsOneWidget,
        );

        // Zoom out twice (14 -> 13 -> 12), triggering clustering for nearby places
        await tester.tap(find.byIcon(Icons.remove_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.remove_rounded));
        await tester.pumpAndSettle();

        // At zoom 12, nearby places cluster. The selected marker (cafe_1) remains individually identifiable
        expect(
          find.byKey(const Key('marker_geoapify:place_cafe_1')),
          findsOneWidget,
        );

        // Cluster marker exists for the remaining nearby spots
        expect(find.textContaining('Spot'), findsWidgets);

        // No duplicate widget keys or exceptions thrown
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '13. Tapping cluster zooms in and expands into individual venue pins',
      (WidgetTester tester) async {
        final samplePlaces = _createSamplePlaces();
        final testRepo = TestPlaceRepository(testPlaces: samplePlaces);

        await tester.pumpWidget(
          _buildTestApp(
            home: const ExploreMapScreen(),
            overrides: [placeRepositoryProvider.overrideWithValue(testRepo)],
          ),
        );
        await tester.pumpAndSettle();

        // Zoom out to trigger clustering
        await tester.tap(find.byIcon(Icons.remove_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.remove_rounded));
        await tester.pumpAndSettle();

        // Tap on the cluster marker
        final clusterTextFinder = find.textContaining('Spot');
        expect(clusterTextFinder, findsWidgets);
        await tester.tap(clusterTextFinder.first, warnIfMissed: false);
        await tester.pumpAndSettle();

        // Zoomed in, individual venues are revealed
        expect(
          find.byKey(const Key('marker_geoapify:place_coworking_2')),
          findsOneWidget,
        );
        expect(find.text('Lihat Detail'), findsOneWidget);

        // Open Place Detail from preview
        await tester.tap(find.text('Lihat Detail'));
        await tester.pumpAndSettle();

        expect(find.byType(PlaceDetailScreen), findsOneWidget);
      },
    );
  });
}
