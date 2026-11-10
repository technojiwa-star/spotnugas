import 'dart:async';

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
import 'package:spot_nugas/screens/home_screen.dart';
import 'package:spot_nugas/screens/search_results_screen.dart';
import 'package:spot_nugas/screens/spot_ai_screen.dart';
import 'package:spot_nugas/services/device_location_service.dart';
import 'package:spot_nugas/services/reverse_geocoding_service.dart';
import 'package:spot_nugas/widgets/place_card.dart';

class _LocationService implements DeviceLocationService {
  int calls = 0;
  final LocationPermissionStatus status;

  _LocationService({this.status = LocationPermissionStatus.denied});

  @override
  Future<DeviceLocationResult> getCurrentLocation({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    calls++;
    return DeviceLocationResult(
      status: status,
      errorMessage: 'Lokasi perangkat belum tersedia.',
    );
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermissionStatus> checkPermission() async =>
      LocationPermissionStatus.denied;

  @override
  Future<LocationPermissionStatus> requestPermission() async =>
      LocationPermissionStatus.denied;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

class _ReverseGeocoder implements ReverseGeocodingService {
  @override
  Future<String?> reverseGeocode(GeoCoordinates coordinates) async => null;

  @override
  void clearCache() {}
}

class _ControlledRepository implements PlaceRepository {
  final origins = <GeoCoordinates>[];
  final nearby = <Completer<List<Place>>>[];
  final queries = <PlaceSearchQuery>[];
  final searches = <Completer<List<Place>>>[];

  @override
  Future<List<Place>> getNearbyPlaces({
    required GeoCoordinates origin,
    double radiusKm = 5.0,
    int? limit,
  }) {
    origins.add(origin);
    final request = Completer<List<Place>>();
    nearby.add(request);
    return request.future;
  }

  @override
  Future<List<Place>> searchPlaces(PlaceSearchQuery query) {
    queries.add(query);
    final request = Completer<List<Place>>();
    searches.add(request);
    return request.future;
  }

  @override
  Future<Place?> getPlaceById(String id) async => null;
}

Place _place(String name) => Place(
  id: name,
  source: PlaceSource.manual,
  name: name,
  category: 'Cafe',
  latitude: AppLocation.depok.latitude,
  longitude: AppLocation.depok.longitude,
);

LocationNotifier _location({
  LocationState? initialState,
  _LocationService? service,
}) => LocationNotifier(
  locationService: service ?? _LocationService(),
  reverseGeocodingService: _ReverseGeocoder(),
  initialState:
      initialState ??
      const LocationState(
        coordinates: AppLocation.bandung,
        label: AppLocation.bandungLabel,
        source: LocationSource.manual,
      ),
);

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget screen,
  _ControlledRepository repository,
  LocationNotifier location,
) async {
  tester.view.physicalSize = const Size(1000, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentLocationProvider.overrideWith((ref) => location),
        placeRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('Home preserves an explicit manual city on startup', (
    tester,
  ) async {
    final service = _LocationService();
    final location = _location(service: service);
    final repository = _ControlledRepository();
    await _pumpScreen(tester, const HomeScreen(), repository, location);

    expect(service.calls, 0);
    expect(location.state.source, LocationSource.manual);
    expect(repository.origins, [AppLocation.bandung]);
    repository.nearby.single.complete([]);
    await tester.pumpAndSettle();
    expect(
      find.text('Belum ada tempat nugas ditemukan di sekitar lokasi ini.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final status in [
    LocationPermissionStatus.timeout,
    LocationPermissionStatus.error,
  ]) {
    testWidgets(
      'Home describes GPS $status without claiming missing permission',
      (tester) async {
        final repository = _ControlledRepository();
        final location = _location(
          service: _LocationService(status: status),
          initialState: LocationState.unresolved().copyWith(
            permissionStatus: status,
          ),
        );
        await _pumpScreen(tester, const HomeScreen(), repository, location);
        await tester.pumpAndSettle();

        expect(
          find.text(
            status == LocationPermissionStatus.timeout
                ? 'Lokasi GPS Belum Ditemukan'
                : 'Deteksi Lokasi Gagal',
          ),
          findsOneWidget,
        );
        expect(find.text('Izin Lokasi Belum Aktif'), findsNothing);
        expect(repository.origins, isEmpty);
      },
    );
  }

  for (final screen in const [
    HomeScreen(),
    SearchResultsScreen(),
    ExploreMapScreen(),
  ]) {
    testWidgets('${screen.runtimeType} waits for a selected location', (
      tester,
    ) async {
      final repository = _ControlledRepository();
      final location = _location(initialState: LocationState.unresolved());
      await _pumpScreen(tester, screen, repository, location);
      await tester.pumpAndSettle();

      expect(repository.origins, isEmpty);
      expect(repository.queries, isEmpty);
      expect(find.byType(FlutterMap), findsNothing);
      expect(find.textContaining('Pilih lokasi'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Jelajah keeps a successful empty response empty in map and list',
    (tester) async {
      final repository = _ControlledRepository();
      await _pumpScreen(
        tester,
        const ExploreMapScreen(),
        repository,
        _location(),
      );
      repository.nearby.single.complete([]);
      await tester.pumpAndSettle();

      expect(
        find.text('Belum ada tempat nugas ditemukan di sekitar lokasi ini.'),
        findsOneWidget,
      );
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
        hasLength(1),
      );
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();
      expect(find.text('Tidak ada tempat nugas ditemukan.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Jelajah shows an async error and retries without seed places', (
    tester,
  ) async {
    final repository = _ControlledRepository();
    await _pumpScreen(
      tester,
      const ExploreMapScreen(),
      repository,
      _location(),
    );
    repository.nearby.single.completeError(StateError('request failed'));
    await tester.pumpAndSettle();

    expect(
      find.text('Gagal memuat tempat nugas. Periksa koneksi lalu coba lagi.'),
      findsOneWidget,
    );
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      hasLength(1),
    );
    await tester.tap(find.text('Coba Lagi'));
    await tester.pump();
    expect(repository.nearby, hasLength(2));
    repository.nearby.last.complete([]);
    await tester.pumpAndSettle();
    expect(find.textContaining('Gagal memuat'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Search catches asynchronous repository errors and can retry', (
    tester,
  ) async {
    final repository = _ControlledRepository();
    await _pumpScreen(
      tester,
      const SearchResultsScreen(),
      repository,
      _location(),
    );
    repository.searches.single.completeError(StateError('request failed'));
    await tester.pumpAndSettle();

    expect(
      find.text('Pencarian gagal. Periksa koneksi lalu coba lagi.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Coba Lagi'));
    await tester.pump();
    expect(repository.searches, hasLength(2));
    repository.searches.last.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada tempat yang cocok'), findsOneWidget);
  });

  for (final screen in const [
    HomeScreen(),
    ExploreMapScreen(),
    SearchResultsScreen(),
  ]) {
    testWidgets(
      '${screen.runtimeType} ignores results from the previous city',
      (tester) async {
        final repository = _ControlledRepository();
        final location = _location();
        await _pumpScreen(tester, screen, repository, location);
        final requests = screen is SearchResultsScreen
            ? repository.searches
            : repository.nearby;
        expect(requests, hasLength(1));

        location.setManualLocation(AppLocation.depok, AppLocation.depokLabel);
        await tester.pump();
        expect(requests, hasLength(2));
        requests.last.complete([_place('Spot Depok terbaru')]);
        await tester.pumpAndSettle();
        expect(find.text('Spot Depok terbaru'), findsWidgets);

        requests.first.complete([_place('Spot Bandung lama')]);
        await tester.pumpAndSettle();
        expect(find.text('Spot Depok terbaru'), findsWidgets);
        expect(find.text('Spot Bandung lama'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Search ignores an older query after the newer query finishes', (
    tester,
  ) async {
    final repository = _ControlledRepository();
    await _pumpScreen(
      tester,
      const SearchResultsScreen(),
      repository,
      _location(),
    );
    await tester.enterText(find.byType(TextField), 'baru');
    await tester.pump();
    expect(repository.queries.last.text, 'baru');
    repository.searches.last.complete([_place('Hasil baru')]);
    await tester.pumpAndSettle();
    repository.searches.first.completeError(StateError('old request failed'));
    await tester.pumpAndSettle();

    expect(find.text('Hasil baru'), findsOneWidget);
    expect(find.textContaining('Pencarian gagal'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Keyed SpotAI waits for location and starts without demo recommendations',
    (tester) async {
      final repository = _ControlledRepository();
      await _pumpScreen(
        tester,
        const SpotAIScreen(),
        repository,
        _location(initialState: LocationState.unresolved()),
      );
      await tester.pumpAndSettle();

      expect(repository.origins, isEmpty);
      expect(find.byType(PlaceCard), findsNothing);
      expect(tester.takeException(), isNull);
    },
    skip: !GeoapifyConfig.hasApiKey,
  );

  testWidgets(
    'Keyed SpotAI keeps an empty live pool empty when asked for recommendations',
    (tester) async {
      final repository = _ControlledRepository();
      await _pumpScreen(
        tester,
        const SpotAIScreen(initialQuery: 'bandingkan spot untuk fokus'),
        repository,
        _location(),
      );
      repository.nearby.single.complete([]);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Belum ada spot yang dapat direkomendasikan'),
        findsOneWidget,
      );
      expect(find.byType(PlaceCard), findsNothing);
      expect(tester.takeException(), isNull);
    },
    skip: !GeoapifyConfig.hasApiKey,
  );
}
