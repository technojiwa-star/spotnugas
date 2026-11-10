import 'package:flutter_test/flutter_test.dart';
import 'package:spot_nugas/config/places_api_config.dart';
import 'package:spot_nugas/constants/app_location.dart';
import 'package:spot_nugas/datasources/google_places_data_source.dart';
import 'package:spot_nugas/models/google_attribution.dart';
import 'package:spot_nugas/models/google_place_data.dart';
import 'package:spot_nugas/models/place.dart';
import 'package:spot_nugas/models/place_data_state.dart';
import 'package:spot_nugas/models/spotnugas_place_data.dart';
import 'package:spot_nugas/providers/location_provider.dart';
import 'package:spot_nugas/repositories/mock_place_repository.dart';
import 'package:spot_nugas/repositories/place_repository.dart';
import 'package:spot_nugas/utils/place_merger.dart';

void main() {
  group('PlacesApiConfig Security & Quota Guardrails', () {
    test('safe offline default when no API key is injected', () {
      expect(PlacesApiConfig.hasApiKey, isFalse);
      expect(PlacesApiConfig.apiKey, isEmpty);
    });

    test(
      'field masks distinguish low-cost Pro from Enterprise SKUs and omit reviews',
      () {
        final proNearby = PlacesApiConfig.nearbySearchProFieldMask;
        final entNearby = PlacesApiConfig.nearbySearchEnterpriseFieldMask;
        final proDetails = PlacesApiConfig.placeDetailsProFieldMask;
        final entDetails = PlacesApiConfig.placeDetailsEnterpriseFieldMask;

        // Pro Nearby Search: contains identity + photos, NO Enterprise fields (rating/hours)
        expect(proNearby, contains('places.id'));
        expect(proNearby, contains('places.displayName'));
        expect(proNearby, contains('places.photos'));
        expect(proNearby, isNot(contains('places.rating')));
        expect(proNearby, isNot(contains('places.regularOpeningHours')));
        expect(proNearby, isNot(contains('places.reviews')));

        // Enterprise Nearby Search: contains rating & hours, NO reviews
        expect(entNearby, contains('places.id'));
        expect(entNearby, contains('places.rating'));
        expect(entNearby, contains('places.regularOpeningHours'));
        expect(entNearby, isNot(contains('places.reviews')));

        // Pro Details: contains basic fields + photos, NO enterprise fields
        expect(proDetails, contains('id'));
        expect(proDetails, contains('displayName'));
        expect(proDetails, contains('photos'));
        expect(proDetails, isNot(contains('rating')));

        // Enterprise Details: contains rating & price range, NO reviews
        expect(entDetails, contains('id'));
        expect(entDetails, contains('rating'));
        expect(entDetails, contains('priceRange'));
        expect(entDetails, isNot(contains('reviews')));
      },
    );

    test('throttling and caching constants protect against quota runaway', () {
      expect(
        PlacesApiConfig.searchDebounceDuration.inMilliseconds,
        equals(400),
      );
      expect(PlacesApiConfig.minSearchQueryLength, equals(3));
      expect(PlacesApiConfig.defaultSearchRadiusMeters, equals(5000.0));
      expect(PlacesApiConfig.inMemoryCacheTtl.inMinutes, equals(15));
      expect(PlacesApiConfig.maxPhotosPerPlace, equals(2));
    });
  });

  group('GoogleAttribution Policy Compliance Model', () {
    test('parses attribution from JSON and formats correctly', () {
      final json = {
        'displayName': 'Ahmad Fauzi',
        'uri': 'https://maps.google.com/contrib/12345',
        'photoUri': 'https://lh3.googleusercontent.com/p/photo123',
      };

      final attr = GoogleAttribution.fromJson(json);
      expect(attr.displayName, equals('Ahmad Fauzi'));
      expect(attr.uri, equals('https://maps.google.com/contrib/12345'));
      expect(
        attr.photoUri,
        equals('https://lh3.googleusercontent.com/p/photo123'),
      );

      final serialized = attr.toJson();
      expect(serialized['displayName'], equals('Ahmad Fauzi'));
      expect(
        serialized['uri'],
        equals('https://maps.google.com/contrib/12345'),
      );
    });
  });

  group('AppLocation: Jakarta Target vs Mock Yogyakarta Origin', () {
    test('default Jakarta location is centered in Jakarta Selatan', () {
      expect(AppLocation.defaultJakarta.latitude, closeTo(-6.2297, 0.01));
      expect(AppLocation.defaultJakarta.longitude, closeTo(106.8295, 0.01));
      expect(AppLocation.defaultJakartaLabel, equals('Jakarta Selatan'));

      final state = LocationState.jakarta();
      expect(
        state.coordinates.latitude,
        equals(AppLocation.defaultJakarta.latitude),
      );
      expect(state.label, equals('Jakarta Selatan'));
      expect(state.isMock, isFalse);
    });

    test(
      'mock Yogyakarta origin is explicitly marked for test and seed data',
      () {
        expect(
          AppLocation.mockYogyakartaOrigin.latitude,
          closeTo(-7.7545, 0.01),
        );
        expect(
          AppLocation.mockYogyakartaOrigin.longitude,
          closeTo(110.3830, 0.01),
        );
        expect(AppLocation.mockYogyakartaLabel, contains('Sleman'));

        final state = LocationState.mockYogyakarta();
        expect(state.isMock, isTrue);
        expect(state.label, equals(AppLocation.mockYogyakartaLabel));
      },
    );
  });

  group('PlaceDataState Union & Helper Verification', () {
    test('verifies PlaceDataLoading', () {
      const state = PlaceDataLoading<List<Place>>(message: 'Memuat tempat...');
      expect(state.isLoading, isTrue);
      expect(state.isSuccess, isFalse);
      expect(state.dataOrNull, isNull);
      expect(state.message, equals('Memuat tempat...'));
    });

    test('verifies PlaceDataSuccess', () {
      final dummyPlace = Place(
        id: 'p-1',
        source: PlaceSource.google,
        googlePlaceId: 'gp-1',
        name: 'Test Coffee',
        category: 'Cafe',
        latitude: -6.2,
        longitude: 106.8,
      );
      final state = PlaceDataSuccess<List<Place>>([dummyPlace]);
      expect(state.isSuccess, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.dataOrNull?.length, equals(1));
    });

    test('verifies PlaceDataEmpty', () {
      const state = PlaceDataEmpty<List<Place>>();
      expect(state.isEmpty, isTrue);
      expect(state.dataOrNull, isNull);
      expect(state.message, contains('Tidak ada tempat nugas'));
    });

    test('verifies PlaceDataOffline', () {
      final state = PlaceDataOffline<List<Place>>([], cachedAt: DateTime.now());
      expect(state.isOffline, isTrue);
      expect(state.dataOrNull, isEmpty);
    });

    test('verifies PlaceDataError', () {
      const state = PlaceDataError<List<Place>>(
        message: 'Gagal menghubungi server',
        canRetry: true,
      );
      expect(state.isError, isTrue);
      expect(state.canRetry, isTrue);
    });
  });

  group(
    'PlaceMerger: Deduplication, Overlay Matching, and Partner Independence',
    () {
      final google1 = GooglePlaceData(
        googlePlaceId: 'ChIJ_GOOGLE_ONLY_001',
        name: 'Kopi Publik Tanpa Akun Partner',
        location: const GeoCoordinates(-6.22, 106.82),
        formattedAddress: 'Jl. Senopati No. 1, Jakarta Selatan',
        rating: 4.6,
        userRatingCount: 80,
      );

      final google2 = GooglePlaceData(
        googlePlaceId: 'ChIJ_GOOGLE_WITH_OVERLAY_002',
        name: 'Kafe Partner SpotNugas',
        location: const GeoCoordinates(-6.23, 106.83),
        formattedAddress: 'Jl. Suryo No. 12, Jakarta Selatan',
        rating: 4.8,
        userRatingCount: 150,
      );

      final overlay2 = SpotNugasPlaceData.google(
        placeId: 'sn-partner-kafe',
        googlePlaceId: 'ChIJ_GOOGLE_WITH_OVERLAY_002',
        category: 'Coworking Cafe',
        studyScore: 9.4,
        wifiScore: 4.9,
        outletScore: 4.7,
        facilities: [PlaceFacility.wifi, PlaceFacility.powerOutlet],
        tags: ['Wi-Fi Cepat', 'Banyak Colokan'],
        isVerifiedPartner: true,
      );

      final manualPlace = SpotNugasPlaceData.manual(
        placeId: 'sn-manual-library',
        name: 'Perpustakaan Komunitas',
        address: 'Jl. Tebet Barat No. 5',
        location: const GeoCoordinates(-6.24, 106.85),
        category: 'Public Library',
        studyScore: 9.6,
        facilities: [PlaceFacility.quietZone],
        verificationStatus: PlaceVerificationStatus.verified,
      );

      final inactiveManual = SpotNugasPlaceData.manual(
        placeId: 'sn-inactive-spot',
        name: 'Tempat Tutup Permanen',
        address: 'Jl. Hantu',
        location: const GeoCoordinates(-6.25, 106.86),
        isActive: false,
      );

      test('public Google place without partner account appears cleanly', () {
        final merged = PlaceMerger.merge(
          googlePlaces: [google1],
          spotNugasPlaces: [],
        );

        expect(merged.length, equals(1));
        final place = merged.first;
        expect(place.id, equals('ChIJ_GOOGLE_ONLY_001'));
        expect(place.source, equals(PlaceSource.google));
        expect(place.name, equals('Kopi Publik Tanpa Akun Partner'));
        expect(place.isVerifiedPartner, isFalse);
        expect(place.hasSpotNugasData, isFalse);
      });

      test(
        'Google place with SpotNugas overlay is enriched with productivity data',
        () {
          final merged = PlaceMerger.merge(
            googlePlaces: [google2],
            spotNugasPlaces: [overlay2],
          );

          expect(merged.length, equals(1));
          final place = merged.first;
          expect(place.id, equals('sn-partner-kafe'));
          expect(place.googlePlaceId, equals('ChIJ_GOOGLE_WITH_OVERLAY_002'));
          expect(place.isVerifiedPartner, isTrue);
          expect(place.resolvedStudyScore, equals(9.4));
          expect(place.wifiScoreVal, equals(4.9));
          expect(place.facilities, contains(PlaceFacility.wifi));
        },
      );

      test(
        'manual SpotNugas places are preserved without Google data, inactive skipped',
        () {
          final merged = PlaceMerger.merge(
            googlePlaces: [],
            spotNugasPlaces: [manualPlace, inactiveManual],
          );

          expect(merged.length, equals(1));
          final place = merged.first;
          expect(place.id, equals('sn-manual-library'));
          expect(place.isManual, isTrue);
          expect(place.name, equals('Perpustakaan Komunitas'));
        },
      );

      test('deduplicates multiple Google Places with the same ID', () {
        final merged = PlaceMerger.merge(
          googlePlaces: [google1, google1, google1],
          spotNugasPlaces: [],
        );

        expect(merged.length, equals(1));
      });

      test('computes distance when origin is provided', () {
        const origin = GeoCoordinates(-6.2000, 106.8000);
        final merged = PlaceMerger.merge(
          googlePlaces: [google1],
          spotNugasPlaces: [],
          origin: origin,
        );

        expect(merged.first.distanceKm, isNotNull);
        expect(merged.first.distanceKm!, greaterThan(0.0));
      });
    },
  );

  group('MockGooglePlacesDataSource Offline Simulation', () {
    const dataSource = MockGooglePlacesDataSource();

    test('searchNearby returns places within radius without network', () async {
      final places = await dataSource.searchNearby(
        location: AppLocation.mockYogyakartaOrigin,
        radiusMeters: 5000.0,
      );

      expect(places, isNotEmpty);
      for (final p in places) {
        expect(p.googlePlaceId, isNotEmpty);
        expect(p.name, isNotEmpty);
      }
    });

    test('searchByText finds matching places by name', () async {
      final results = await dataSource.searchByText('Kopi Ruang');
      expect(results.length, equals(1));
      expect(results.first.name, contains('Kopi Ruang'));
    });

    test('getPlaceDetails finds place by googlePlaceId', () async {
      final place = await dataSource.getPlaceDetails('mock-gplace-kopi-ruang');
      expect(place, isNotNull);
      expect(place!.name, equals('Kopi Ruang'));

      final nonExistent = await dataSource.getPlaceDetails('fake-id-999');
      expect(nonExistent, isNull);
    });
  });

  group('Distance Isolation: Mock Yogyakarta vs Real Jakarta Queries', () {
    final repo = MockPlaceRepository();

    test(
      'getNearbyPlaces from Jakarta returns empty list (does NOT show Sleman places)',
      () async {
        final nearbyInJakarta = await repo.getNearbyPlaces(
          origin: AppLocation.defaultJakarta,
          radiusKm: 5.0,
        );

        // Must be empty because Yogyakarta is ~440 km from Jakarta
        expect(nearbyInJakarta, isEmpty);
      },
    );

    test(
      'getNearbyPlaces from mock Yogyakarta origin returns mock seed spots',
      () async {
        final nearbyInYogya = await repo.getNearbyPlaces(
          origin: AppLocation.mockYogyakartaOrigin,
          radiusKm: 5.0,
        );

        expect(nearbyInYogya, isNotEmpty);
        expect(nearbyInYogya.first.distanceKm, lessThan(5.0));
      },
    );

    test(
      'searchPlaces from Jakarta computes real geographic distance (>400 km)',
      () async {
        final results = await repo.searchPlaces(
          const PlaceSearchQuery(
            text: 'Kopi Ruang',
            origin: AppLocation.defaultJakarta,
          ),
        );

        expect(results.length, equals(1));
        final place = results.first;
        // Distance from Jakarta to Yogyakarta must be around 440 km, never 850m
        expect(place.distanceKm, greaterThan(400.0));
        expect(place.distanceLabel, contains('km'));
      },
    );
  });
}
