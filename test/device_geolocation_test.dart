import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spot_nugas/constants/app_location.dart';
import 'package:spot_nugas/datasources/geoapify_places_data_source.dart';
import 'package:spot_nugas/models/place.dart';
import 'package:spot_nugas/providers/location_provider.dart';
import 'package:spot_nugas/providers/place_provider.dart';
import 'package:spot_nugas/repositories/place_repository.dart';
import 'package:spot_nugas/screens/home_screen.dart';
import 'package:spot_nugas/services/device_location_service.dart';
import 'package:spot_nugas/services/reverse_geocoding_service.dart';

/// Test mock implementation of [DeviceLocationService]
class MockDeviceLocationService implements DeviceLocationService {
  DeviceLocationResult nextResult;
  bool appSettingsOpened = false;
  bool locationSettingsOpened = false;
  Future<DeviceLocationResult> Function()? onGetCurrentLocation;

  MockDeviceLocationService({DeviceLocationResult? nextResult})
    : nextResult =
          nextResult ??
          DeviceLocationResult.success(const GeoCoordinates(-6.2297, 106.8295));

  @override
  Future<bool> isLocationServiceEnabled() async =>
      nextResult.status != LocationPermissionStatus.serviceDisabled;

  @override
  Future<LocationPermissionStatus> checkPermission() async => nextResult.status;

  @override
  Future<LocationPermissionStatus> requestPermission() async =>
      nextResult.status;

  @override
  Future<DeviceLocationResult> getCurrentLocation({
    Duration timeout = const Duration(seconds: 8),
  }) async =>
      onGetCurrentLocation != null ? await onGetCurrentLocation!() : nextResult;

  @override
  Future<bool> openAppSettings() async {
    appSettingsOpened = true;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpened = true;
    return true;
  }
}

/// Test mock implementation of [ReverseGeocodingService]
class MockReverseGeocodingService implements ReverseGeocodingService {
  String? resolvedAddress;
  bool shouldThrow;
  Future<String?> Function(GeoCoordinates)? onReverseGeocode;

  MockReverseGeocodingService({
    this.resolvedAddress = 'Tebet, Jakarta Selatan',
    this.shouldThrow = false,
  });

  @override
  Future<String?> reverseGeocode(GeoCoordinates coords) async {
    if (onReverseGeocode != null) return onReverseGeocode!(coords);
    if (shouldThrow) throw Exception('Network timeout');
    return resolvedAddress;
  }

  @override
  void clearCache() {}
}

class TestGeolocatorPlatform extends GeolocatorPlatform {
  final Position position;
  LocationPermission permission = LocationPermission.whileInUse;
  Object? positionError;
  LocationSettings? requestedSettings;
  int positionRequests = 0;

  TestGeolocatorPlatform(GeoCoordinates coordinates)
    : position = Position(
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
        timestamp: DateTime.utc(2026, 10, 20),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
        hasAccuracy: true,
      );

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    positionRequests++;
    requestedSettings = locationSettings;
    if (positionError != null) throw positionError!;
    return position;
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => null;
}

class RecordingLocationPlaceRepository implements PlaceRepository {
  final origins = <GeoCoordinates>[];

  @override
  Future<List<Place>> getNearbyPlaces({
    required GeoCoordinates origin,
    double radiusKm = 5,
    int? limit,
  }) async {
    origins.add(origin);
    return [];
  }

  @override
  Future<List<Place>> searchPlaces(PlaceSearchQuery query) async => [];

  @override
  Future<Place?> getPlaceById(String id) async => null;
}

void main() {
  group('Production geolocator coordinate forwarding', () {
    for (final entry in <String, GeoCoordinates>{
      'Jakarta': const GeoCoordinates(-6.2297, 106.8295),
      'Bandung': AppLocation.bandung,
      'Mountain View': const GeoCoordinates(37.4219983, -122.084),
    }.entries) {
      test('preserves ${entry.key} platform coordinates', () async {
        final previousPlatform = GeolocatorPlatform.instance;
        addTearDown(() => GeolocatorPlatform.instance = previousPlatform);
        final platform = TestGeolocatorPlatform(entry.value);
        GeolocatorPlatform.instance = platform;

        final result = await const GeolocatorDeviceLocationService()
            .getCurrentLocation();

        expect(result.isSuccess, true);
        expect(result.coordinates, entry.value);
        expect(result.isApproximate, false);
        expect(
          platform.requestedSettings?.timeLimit,
          const Duration(seconds: 8),
        );
      });
    }

    test('denial does not request or invent a position', () async {
      final previousPlatform = GeolocatorPlatform.instance;
      addTearDown(() => GeolocatorPlatform.instance = previousPlatform);
      final platform = TestGeolocatorPlatform(AppLocation.bandung)
        ..permission = LocationPermission.denied;
      GeolocatorPlatform.instance = platform;

      final result = await const GeolocatorDeviceLocationService()
          .getCurrentLocation();

      expect(result.status, LocationPermissionStatus.denied);
      expect(result.coordinates, isNull);
      expect(platform.positionRequests, 0);
    });

    test(
      'timeout without a last known position remains an explicit failure',
      () async {
        final previousPlatform = GeolocatorPlatform.instance;
        addTearDown(() => GeolocatorPlatform.instance = previousPlatform);
        GeolocatorPlatform.instance = TestGeolocatorPlatform(
          AppLocation.bandung,
        )..positionError = TimeoutException('GPS timeout');

        final result = await const GeolocatorDeviceLocationService()
            .getCurrentLocation();

        expect(result.status, LocationPermissionStatus.timeout);
        expect(result.coordinates, isNull);
      },
    );
  });

  group('1. Device Location & Permission Handling', () {
    test(
      '1.1 Permission granted returns accurate coordinates and label',
      () async {
        final mockLocation = MockDeviceLocationService(
          nextResult: DeviceLocationResult.success(
            const GeoCoordinates(-6.2297, 106.8295),
            isApproximate: false,
          ),
        );
        final mockReverse = MockReverseGeocodingService(
          resolvedAddress: 'Tebet, Jakarta Selatan',
        );

        final notifier = LocationNotifier(
          locationService: mockLocation,
          reverseGeocodingService: mockReverse,
          initialState: LocationState.unresolved(),
        );

        await notifier.detectDeviceLocation();

        expect(notifier.state.source, LocationSource.deviceGps);
        expect(
          notifier.state.permissionStatus,
          LocationPermissionStatus.granted,
        );
        expect(notifier.state.coordinates.latitude, -6.2297);
        expect(notifier.state.coordinates.longitude, 106.8295);
        expect(notifier.state.label, 'Tebet, Jakarta Selatan');
        expect(notifier.state.isApproximate, false);
        expect(notifier.state.errorMessage, isNull);
      },
    );

    test(
      '1.2 Permission denied shows neutral label without claiming Jakarta is detected',
      () async {
        final mockLocation = MockDeviceLocationService(
          nextResult: DeviceLocationResult.failure(
            LocationPermissionStatus.denied,
            message: 'Izin lokasi ditolak oleh pengguna.',
          ),
        );
        final mockReverse = MockReverseGeocodingService();

        final notifier = LocationNotifier(
          locationService: mockLocation,
          reverseGeocodingService: mockReverse,
          initialState: LocationState.unresolved(),
        );

        await notifier.detectDeviceLocation();

        expect(
          notifier.state.permissionStatus,
          LocationPermissionStatus.denied,
        );
        expect(notifier.state.label, 'Pilih Lokasi (Izin Ditolak)');
        expect(
          notifier.state.errorMessage,
          'Izin lokasi ditolak oleh pengguna.',
        );
        expect(notifier.state.source, isNot(LocationSource.deviceGps));
        expect(notifier.state.hasSelectedLocation, false);
      },
    );

    test(
      '1.3 Permanently denied updates state and delegates to openAppSettings',
      () async {
        final mockLocation = MockDeviceLocationService(
          nextResult: DeviceLocationResult.failure(
            LocationPermissionStatus.permanentlyDenied,
            message: 'Izin lokasi ditolak permanen.',
          ),
        );
        final mockReverse = MockReverseGeocodingService();

        final notifier = LocationNotifier(
          locationService: mockLocation,
          reverseGeocodingService: mockReverse,
          initialState: LocationState.unresolved(),
        );

        await notifier.detectDeviceLocation();

        expect(
          notifier.state.permissionStatus,
          LocationPermissionStatus.permanentlyDenied,
        );
        expect(notifier.state.label, 'Pilih Lokasi (Izin Dinonaktifkan)');

        final opened = await notifier.openAppSettings();
        expect(opened, true);
        expect(mockLocation.appSettingsOpened, true);
      },
    );

    test(
      '1.4 Location service disabled updates state and delegates to openLocationSettings',
      () async {
        final mockLocation = MockDeviceLocationService(
          nextResult: DeviceLocationResult.failure(
            LocationPermissionStatus.serviceDisabled,
            message: 'GPS mati.',
          ),
        );
        final mockReverse = MockReverseGeocodingService();

        final notifier = LocationNotifier(
          locationService: mockLocation,
          reverseGeocodingService: mockReverse,
          initialState: LocationState.unresolved(),
        );

        await notifier.detectDeviceLocation();

        expect(
          notifier.state.permissionStatus,
          LocationPermissionStatus.serviceDisabled,
        );
        expect(notifier.state.label, 'Pilih Lokasi (GPS Mati)');

        final opened = await notifier.openLocationSettings();
        expect(opened, true);
        expect(mockLocation.locationSettingsOpened, true);
      },
    );

    test(
      '1.5 GPS timeout safely terminates without indefinite loading',
      () async {
        final mockLocation = MockDeviceLocationService(
          nextResult: DeviceLocationResult.failure(
            LocationPermissionStatus.timeout,
            message: 'Waktu pencarian GPS habis.',
          ),
        );
        final mockReverse = MockReverseGeocodingService();

        final notifier = LocationNotifier(
          locationService: mockLocation,
          reverseGeocodingService: mockReverse,
          initialState: LocationState.unresolved(),
        );

        await notifier.detectDeviceLocation();

        expect(notifier.state.isLoading, false);
        expect(
          notifier.state.permissionStatus,
          LocationPermissionStatus.timeout,
        );
        expect(notifier.state.errorMessage, 'Waktu pencarian GPS habis.');
        expect(notifier.state.hasSelectedLocation, false);
      },
    );

    test('1.6 Approximate (coarse) location is correctly flagged', () async {
      final mockLocation = MockDeviceLocationService(
        nextResult: DeviceLocationResult.success(
          const GeoCoordinates(-6.9175, 107.6191),
          isApproximate: true,
        ),
      );
      final mockReverse = MockReverseGeocodingService(
        resolvedAddress: 'Bandung',
      );

      final notifier = LocationNotifier(
        locationService: mockLocation,
        reverseGeocodingService: mockReverse,
      );

      await notifier.detectDeviceLocation();

      expect(notifier.state.isApproximate, true);
      expect(notifier.state.label, 'Bandung');
      expect(notifier.state.coordinates.latitude, -6.9175);
    });

    test(
      '1.7 Valid GPS coordinates outside Jakarta/Indonesia (e.g. Mountain View) are preserved as-is and never replaced',
      () async {
        const mountainView = GeoCoordinates(37.4219983, -122.084);
        final mockLocation = MockDeviceLocationService(
          nextResult: DeviceLocationResult.success(
            mountainView,
            isApproximate: false,
          ),
        );
        final mockReverse = MockReverseGeocodingService(
          resolvedAddress: 'Mountain View, California',
        );

        final notifier = LocationNotifier(
          locationService: mockLocation,
          reverseGeocodingService: mockReverse,
        );

        await notifier.detectDeviceLocation();

        expect(notifier.state.source, LocationSource.deviceGps);
        expect(
          notifier.state.permissionStatus,
          LocationPermissionStatus.granted,
        );
        expect(notifier.state.coordinates, mountainView);
        expect(notifier.state.coordinates.latitude, 37.4219983);
        expect(notifier.state.coordinates.longitude, -122.084);
        expect(notifier.state.label, 'Mountain View, California');
      },
    );
  });

  group('Location selection integrity and recovery', () {
    test(
      'discovery waits for an explicit selection, including after denial',
      () async {
        final repository = RecordingLocationPlaceRepository();
        final notifier = LocationNotifier(
          locationService: MockDeviceLocationService(
            nextResult: DeviceLocationResult.failure(
              LocationPermissionStatus.denied,
            ),
          ),
          reverseGeocodingService: MockReverseGeocodingService(),
          initialState: LocationState.unresolved(),
        );
        final container = ProviderContainer(
          overrides: [
            currentLocationProvider.overrideWith((ref) => notifier),
            placeRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        expect(await container.read(nearbyPlacesProvider.future), isEmpty);
        expect(repository.origins, isEmpty);
        await notifier.detectDeviceLocation();
        expect(await container.read(nearbyPlacesProvider.future), isEmpty);
        expect(repository.origins, isEmpty);

        notifier.setManualLocation(
          AppLocation.defaultJakarta,
          AppLocation.defaultJakartaLabel,
        );

        expect(await container.read(nearbyPlacesProvider.future), isEmpty);
        expect(repository.origins, [AppLocation.defaultJakarta]);
      },
    );

    test('unresolved state does not claim a selected city', () {
      final state = LocationState.unresolved();

      expect(state.hasSelectedLocation, false);
      expect(state.source, isNot(LocationSource.manual));
      expect(state.label, 'Pilih Lokasi');
      expect(state.isMock, false);
    });

    test('successful GPS retry clears the previous failure', () async {
      final location = MockDeviceLocationService(
        nextResult: DeviceLocationResult.failure(
          LocationPermissionStatus.denied,
          message: 'Izin ditolak.',
        ),
      );
      final notifier = LocationNotifier(
        locationService: location,
        reverseGeocodingService: MockReverseGeocodingService(
          resolvedAddress: 'Bandung',
        ),
        initialState: LocationState.unresolved(),
      );
      addTearDown(notifier.dispose);
      await notifier.detectDeviceLocation();
      expect(notifier.state.errorMessage, isNotNull);

      location.nextResult = DeviceLocationResult.success(AppLocation.bandung);
      await notifier.detectDeviceLocation();

      expect(notifier.state.coordinates, AppLocation.bandung);
      expect(notifier.state.hasSelectedLocation, true);
      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.permissionStatus, LocationPermissionStatus.granted);
    });

    test('manual selection clears errors and approximate GPS status', () {
      final notifier = LocationNotifier(
        locationService: MockDeviceLocationService(),
        reverseGeocodingService: MockReverseGeocodingService(),
        initialState: const LocationState(
          coordinates: GeoCoordinates(37.4219983, -122.084),
          label: 'Mountain View',
          source: LocationSource.deviceGps,
          isApproximate: true,
          errorMessage: 'GPS timeout',
        ),
      );
      addTearDown(notifier.dispose);

      notifier.setManualLocation(AppLocation.bandung, AppLocation.bandungLabel);

      expect(notifier.state.source, LocationSource.manual);
      expect(notifier.state.coordinates, AppLocation.bandung);
      expect(notifier.state.hasSelectedLocation, true);
      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.isApproximate, false);
    });

    test(
      'failed GPS request preserves a previously selected manual city',
      () async {
        final notifier = LocationNotifier(
          locationService: MockDeviceLocationService(
            nextResult: DeviceLocationResult.failure(
              LocationPermissionStatus.denied,
            ),
          ),
          reverseGeocodingService: MockReverseGeocodingService(),
          initialState: LocationState.unresolved(),
        );
        addTearDown(notifier.dispose);
        notifier.setManualLocation(
          AppLocation.bandung,
          AppLocation.bandungLabel,
        );

        await notifier.detectDeviceLocation();

        expect(notifier.state.coordinates, AppLocation.bandung);
        expect(notifier.state.label, AppLocation.bandungLabel);
        expect(notifier.state.source, LocationSource.manual);
        expect(notifier.state.hasSelectedLocation, true);
      },
    );

    test(
      'pending GPS result cannot replace a later manual selection',
      () async {
        final result = Completer<DeviceLocationResult>();
        final location = MockDeviceLocationService()
          ..onGetCurrentLocation = () => result.future;
        final notifier = LocationNotifier(
          locationService: location,
          reverseGeocodingService: MockReverseGeocodingService(),
          initialState: LocationState.unresolved(),
        );
        addTearDown(notifier.dispose);
        final detection = notifier.detectDeviceLocation();

        notifier.setManualLocation(
          AppLocation.bandung,
          AppLocation.bandungLabel,
        );
        result.complete(
          DeviceLocationResult.success(
            const GeoCoordinates(37.4219983, -122.084),
          ),
        );
        await detection;

        expect(notifier.state.coordinates, AppLocation.bandung);
        expect(notifier.state.label, AppLocation.bandungLabel);
        expect(notifier.state.source, LocationSource.manual);
        expect(notifier.state.isLoading, false);
      },
    );

    test(
      'pending reverse geocoding cannot replace a later manual selection',
      () async {
        final geocodingStarted = Completer<void>();
        final label = Completer<String?>();
        final reverse = MockReverseGeocodingService()
          ..onReverseGeocode = (_) {
            geocodingStarted.complete();
            return label.future;
          };
        final notifier = LocationNotifier(
          locationService: MockDeviceLocationService(),
          reverseGeocodingService: reverse,
          initialState: LocationState.unresolved(),
        );
        addTearDown(notifier.dispose);
        final detection = notifier.detectDeviceLocation();
        await geocodingStarted.future;

        notifier.setManualLocation(
          AppLocation.bandung,
          AppLocation.bandungLabel,
        );
        label.complete('Jakarta Selatan');
        await detection;

        expect(notifier.state.coordinates, AppLocation.bandung);
        expect(notifier.state.label, AppLocation.bandungLabel);
        expect(notifier.state.source, LocationSource.manual);
      },
    );

    test(
      'a forced newer GPS request wins when the older request finishes last',
      () async {
        final requests = <Completer<DeviceLocationResult>>[];
        final location = MockDeviceLocationService()
          ..onGetCurrentLocation = () {
            final request = Completer<DeviceLocationResult>();
            requests.add(request);
            return request.future;
          };
        final notifier = LocationNotifier(
          locationService: location,
          reverseGeocodingService: MockReverseGeocodingService(
            resolvedAddress: 'Mountain View',
          ),
          initialState: LocationState.unresolved(),
        );
        addTearDown(notifier.dispose);
        final older = notifier.detectDeviceLocation();
        final newer = notifier.detectDeviceLocation(force: true);
        const mountainView = GeoCoordinates(37.4219983, -122.084);

        requests[1].complete(DeviceLocationResult.success(mountainView));
        await newer;
        requests[0].complete(
          DeviceLocationResult.success(AppLocation.defaultJakarta),
        );
        await older;

        expect(notifier.state.coordinates, mountainView);
        expect(notifier.state.label, 'Mountain View');
        expect(notifier.state.source, LocationSource.deviceGps);
      },
    );

    test(
      'disposing during GPS acquisition safely discards the result',
      () async {
        final result = Completer<DeviceLocationResult>();
        final location = MockDeviceLocationService()
          ..onGetCurrentLocation = () => result.future;
        final notifier = LocationNotifier(
          locationService: location,
          reverseGeocodingService: MockReverseGeocodingService(),
          initialState: LocationState.unresolved(),
        );
        final detection = notifier.detectDeviceLocation();
        notifier.dispose();

        result.complete(DeviceLocationResult.success(AppLocation.bandung));

        await expectLater(detection, completes);
      },
    );

    test(
      'unexpected device errors stop loading without exposing exception text',
      () async {
        final location = MockDeviceLocationService()
          ..onGetCurrentLocation = () async =>
              throw Exception('sensitive transport text');
        final notifier = LocationNotifier(
          locationService: location,
          reverseGeocodingService: MockReverseGeocodingService(),
          initialState: LocationState.unresolved(),
        );
        addTearDown(notifier.dispose);

        await notifier.detectDeviceLocation();

        expect(notifier.state.isLoading, false);
        expect(notifier.state.permissionStatus, LocationPermissionStatus.error);
        expect(notifier.state.hasSelectedLocation, false);
        expect(
          notifier.state.errorMessage,
          isNot(contains('sensitive transport text')),
        );
      },
    );
  });

  group('2. Reverse Geocoding & Label Formatting', () {
    test('transport failures do not log a keyed request URI', () async {
      final messages = <String>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) =>
          messages.add(message ?? '');
      addTearDown(() => debugPrint = previousDebugPrint);
      final service = GeoapifyReverseGeocodingService(
        apiKey: 'secret-regression-test-key',
        client: MockClient((request) async {
          throw http.ClientException('connection failed', request.url);
        }),
      );

      expect(await service.reverseGeocode(AppLocation.bandung), isNull);
      expect(
        messages.join('\n'),
        isNot(contains('secret-regression-test-key')),
      );
      expect(messages.join('\n'), isNot(contains('apiKey=')));
    });

    test(
      '2.1 ReverseGeocodingService formats suburb and city from Geoapify response',
      () async {
        final mockHttpClient = MockClient((request) async {
          expect(request.url.path, '/v1/geocode/reverse');
          final responsePayload = {
            'type': 'FeatureCollection',
            'features': [
              {
                'properties': {
                  'suburb': 'Cengkareng',
                  'city': 'Jakarta Barat',
                  'state': 'DKI Jakarta',
                  'country': 'Indonesia',
                },
              },
            ],
          };
          return http.Response(jsonEncode(responsePayload), 200);
        });

        final service = GeoapifyReverseGeocodingService(
          client: mockHttpClient,
          apiKey: 'test-api-key',
        );

        final label = await service.reverseGeocode(
          const GeoCoordinates(-6.1550, 106.7200),
        );
        expect(label, 'Cengkareng, Jakarta Barat');
      },
    );

    test(
      '2.2 ReverseGeocodingService caches close coordinates to prevent duplicate API hits',
      () async {
        int requestCount = 0;
        final mockHttpClient = MockClient((request) async {
          requestCount++;
          final responsePayload = {
            'features': [
              {
                'properties': {'city': 'Depok', 'state': 'Jawa Barat'},
              },
            ],
          };
          return http.Response(jsonEncode(responsePayload), 200);
        });

        final service = GeoapifyReverseGeocodingService(
          client: mockHttpClient,
          apiKey: 'test-api-key',
        );

        // Point 1
        final label1 = await service.reverseGeocode(
          const GeoCoordinates(-6.4021, 106.7941),
        );
        // Point 2 (~30 meters away, rounds to same 3-decimal cache key: -6.402,106.794)
        final label2 = await service.reverseGeocode(
          const GeoCoordinates(-6.4024, 106.7944),
        );

        expect(label1, 'Depok');
        expect(label2, 'Depok');
        expect(
          requestCount,
          1,
          reason: 'Cache hit should prevent second network request',
        );
      },
    );

    test(
      '2.3 Geocoding failure falls back to neutral label without inventing address',
      () async {
        final mockLocation = MockDeviceLocationService(
          nextResult: DeviceLocationResult.success(
            const GeoCoordinates(-6.2297, 106.8295),
          ),
        );
        final mockReverse = MockReverseGeocodingService(shouldThrow: true);

        final notifier = LocationNotifier(
          locationService: mockLocation,
          reverseGeocodingService: mockReverse,
        );

        await notifier.detectDeviceLocation();

        expect(notifier.state.label, 'Lokasi Terdeteksi');
      },
    );
  });

  group('3. Geoapify Nearby Search & Query Generation', () {
    test(
      '3.1 Nearby Places generates circle:lon,lat,radius with correct syntax',
      () async {
        Uri? capturedUri;
        final mockHttpClient = MockClient((request) async {
          capturedUri = request.url;
          final responsePayload = {
            'type': 'FeatureCollection',
            'features': <dynamic>[],
          };
          return http.Response(jsonEncode(responsePayload), 200);
        });

        final dataSource = HttpGeoapifyPlacesDataSource(
          client: mockHttpClient,
          apiKey: 'test-api-key',
        );

        await dataSource.fetchNearbyPlaces(
          location: const GeoCoordinates(-6.2297, 106.8295),
          radiusMeters: 5000,
        );

        expect(capturedUri, isNotNull);
        final filterParam = capturedUri!.queryParameters['filter'];
        final biasParam = capturedUri!.queryParameters['bias'];

        // Must be circle:lon,lat,radiusMeters
        expect(filterParam, 'circle:106.829500,-6.229700,5000');
        expect(biasParam, 'proximity:106.829500,-6.229700');
      },
    );
  });

  group('4. Distance Calculation & Formatting', () {
    test(
      '4.1 Haversine distance calculates accurate km between Jakarta landmarks',
      () {
        const monas = GeoCoordinates(-6.1754, 106.8272);
        const gbk = GeoCoordinates(-6.2186, 106.8026);

        final distanceKm = monas.distanceKmTo(gbk);
        // Actual geographic distance is approximately 5.5 km
        expect(distanceKm, greaterThan(5.0));
        expect(distanceKm, lessThan(6.0));
      },
    );

    test(
      '4.2 Place.distanceLabel formats meters and kilometers appropriately',
      () {
        final closePlace = Place(
          id: 'p1',
          source: PlaceSource.manual,
          name: 'Cafe Dekat',
          category: 'Cafe',
          address: 'Jl. Tebet',
          latitude: -6.2297,
          longitude: 106.8295,
          distanceKm: 0.45,
          studyScore: 9.0,
        );
        expect(closePlace.distanceLabel, '450 m');

        final farPlace = Place(
          id: 'p2',
          source: PlaceSource.manual,
          name: 'Coworking Jauh',
          category: 'Coworking',
          address: 'Jl. Sudirman',
          latitude: -6.2100,
          longitude: 106.8200,
          distanceKm: 2.34,
          studyScore: 9.5,
        );
        expect(farPlace.distanceLabel, '2.3 km');
      },
    );
  });

  group('5. Location Fallback, Refresh & Manual Selection', () {
    test(
      '5.1 Manual city selection updates coordinates and sets source to manual',
      () {
        final mockLocation = MockDeviceLocationService();
        final mockReverse = MockReverseGeocodingService();

        final notifier = LocationNotifier(
          locationService: mockLocation,
          reverseGeocodingService: mockReverse,
        );

        notifier.setManualLocation(
          AppLocation.bandung,
          AppLocation.bandungLabel,
        );

        expect(notifier.state.source, LocationSource.manual);
        expect(notifier.state.coordinates, AppLocation.bandung);
        expect(notifier.state.label, AppLocation.bandungLabel);
        expect(notifier.state.isMock, false);
        expect(
          notifier.state.permissionStatus,
          LocationPermissionStatus.granted,
        );
      },
    );

    test('5.2 Sleman preset is explicitly marked as demo / mock mode', () {
      final mockLocation = MockDeviceLocationService();
      final mockReverse = MockReverseGeocodingService();

      final notifier = LocationNotifier(
        locationService: mockLocation,
        reverseGeocodingService: mockReverse,
      );

      notifier.setManualLocation(
        AppLocation.mockYogyakartaOrigin,
        AppLocation.mockYogyakartaLabel,
      );

      expect(notifier.state.isMock, true);
      expect(notifier.state.label, AppLocation.mockYogyakartaLabel);
    });
  });

  group('6. HomeScreen Location UI & Fallback Banner Widgets', () {
    testWidgets(
      '6.1 Location header reflects active label and opens picker sheet',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockLocation = MockDeviceLocationService(
          nextResult: DeviceLocationResult.success(
            const GeoCoordinates(-6.2297, 106.8295),
          ),
        );
        final mockReverse = MockReverseGeocodingService(
          resolvedAddress: 'Tebet, Jakarta Selatan',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deviceLocationServiceProvider.overrideWithValue(mockLocation),
              reverseGeocodingServiceProvider.overrideWithValue(mockReverse),
              currentLocationProvider.overrideWith((ref) {
                return LocationNotifier(
                  locationService: mockLocation,
                  reverseGeocodingService: mockReverse,
                  initialState: const LocationState(
                    coordinates: GeoCoordinates(-6.2297, 106.8295),
                    label: 'Tebet, Jakarta Selatan',
                    source: LocationSource.deviceGps,
                    permissionStatus: LocationPermissionStatus.granted,
                  ),
                );
              }),
            ],
            child: const MaterialApp(home: HomeScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Verify header reflects location
        expect(find.text('Tebet, Jakarta Selatan'), findsOneWidget);

        // Tap on the location header
        await tester.tap(find.text('Tebet, Jakarta Selatan'));
        await tester.pumpAndSettle();

        // Verify bottom sheet modal opens with options
        expect(find.text('Pilih Lokasi Nugas'), findsOneWidget);
        expect(find.text('Lokasi Saat Ini (GPS)'), findsOneWidget);
        expect(find.text(AppLocation.bandungLabel), findsOneWidget);
        expect(find.text(AppLocation.depokLabel), findsOneWidget);
        expect(find.text(AppLocation.mockYogyakartaLabel), findsOneWidget);

        // Select Bandung preset
        await tester.tap(find.text(AppLocation.bandungLabel));
        await tester.pumpAndSettle();

        // Modal closed and header updated to Bandung
        expect(find.text(AppLocation.bandungLabel), findsOneWidget);
      },
    );

    testWidgets(
      '6.2 Notice banner appears when location permission is denied and allows retry',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockLocation = MockDeviceLocationService(
          nextResult: DeviceLocationResult.failure(
            LocationPermissionStatus.denied,
            message: 'Izin ditolak.',
          ),
        );
        final mockReverse = MockReverseGeocodingService();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deviceLocationServiceProvider.overrideWithValue(mockLocation),
              reverseGeocodingServiceProvider.overrideWithValue(mockReverse),
              currentLocationProvider.overrideWith((ref) {
                final notifier = LocationNotifier(
                  locationService: mockLocation,
                  reverseGeocodingService: mockReverse,
                  initialState: const LocationState(
                    coordinates: AppLocation.defaultJakarta,
                    label: 'Pilih Lokasi (Izin Ditolak)',
                    permissionStatus: LocationPermissionStatus.denied,
                    source: LocationSource.demoFallback,
                  ),
                );
                return notifier;
              }),
            ],
            child: const MaterialApp(home: HomeScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Notice banner should be visible
        expect(find.text('Izin Lokasi Belum Aktif'), findsOneWidget);
        expect(find.text('Aktifkan'), findsOneWidget);
        expect(find.text('Pilih Lokasi (Izin Ditolak)'), findsOneWidget);

        // Never shows Jakarta Selatan as detected GPS location
        expect(find.text('Jakarta Selatan'), findsNothing);
      },
    );
  });
}
