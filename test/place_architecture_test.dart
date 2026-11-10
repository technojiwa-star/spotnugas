import 'package:flutter_test/flutter_test.dart';
import 'package:spot_nugas/models/google_place_data.dart';
import 'package:spot_nugas/models/place.dart';
import 'package:spot_nugas/models/spotnugas_place_data.dart';
import 'package:spot_nugas/repositories/mock_place_repository.dart';
import 'package:spot_nugas/repositories/place_repository.dart';
import 'package:spot_nugas/utils/study_score_calculator.dart';

void main() {
  group('PlaceSource.google vs PlaceSource.manual Contracts', () {
    test(
      'Google-sourced place requires googlePlaceId and merges correctly',
      () {
        final googleData = GooglePlaceData(
          googlePlaceId: 'ChIJ_TEST_123',
          name: 'Kopi Google',
          location: const GeoCoordinates(-7.770, 110.377),
          formattedAddress: 'Jl. Kaliurang No. 10',
          rating: 4.8,
          userRatingCount: 120,
          priceLevel: PlacePriceLevel.inexpensive,
          isOpenNow: true,
        );

        final spotOverlay = SpotNugasPlaceData.google(
          placeId: 'sn-kopi-google',
          googlePlaceId: 'ChIJ_TEST_123',
          category: 'Coworking Cafe',
          studyScore: 9.3,
          wifiScore: 4.9,
          outletScore: 4.8,
          comfortScore: 4.5,
          noiseScore: 4.2,
          priceValueScore: 4.0,
          facilities: [PlaceFacility.wifi, PlaceFacility.powerOutlet],
          tags: ['Wi-Fi Cepat', 'Banyak Colokan'],
        );

        final place = Place.fromSources(
          google: googleData,
          spotNugas: spotOverlay,
          distanceKm: 0.85,
        );

        expect(place.id, equals('sn-kopi-google'));
        expect(place.source, equals(PlaceSource.google));
        expect(place.isGoogleSourced, isTrue);
        expect(place.isManual, isFalse);
        expect(place.googlePlaceId, equals('ChIJ_TEST_123'));
        expect(place.name, equals('Kopi Google'));
        expect(place.address, equals('Jl. Kaliurang No. 10'));
        expect(place.latitude, equals(-7.770));
        expect(place.longitude, equals(110.377));
        expect(place.displayRating, equals(4.8));
        expect(place.category, equals('Coworking Cafe'));
        expect(place.resolvedStudyScore, equals(9.3));
        expect(place.studyScoreLabel, equals('Sangat Direkomendasikan'));
        expect(place.distanceLabel, equals('850 m'));
        expect(place.openStatusLabel, equals('Buka sekarang'));
        expect(place.priceLabel, equals('Murah'));
        expect(place.facilityLabels, containsAll(['Wi-Fi', 'Colokan']));
      },
    );

    test(
      'Manual place requires all data from SpotNugas without Google data',
      () {
        final manualData = SpotNugasPlaceData.manual(
          placeId: 'sn-selasar-kampus',
          name: 'Selasar Belajar FT UGM',
          address: 'Kompleks Fakultas Teknik UGM',
          location: const GeoCoordinates(-7.765, 110.372),
          category: 'Study Hall',
          priceLevel: PlacePriceLevel.free,
          studyScore: 9.5,
          wifiScore: 4.8,
          outletScore: 4.6,
          facilities: [
            PlaceFacility.wifi,
            PlaceFacility.powerOutlet,
            PlaceFacility.quietZone,
          ],
          tags: ['Gratis', 'Zona Hening'],
          verificationStatus: PlaceVerificationStatus.verified,
          communityRating: 4.9,
          communityRatingCount: 45,
        );

        final place = Place.fromSources(spotNugas: manualData, distanceKm: 1.4);

        expect(place.id, equals('sn-selasar-kampus'));
        expect(place.source, equals(PlaceSource.manual));
        expect(place.isManual, isTrue);
        expect(place.isGoogleSourced, isFalse);
        expect(place.googlePlaceId, isNull);
        expect(place.name, equals('Selasar Belajar FT UGM'));
        expect(place.address, equals('Kompleks Fakultas Teknik UGM'));
        expect(
          place.verificationStatus,
          equals(PlaceVerificationStatus.verified),
        );
        expect(place.displayRating, equals(4.9));
        expect(place.displayRatingCount, equals(45));
        expect(place.distanceLabel, equals('1.4 km'));
        expect(place.priceLabel, equals('Gratis'));
      },
    );

    test('Manual place throws if merged with Google data', () {
      final manualData = SpotNugasPlaceData.manual(
        placeId: 'sn-manual-conflict',
        name: 'Selasar Belajar',
        address: 'Kampus',
        location: const GeoCoordinates(-7.765, 110.372),
      );

      final googleData = GooglePlaceData(
        googlePlaceId: 'ChIJ_CONFLICT',
        name: 'Google Duplicate',
        location: const GeoCoordinates(-7.765, 110.372),
      );

      expect(
        () => Place.fromSources(google: googleData, spotNugas: manualData),
        throwsArgumentError,
      );
    });

    test('Google place throws if GooglePlaceData is null', () {
      final googleOverlay = SpotNugasPlaceData.google(
        placeId: 'sn-missing-google',
        googlePlaceId: 'ChIJ_MISSING',
      );

      expect(
        () => Place.fromSources(google: null, spotNugas: googleOverlay),
        throwsArgumentError,
      );
    });

    test('Google place throws if overlay googlePlaceId mismatches', () {
      final googleData = GooglePlaceData(
        googlePlaceId: 'ChIJ_REAL_ID',
        name: 'Real Place',
        location: const GeoCoordinates(-7.7, 110.3),
      );

      final googleOverlay = SpotNugasPlaceData.google(
        placeId: 'sn-mismatched',
        googlePlaceId: 'ChIJ_WRONG_ID',
      );

      expect(
        () => Place.fromSources(google: googleData, spotNugas: googleOverlay),
        throwsArgumentError,
      );
    });
  });

  group('SpotNugasPlaceData Serialization / Deserialization', () {
    test(
      'Google overlay document roundtrip preserves fields and omits transient data',
      () {
        final overlay = SpotNugasPlaceData.google(
          placeId: 'sn-test-overlay',
          googlePlaceId: 'ChIJ_OVERLAY_123',
          category: 'Kafe Nugas',
          studyScore: 9.1,
          wifiScore: 4.8,
          outletScore: 4.7,
          facilities: [PlaceFacility.wifi, PlaceFacility.powerOutlet],
          tags: ['Wi-Fi Cepat'],
          isVerifiedPartner: true,
          verifiedPartnerUid: 'partner-user-99',
        );

        final map = overlay.toMap();
        expect(map['source'], equals('google'));
        expect(map['googlePlaceId'], equals('ChIJ_OVERLAY_123'));
        expect(map['category'], equals('Kafe Nugas'));
        expect(map['studyScore'], equals(9.1));
        expect(map['wifiScore'], equals(4.8));
        expect(map['facilities'], containsAll(['wifi', 'power_outlet']));
        expect(map['tags'], contains('Wi-Fi Cepat'));
        expect(map['isVerifiedPartner'], isTrue);
        expect(map['verifiedPartnerUid'], equals('partner-user-99'));

        // Ensure public content is NOT written for Google overlay
        expect(map.containsKey('name'), isFalse);
        expect(map.containsKey('address'), isFalse);
        expect(map.containsKey('location'), isFalse);

        final parsed = SpotNugasPlaceData.fromMap(map, 'sn-test-overlay');
        expect(parsed.placeId, equals('sn-test-overlay'));
        expect(parsed.source, equals(PlaceSource.google));
        expect(parsed.googlePlaceId, equals('ChIJ_OVERLAY_123'));
        expect(parsed.category, equals('Kafe Nugas'));
        expect(parsed.studyScore, equals(9.1));
        expect(parsed.facilities, contains(PlaceFacility.wifi));
      },
    );

    test(
      'Manual place document roundtrip serializes public info and verificationStatus',
      () {
        final manual = SpotNugasPlaceData.manual(
          placeId: 'sn-test-manual',
          name: 'Spot Belajar Komunitas',
          address: 'Jl. Gejayan No. 45',
          location: const GeoCoordinates(-7.772, 110.390),
          category: 'Ruang Belajar',
          priceLevel: PlacePriceLevel.free,
          facilities: [PlaceFacility.wifi, PlaceFacility.airConditioning],
          verificationStatus: PlaceVerificationStatus.verified,
          communityRating: 4.6,
          communityRatingCount: 15,
        );

        final map = manual.toMap();
        expect(map['source'], equals('manual'));
        expect(map['name'], equals('Spot Belajar Komunitas'));
        expect(map['address'], equals('Jl. Gejayan No. 45'));
        expect(map['priceLevel'], equals('PRICE_LEVEL_FREE'));
        expect(map['verificationStatus'], equals('verified'));
        expect(map['communityRating'], equals(4.6));

        final parsed = SpotNugasPlaceData.fromMap(map, 'sn-test-manual');
        expect(parsed.placeId, equals('sn-test-manual'));
        expect(parsed.source, equals(PlaceSource.manual));
        expect(parsed.name, equals('Spot Belajar Komunitas'));
        expect(parsed.address, equals('Jl. Gejayan No. 45'));
        expect(
          parsed.verificationStatus,
          equals(PlaceVerificationStatus.verified),
        );
        expect(parsed.location?.latitude, equals(-7.772));
        expect(parsed.location?.longitude, equals(110.390));
      },
    );
  });

  group('StudyScoreCalculator Deterministic Calculation & Labels', () {
    const calc = StudyScoreCalculator();

    test('calculates weighted score correctly with all inputs', () {
      // weights: wifi 0.25, outlet 0.20, comfort 0.20, noise 0.15, price 0.10, reputation 0.10
      // all 5.0 -> 10.0
      final perfect = calc.compute(
        wifiScore: 5.0,
        outletScore: 5.0,
        comfortScore: 5.0,
        noiseScore: 5.0,
        priceValueScore: 5.0,
        rating: 5.0,
      );
      expect(perfect, equals(10.0));
      expect(StudyScoreCalculator.labelFor(perfect), equals('Luar Biasa'));

      // 4.0 out of 5 for all -> 8.0 out of 10
      final good = calc.compute(
        wifiScore: 4.0,
        outletScore: 4.0,
        comfortScore: 4.0,
        noiseScore: 4.0,
        priceValueScore: 4.0,
        rating: 4.0,
      );
      expect(good, equals(8.0));
      expect(StudyScoreCalculator.labelFor(good), equals('Bagus'));
    });

    test('renormalises weights when some sub-scores are missing', () {
      final partial = calc.compute(
        wifiScore: 5.0, // weight 0.25
        outletScore: 4.0, // weight 0.20
      );
      // totalWeight = 0.45, weighted = (5*0.25 + 4*0.20) = 1.25 + 0.80 = 2.05
      // 2.05 / 0.45 = 4.5555... out of 5 -> 9.111... out of 10 -> rounded to 9.1
      expect(partial, equals(9.1));
      expect(StudyScoreCalculator.labelFor(partial), equals('Sangat Bagus'));
    });

    test(
      'returns null when no productivity score is provided (reputation alone is insufficient)',
      () {
        final ratingOnly = calc.compute(rating: 4.8);
        expect(ratingOnly, isNull);
        expect(
          StudyScoreCalculator.labelFor(ratingOnly),
          equals('Belum Dinilai'),
        );
      },
    );

    test('labelFor returns proper thresholds', () {
      expect(StudyScoreCalculator.labelFor(9.6), equals('Luar Biasa'));
      expect(
        StudyScoreCalculator.labelFor(9.3),
        equals('Sangat Direkomendasikan'),
      );
      expect(StudyScoreCalculator.labelFor(9.0), equals('Sangat Bagus'));
      expect(StudyScoreCalculator.labelFor(8.7), equals('Bagus Sekali'));
      expect(StudyScoreCalculator.labelFor(7.8), equals('Bagus'));
      expect(StudyScoreCalculator.labelFor(6.5), equals('Cukup'));
      expect(StudyScoreCalculator.labelFor(5.0), equals('Kurang Cocok'));
    });
  });

  group('MockPlaceRepository Queries, Search, and Sort', () {
    final repo = MockPlaceRepository();

    test('getNearbyPlaces respects radius and origin', () async {
      final nearby = await repo.getNearbyPlaces(
        origin: const GeoCoordinates(-7.770, 110.377),
        radiusKm: 2.0,
      );

      expect(nearby, isNotEmpty);
      for (final p in nearby) {
        expect(p.distanceKm, lessThanOrEqualTo(2.0));
      }
    });

    test('getNearbyPlaces respects limit parameter', () async {
      final limited = await repo.getNearbyPlaces(
        origin: const GeoCoordinates(-7.770, 110.377),
        limit: 2,
      );
      expect(limited.length, equals(2));
    });

    test('searchPlaces searches by text in name, category, and tags', () async {
      final nameResults = await repo.searchPlaces(
        const PlaceSearchQuery(text: 'Kopi Ruang'),
      );
      expect(nameResults.length, equals(1));
      expect(nameResults.first.name, contains('Kopi Ruang'));

      final tagResults = await repo.searchPlaces(
        const PlaceSearchQuery(text: 'Wi-Fi Cepat'),
      );
      expect(tagResults, isNotEmpty);
      expect(tagResults.any((p) => p.tags.contains('Wi-Fi Cepat')), isTrue);
    });

    test('searchPlaces filters by tag', () async {
      final results = await repo.searchPlaces(
        const PlaceSearchQuery(tag: 'Hemat'),
      );
      expect(results, isNotEmpty);
      for (final p in results) {
        expect(p.tags, contains('Hemat'));
      }
    });

    test(
      'searchPlaces sorts by studyScore, distance, rating, and price',
      () async {
        // 1. Sort by studyScore descending
        final scoreSorted = await repo.searchPlaces(
          const PlaceSearchQuery(sort: PlaceSortOption.studyScore),
        );
        for (int i = 0; i < scoreSorted.length - 1; i++) {
          final current = scoreSorted[i].resolvedStudyScore ?? 0;
          final next = scoreSorted[i + 1].resolvedStudyScore ?? 0;
          expect(current >= next, isTrue);
        }

        // 2. Sort by rating descending
        final ratingSorted = await repo.searchPlaces(
          const PlaceSearchQuery(sort: PlaceSortOption.rating),
        );
        for (int i = 0; i < ratingSorted.length - 1; i++) {
          final current = ratingSorted[i].displayRating ?? 0;
          final next = ratingSorted[i + 1].displayRating ?? 0;
          expect(current >= next, isTrue);
        }

        // 3. Sort by distance ascending
        final distanceSorted = await repo.searchPlaces(
          const PlaceSearchQuery(sort: PlaceSortOption.distance),
        );
        for (int i = 0; i < distanceSorted.length - 1; i++) {
          final current = distanceSorted[i].distanceKm ?? double.infinity;
          final next = distanceSorted[i + 1].distanceKm ?? double.infinity;
          expect(current <= next, isTrue);
        }
      },
    );

    test('getPlaceById finds by SpotNugas id and Google place id', () async {
      final bySnId = await repo.getPlaceById('kopi-ruang');
      expect(bySnId, isNotNull);
      expect(bySnId!.name, contains('Kopi Ruang'));

      final byGoogleId = await repo.getPlaceById('mock-gplace-kopi-ruang');
      expect(byGoogleId, isNotNull);
      expect(byGoogleId!.id, equals('kopi-ruang'));

      final notFound = await repo.getPlaceById('non-existent-id');
      expect(notFound, isNull);
    });
  });

  group('Place Compatibility Getters Verification', () {
    test('legacy getters return expected values cleanly', () {
      final googleData = GooglePlaceData(
        googlePlaceId: 'ChIJ_LEGACY',
        name: 'Legacy Test',
        location: const GeoCoordinates(-7.75, 110.35),
        rating: 4.7,
        userRatingCount: 88,
        priceLevel: PlacePriceLevel.moderate,
        isOpenNow: true,
        photoUrls: ['assets/images/legacy.jpg'],
      );

      final spotOverlay = SpotNugasPlaceData.google(
        placeId: 'sn-legacy',
        googlePlaceId: 'ChIJ_LEGACY',
        studyScore: 9.2,
        wifiScore: 4.8,
        outletScore: 4.5,
        comfortScore: 4.3,
        noiseScore: 4.1,
        priceValueScore: 3.9,
      );

      final place = Place.fromSources(
        google: googleData,
        spotNugas: spotOverlay,
        distanceKm: 0.5,
      );

      // Verify legacy getter values
      expect(place.image, equals('assets/images/legacy.jpg'));
      expect(place.distance, equals('500 m'));
      expect(place.isOpen, isTrue);
      expect(place.openStatus, equals('Buka sekarang'));
      expect(place.skorNugas, equals(9.2));
      expect(place.skorDescription, equals('Sangat Direkomendasikan'));
      expect(place.rating, equals(4.7));
      expect(place.reviewCount, equals(88));
      expect(place.wifiScoreVal, equals(4.8));
      expect(place.colokanScore, equals(4.5));
      expect(place.kenyamananScore, equals(4.3));
      expect(place.ketenanganScore, equals(4.1));
      expect(place.hargaScore, equals(3.9));
      expect(place.lat, equals(-7.75));
      expect(place.lng, equals(110.35));
    });
  });
}
