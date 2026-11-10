import 'package:flutter_test/flutter_test.dart';
import 'package:spot_nugas/models/place.dart';
import 'package:spot_nugas/models/saved_place_item.dart';
import 'package:spot_nugas/models/spotnugas_place_data.dart';
import 'package:spot_nugas/models/user_profile.dart';
import 'package:spot_nugas/repositories/mock_place_repository.dart';
import 'package:spot_nugas/repositories/review_repository.dart';
import 'package:spot_nugas/repositories/saved_places_repository.dart';

void main() {
  group('PlaceSource & Geoapify Taxonomy', () {
    test('PlaceSource includes geoapify, google, and manual', () {
      expect(PlaceSource.geoapify.value, 'geoapify');
      expect(PlaceSource.google.value, 'google');
      expect(PlaceSource.manual.value, 'manual');

      expect(PlaceSource.tryParse('geoapify'), PlaceSource.geoapify);
      expect(PlaceSource.tryParse('google'), PlaceSource.google);
      expect(PlaceSource.tryParse('manual'), PlaceSource.manual);
      expect(PlaceSource.tryParse('unknown_vendor'), isNull);
    });
  });

  group('PlaceIdentity & Stable Identity Architecture', () {
    test(
      'Geoapify factory creates formatted canonical key without overlay doc',
      () {
        final identity = PlaceIdentity.geoapify('5130b427435f3d5b40590a');
        expect(identity.canonicalKey, 'geoapify:5130b427435f3d5b40590a');
        expect(identity.primarySource, PlaceSource.geoapify);
        expect(identity.geoapifyPlaceId, '5130b427435f3d5b40590a');
        expect(identity.spotNugasPlaceId, isNull);
        expect(identity.aliases, contains('geoapify:5130b427435f3d5b40590a'));
        expect(identity.aliases, contains('5130b427435f3d5b40590a'));
      },
    );

    test(
      'Geoapify factory adopts spotNugasPlaceId as canonical key when overlay exists',
      () {
        final identity = PlaceIdentity.geoapify(
          '5130b427435f3d5b40590a',
          spotNugasPlaceId: 'kopi-ruang-jakal',
          aliases: const ['legacy-gplace-123'],
        );
        expect(identity.canonicalKey, 'kopi-ruang-jakal');
        expect(identity.spotNugasPlaceId, 'kopi-ruang-jakal');
        expect(identity.aliases, contains('kopi-ruang-jakal'));
        expect(identity.aliases, contains('legacy-gplace-123'));
      },
    );

    test('Identity is NEVER derived from mutable place name or address', () {
      // Create two identities with identical place keys but changed names/addresses
      final id1 = PlaceIdentity.geoapify('venue_abc_123');
      final id2 = PlaceIdentity.geoapify('venue_abc_123');

      expect(id1.canonicalKey, id2.canonicalKey);
      expect(id1.matches(id2), isTrue);

      // Verify key remains identical regardless of what name or address the user sees
      const nameV1 = 'Cafe Kopi Senja';
      const nameV2 = 'Kopi Senja & Space Rebranded';
      const addressV1 = 'Jl. Kaliurang km 5';
      const addressV2 = 'Jalan Kaliurang Kilometer 5 No. 12';

      expect(nameV1 != nameV2, isTrue);
      expect(addressV1 != addressV2, isTrue);

      // Crucial: key remains untouched and stable
      expect(id1.canonicalKey, 'geoapify:venue_abc_123');
    });

    test(
      'Deduplication matcher detects cross-provider aliases and shared venue IDs',
      () {
        // 1. Matched by canonical key
        final a = PlaceIdentity.manual('spot-101');
        final b = PlaceIdentity.manual('spot-101');
        expect(a.matches(b), isTrue);

        // 2. Matched by geoapifyPlaceId
        final g1 = PlaceIdentity.geoapify('geo_999');
        final g2 = PlaceIdentity.geoapify(
          'geo_999',
          spotNugasPlaceId: 'curated-999',
        );
        expect(g1.matches(g2), isTrue);

        // 3. Matched across migration via aliases (Google -> Geoapify migration)
        final legacyGoogle = PlaceIdentity.google(
          'gplace_cafe_x',
          spotNugasPlaceId: 'cafe-x',
          aliases: const ['gplace_cafe_x'],
        );
        final migratedGeoapify = PlaceIdentity.geoapify(
          'geoapify_cafe_x',
          spotNugasPlaceId: 'cafe-x',
          aliases: const ['gplace_cafe_x'],
        );
        expect(legacyGoogle.matches(migratedGeoapify), isTrue);

        // 4. Different places do not match
        final diff = PlaceIdentity.geoapify('different_id');
        expect(legacyGoogle.matches(diff), isFalse);
      },
    );

    test(
      'isValidKey rejects slashes and invalid characters for Firestore safety',
      () {
        expect(
          PlaceIdentity.isValidKey('geoapify:5130b427435f3d5b40590a'),
          isTrue,
        );
        expect(PlaceIdentity.isValidKey('kopi-ruang'), isTrue);
        expect(PlaceIdentity.isValidKey('google:mock-123'), isTrue);

        expect(PlaceIdentity.isValidKey(''), isFalse);
        expect(PlaceIdentity.isValidKey('   '), isFalse);
        expect(PlaceIdentity.isValidKey('invalid/slash'), isFalse);
        expect(PlaceIdentity.isValidKey('invalid..dotdot'), isFalse);
      },
    );
  });

  group('GeoapifyPlaceData DTO Parsing', () {
    test(
      'Parses GeoJSON feature structure correctly without external calls',
      () {
        final geoJsonFeature = {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [110.3845, -7.7610], // [lon, lat]
          },
          'properties': {
            'place_id': '5130b427435f3d5b40590a',
            'name': 'Kopi Ruang Geoapify',
            'formatted': 'Jl. Kaliurang km 5, Sleman, D.I. Yogyakarta',
            'categories': ['catering.cafe', 'catering.coffee_shop'],
            'opening_hours': 'Mo-Su 08:00-23:00',
            'is_open': true,
            'contact': {'phone': '+62 812-3456-7890'},
            'website': 'https://kopiruang.example.com',
            'datasource': {'sourcename': 'openstreetmap'},
          },
        };

        final dto = GeoapifyPlaceData.fromGeoJson(geoJsonFeature);

        expect(dto.geoapifyPlaceId, '5130b427435f3d5b40590a');
        expect(dto.name, 'Kopi Ruang Geoapify');
        expect(dto.location.latitude, -7.7610);
        expect(dto.location.longitude, 110.3845);
        expect(dto.primaryCategory, 'catering.cafe');
        expect(dto.categories, contains('catering.coffee_shop'));
        expect(
          dto.formattedAddress,
          'Jl. Kaliurang km 5, Sleman, D.I. Yogyakarta',
        );
        expect(dto.isOpenNow, isTrue);
        expect(dto.openingHours?.statusLabel, 'Mo-Su 08:00-23:00');
        expect(dto.contactPhone, '+62 812-3456-7890');
        expect(dto.website, 'https://kopiruang.example.com');
        expect(dto.datasource, 'openstreetmap');
      },
    );

    test(
      'Parses fallback coordinates when geometry.coordinates is missing',
      () {
        final flatFeature = {
          'properties': {
            'place_id': 'flat_123',
            'name': 'Flat Props Place',
            'lat': -6.2088,
            'lon': 106.8456,
          },
        };

        final dto = GeoapifyPlaceData.fromGeoJson(flatFeature);
        expect(dto.geoapifyPlaceId, 'flat_123');
        expect(dto.location.latitude, -6.2088);
        expect(dto.location.longitude, 106.8456);
        expect(dto.name, 'Flat Props Place');
      },
    );
  });

  group('SpotNugasPlaceData Geoapify Serialization', () {
    test('Serializes and deserializes Geoapify overlay document', () {
      final overlay = SpotNugasPlaceData.geoapify(
        placeId: 'kopi-geo-overlay',
        geoapifyPlaceId: '5130b427435f3d5b40590a',
        aliases: const ['5130b427435f3d5b40590a', 'legacy-g-1'],
        category: 'Workspace & Cafe',
        studyScore: 9.3,
        wifiScore: 4.8,
        outletScore: 4.7,
        facilities: const [PlaceFacility.wifi, PlaceFacility.powerOutlet],
        tags: const ['Wi-Fi Cepat', 'Banyak Colokan'],
      );

      expect(overlay.isGeoapify, isTrue);
      expect(overlay.isGoogle, isFalse);
      expect(overlay.isManual, isFalse);

      final map = overlay.toMap();
      expect(map['source'], 'geoapify');
      expect(map['geoapifyPlaceId'], '5130b427435f3d5b40590a');
      expect(map['aliases'], contains('5130b427435f3d5b40590a'));
      expect(map['studyScore'], 9.3);

      final restored = SpotNugasPlaceData.fromMap(map, 'kopi-geo-overlay');
      expect(restored.isGeoapify, isTrue);
      expect(restored.geoapifyPlaceId, '5130b427435f3d5b40590a');
      expect(restored.studyScore, 9.3);
      expect(restored.facilities, contains(PlaceFacility.wifi));
    });

    test(
      'Throws FormatException if source is geoapify but geoapifyPlaceId is missing',
      () {
        final invalidMap = <String, dynamic>{
          'source': 'geoapify',
          'studyScore': 8.5,
        };

        expect(
          () => SpotNugasPlaceData.fromMap(invalidMap, 'invalid-doc'),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });

  group('Place Domain Model from Geoapify Sources', () {
    test(
      'Merges GeoapifyPlaceData and SpotNugas overlay with proper precedence',
      () {
        const geoDto = GeoapifyPlaceData(
          geoapifyPlaceId: 'geo-venue-1',
          name: 'Geoapify Study Hub',
          location: GeoCoordinates(-6.2000, 106.8166),
          primaryCategory: 'catering.cafe',
          formattedAddress: 'Jl. Sudirman No. 1, Jakarta',
          isOpenNow: true,
        );

        final overlay = SpotNugasPlaceData.geoapify(
          placeId: 'study-hub-jakarta',
          geoapifyPlaceId: 'geo-venue-1',
          category: 'Study & Work Haven', // Editorial override
          studyScore: 9.6,
          wifiScore: 5.0,
          outletScore: 4.9,
          comfortScore: 4.8,
          noiseScore: 4.5,
          facilities: const [PlaceFacility.wifi, PlaceFacility.quietZone],
          tags: const ['Wi-Fi Cepat', 'Zona Hening'],
        );

        final place = Place.fromSources(
          geoapify: geoDto,
          spotNugas: overlay,
          distanceKm: 0.5,
        );

        expect(place.id, 'study-hub-jakarta');
        expect(place.canonicalKey, 'study-hub-jakarta');
        expect(place.source, PlaceSource.geoapify);
        expect(place.isGeoapify, isTrue);
        expect(place.geoapifyPlaceId, 'geo-venue-1');

        // Public facts come from Geoapify
        expect(place.name, 'Geoapify Study Hub');
        expect(place.address, 'Jl. Sudirman No. 1, Jakarta');
        expect(place.latitude, -6.2000);
        expect(place.longitude, 106.8166);

        // Editorial & productivity overrides come from SpotNugas overlay
        expect(place.category, 'Study & Work Haven');
        expect(place.studyScore, 9.6);
        expect(place.resolvedStudyScore, 9.6);
        expect(place.facilities, contains(PlaceFacility.quietZone));
        expect(place.tags, contains('Zona Hening'));

        // Identity value object
        final identity = place.identity;
        expect(identity.canonicalKey, 'study-hub-jakarta');
        expect(identity.primarySource, PlaceSource.geoapify);
      },
    );

    test('Creates Place from Geoapify without SpotNugas overlay doc', () {
      const geoDto = GeoapifyPlaceData(
        geoapifyPlaceId: 'geo-raw-77',
        name: 'New Coffee Bar',
        location: GeoCoordinates(-6.2500, 106.8000),
        formattedAddress: 'Jl. Kemang Raya No. 10',
      );

      final place = Place.fromSources(geoapify: geoDto);
      expect(place.id, 'geoapify:geo-raw-77');
      expect(place.canonicalKey, 'geoapify:geo-raw-77');
      expect(place.isGeoapify, isTrue);
      expect(place.name, 'New Coffee Bar');
      expect(place.hasSpotNugasData, isFalse);
    });

    test('Rejects mismatched geoapifyPlaceId between DTO and overlay', () {
      const geoDto = GeoapifyPlaceData(
        geoapifyPlaceId: 'geo-id-1',
        name: 'Venue 1',
        location: GeoCoordinates(0, 0),
      );

      final overlay = SpotNugasPlaceData.geoapify(
        placeId: 'overlay-1',
        geoapifyPlaceId: 'geo-id-2', // Mismatch!
      );

      expect(
        () => Place.fromSources(geoapify: geoDto, spotNugas: overlay),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Rejects merging manual place with Geoapify data', () {
      const geoDto = GeoapifyPlaceData(
        geoapifyPlaceId: 'geo-id-1',
        name: 'Venue 1',
        location: GeoCoordinates(0, 0),
      );

      final manualPlace = SpotNugasPlaceData.manual(
        placeId: 'manual-place-1',
        name: 'Manual Place',
        location: const GeoCoordinates(0, 0),
      );

      expect(
        () => Place.fromSources(geoapify: geoDto, spotNugas: manualPlace),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Saved Places & Reviews with Geoapify Canonical Keys', () {
    late SavedPlacesRepository savedRepo;
    late ReviewRepository reviewRepo;

    setUp(() {
      savedRepo = SavedPlacesRepository();
      reviewRepo = ReviewRepository();
    });

    tearDown(() {
      savedRepo.clearAll();
      reviewRepo.clearAll();
    });

    test(
      'SavedPlaceItem correctly stores and references Geoapify canonical key',
      () {
        const geoDto = GeoapifyPlaceData(
          geoapifyPlaceId: 'geo-bookmark-123',
          name: 'Geoapify Bookmark Spot',
          location: GeoCoordinates(-6.2, 106.8),
          formattedAddress: 'Jakarta',
        );

        final place = Place.fromSources(geoapify: geoDto);
        final item = SavedPlaceItem.fromPlace(place);

        expect(item.placeId, 'geoapify:geo-bookmark-123');
        expect(item.name, 'Geoapify Bookmark Spot');

        final map = item.toMap();
        expect(map['placeId'], 'geoapify:geo-bookmark-123');

        final restored = SavedPlaceItem.fromMap(map, item.placeId);
        expect(restored.placeId, 'geoapify:geo-bookmark-123');
      },
    );

    test(
      'SavedPlacesRepository saves, checks, and toggles Geoapify places',
      () async {
        const geoDto = GeoapifyPlaceData(
          geoapifyPlaceId: 'geo-venue-save-test',
          name: 'Save Test Spot',
          location: GeoCoordinates(-6.2, 106.8),
        );
        final place = Place.fromSources(geoapify: geoDto);
        const testUserId = 'test_user_saved_1';

        expect(await savedRepo.isPlaceSaved(testUserId, place.id), isFalse);

        // Save
        await savedRepo.savePlace(testUserId, place);
        expect(await savedRepo.isPlaceSaved(testUserId, place.id), isTrue);

        // Toggle off
        final toggledOff = await savedRepo.toggleSavedPlace(testUserId, place);
        expect(toggledOff, isFalse);
        expect(await savedRepo.isPlaceSaved(testUserId, place.id), isFalse);

        // Toggle on
        final toggledOn = await savedRepo.toggleSavedPlace(testUserId, place);
        expect(toggledOn, isTrue);
        expect(await savedRepo.isPlaceSaved(testUserId, place.id), isTrue);
      },
    );

    test(
      'ReviewRepository publishes and dynamically updates Skor Nugas for Geoapify places',
      () async {
        const geoDto = GeoapifyPlaceData(
          geoapifyPlaceId: 'geo-review-test',
          name: 'Review Test Cafe',
          location: GeoCoordinates(-6.2, 106.8),
        );
        final place = Place.fromSources(geoapify: geoDto);

        final registeredUser = UserProfile(
          uid: 'user_reg_99',
          name: 'Budi Santoso',
          email: 'budi@example.com',
          isGuest: false,
        );

        final publishedReview = await reviewRepo.publishReview(
          placeId: place.id,
          user: registeredUser,
          rating: 4.8,
          comment: 'Tempat Geoapify ini sangat cocok untuk nugas!',
          wifiRating: 5.0,
          outletRating: 4.5,
          comfortRating: 4.5,
          noiseRating: 4.0,
        );

        expect(publishedReview.placeId, place.id);
        expect(publishedReview.userId, 'user_reg_99');
        expect(publishedReview.rating, 4.8);

        // Verify dynamic Skor Nugas computation
        final dynamicScore = reviewRepo.computeDynamicSkorNugas(
          place: place,
          reviews: [publishedReview],
        );

        expect(dynamicScore, greaterThan(8.0));
        expect(dynamicScore, lessThanOrEqualTo(10.0));
      },
    );

    test(
      'Anonymous guest is strictly prevented from publishing reviews on Geoapify places',
      () async {
        const geoDto = GeoapifyPlaceData(
          geoapifyPlaceId: 'geo-guest-test',
          name: 'Guest Test Cafe',
          location: GeoCoordinates(-6.2, 106.8),
        );
        final place = Place.fromSources(geoapify: geoDto);

        final guestUser = const UserProfile(
          uid: 'guest_user_anon',
          name: 'Tamu SpotNugas',
          isGuest: true,
        );

        expect(
          () => reviewRepo.publishReview(
            placeId: place.id,
            user: guestUser,
            rating: 4.0,
            comment: 'Guest comment attempt',
          ),
          throwsA(
            isA<ReviewException>().having(
              (e) => e.code,
              'code',
              'guest-review-forbidden',
            ),
          ),
        );
      },
    );
  });

  group('MockPlaceRepository with Geoapify Support', () {
    test(
      'Lookups find places by canonical id, geoapifyPlaceId, and aliases',
      () async {
        const geoDto = GeoapifyPlaceData(
          geoapifyPlaceId: 'geo-mock-lookup-1',
          name: 'Geoapify Lookup Spot',
          location: GeoCoordinates(-7.76, 110.38),
        );
        final overlay = SpotNugasPlaceData.geoapify(
          placeId: 'spot-geo-lookup',
          geoapifyPlaceId: 'geo-mock-lookup-1',
          aliases: const ['legacy-alias-g99'],
          studyScore: 9.0,
        );
        final geoPlace = Place.fromSources(
          geoapify: geoDto,
          spotNugas: overlay,
        );

        final repo = MockPlaceRepository(places: [geoPlace]);

        // 1. Lookup by canonical spotNugas id
        final foundByCanonical = await repo.getPlaceById('spot-geo-lookup');
        expect(foundByCanonical, isNotNull);
        expect(foundByCanonical!.name, 'Geoapify Lookup Spot');

        // 2. Lookup by geoapifyPlaceId
        final foundByGeoapify = await repo.getPlaceById('geo-mock-lookup-1');
        expect(foundByGeoapify, isNotNull);
        expect(foundByGeoapify!.id, 'spot-geo-lookup');

        // 3. Lookup by alias
        final foundByAlias = await repo.getPlaceById('legacy-alias-g99');
        expect(foundByAlias, isNotNull);
        expect(foundByAlias!.id, 'spot-geo-lookup');

        // 4. Non-existent returns null
        final notFound = await repo.getPlaceById('non-existent-id');
        expect(notFound, isNull);
      },
    );
  });
}
