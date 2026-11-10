import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:spot_nugas/config/geoapify_config.dart';
import 'package:spot_nugas/constants/app_location.dart';
import 'package:spot_nugas/datasources/geoapify_places_data_source.dart';
import 'package:spot_nugas/models/place.dart';
import 'package:spot_nugas/models/place_review_model.dart';
import 'package:spot_nugas/models/saved_place_item.dart';
import 'package:spot_nugas/models/user_profile.dart';
import 'package:spot_nugas/repositories/geoapify_place_repository.dart';
import 'package:spot_nugas/repositories/place_repository.dart';
import 'package:spot_nugas/repositories/review_repository.dart';
import 'package:spot_nugas/repositories/saved_places_repository.dart';
import 'package:spot_nugas/screens/place_detail_screen.dart';
import 'package:spot_nugas/widgets/place_card.dart';

/// Mock HTTP client for injecting Geoapify responses in automated tests.
class MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request request) handler;

  MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final httpRequest = request as http.Request;
    final response = await handler(httpRequest);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  const sampleGeoJson = {
    'type': 'FeatureCollection',
    'features': [
      {
        'type': 'Feature',
        'properties': {
          'place_id': 'geo_cafe_001',
          'name': 'Cofilab Jakarta',
          'categories': ['catering.cafe', 'catering'],
          'formatted': 'Jl. Senopati No. 12, Kebayoran Baru, Jakarta Selatan',
          'lat': -6.2297,
          'lon': 106.8295,
          'opening_hours': 'Mo-Su 08:00-22:00',
          'is_open': true,
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [106.8295, -6.2297],
        },
      },
      {
        'type': 'Feature',
        'properties': {
          'place_id': 'geo_cowork_002',
          'name': 'Kuningan Space & Coworking',
          'categories': ['office.coworking', 'office'],
          'formatted': 'Jl. Rasuna Said Kav. 5, Jakarta Selatan',
          'lat': -6.2250,
          'lon': 106.8320,
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [106.8320, -6.2250],
        },
      },
    ],
  };

  group('1. Valid Geoapify FeatureCollection parsing', () {
    test(
      'Correctly parses GeoJSON FeatureCollection into GeoapifyPlaceData',
      () async {
        final client = MockHttpClient((req) async {
          return http.Response(
            json.encode(sampleGeoJson),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });

        final dataSource = HttpGeoapifyPlacesDataSource(
          client: client,
          apiKey: 'test_dev_key',
        );

        final results = await dataSource.fetchNearbyPlaces(
          location: const GeoCoordinates(-6.2297, 106.8295),
        );

        expect(results.length, 2);
        expect(results[0].geoapifyPlaceId, 'geo_cafe_001');
        expect(results[0].name, 'Cofilab Jakarta');
        expect(results[0].primaryCategory, 'catering.cafe');
        expect(results[0].location.latitude, -6.2297);
        expect(results[0].location.longitude, 106.8295);
        expect(results[0].formattedAddress, contains('Jl. Senopati'));
        expect(results[0].isOpenNow, isTrue);

        expect(results[1].geoapifyPlaceId, 'geo_cowork_002');
        expect(results[1].name, 'Kuningan Space & Coworking');
        expect(results[1].primaryCategory, 'office.coworking');
      },
    );
  });

  group('2. Empty feature arrays', () {
    test(
      'Gracefully returns empty list when features array is empty',
      () async {
        final client = MockHttpClient((req) async {
          return http.Response(
            json.encode({'type': 'FeatureCollection', 'features': []}),
            200,
          );
        });

        final dataSource = HttpGeoapifyPlacesDataSource(
          client: client,
          apiKey: 'test_dev_key',
        );

        final results = await dataSource.fetchNearbyPlaces(
          location: const GeoCoordinates(-6.2297, 106.8295),
        );

        expect(results, isEmpty);
      },
    );
  });

  group('3. Missing place names', () {
    test('Falls back to "Tempat Tanpa Nama" when name is missing or null', () {
      final feature = {
        'properties': {
          'place_id': 'no_name_place',
          'name': null,
          'lat': -6.2297,
          'lon': 106.8295,
        },
      };

      final place = GeoapifyPlaceData.fromGeoJson(feature);
      expect(place.name, 'Tempat Tanpa Nama');
      expect(place.geoapifyPlaceId, 'no_name_place');
    });
  });

  group('4. Missing addresses', () {
    test(
      'Handles missing formatted and street addresses safely without crashing',
      () {
        final feature = {
          'properties': {
            'place_id': 'no_addr_place',
            'name': 'Cafe Senja',
            'lat': -6.2297,
            'lon': 106.8295,
          },
        };

        final place = GeoapifyPlaceData.fromGeoJson(feature);
        expect(place.formattedAddress, isNull);
        expect(place.name, 'Cafe Senja');
      },
    );
  });

  group('5. Invalid coordinates', () {
    test(
      'Safely clamps out-of-bounds coordinates to valid geographic limits',
      () {
        final feature = {
          'properties': {
            'place_id': 'out_of_bounds_coords',
            'name': 'Extreme Venue',
            'lat': 999.0, // Invalid latitude > 90
            'lon': -999.0, // Invalid longitude < -180
          },
        };

        final place = GeoapifyPlaceData.fromGeoJson(feature);
        expect(place.location.latitude, 90.0);
        expect(place.location.longitude, -180.0);
      },
    );
  });

  group('6. Incorrect longitude/latitude order', () {
    test(
      'Detects and corrects accidentally swapped [latitude, longitude] in coordinates',
      () {
        // In GeoJSON, order is [lon, lat]. If swapped as [lat, lon] where lat is 106.8295 (>90):
        final feature = {
          'properties': {
            'place_id': 'swapped_coords_place',
            'name': 'Reversed Coords Cafe',
          },
          'geometry': {
            'type': 'Point',
            // Accidental [lat, lon]: 106.8295 is longitude placed at coordinates[1]
            'coordinates': [-6.2297, 106.8295],
          },
        };

        final place = GeoapifyPlaceData.fromGeoJson(feature);
        expect(place.location.latitude, -6.2297);
        expect(place.location.longitude, 106.8295);
      },
    );
  });

  group('7. Duplicate venue records', () {
    test('Deduplicates duplicate venue place_ids from response', () async {
      final duplicateGeoJson = {
        'type': 'FeatureCollection',
        'features': [
          {
            'properties': {
              'place_id': 'dup_101',
              'name': 'Duplicate Coffee 1',
              'lat': -6.2297,
              'lon': 106.8295,
            },
          },
          {
            'properties': {
              'place_id': 'dup_101',
              'name': 'Duplicate Coffee 2',
              'lat': -6.2297,
              'lon': 106.8295,
            },
          },
        ],
      };

      final client = MockHttpClient((req) async {
        return http.Response(json.encode(duplicateGeoJson), 200);
      });

      final dataSource = HttpGeoapifyPlacesDataSource(
        client: client,
        apiKey: 'test_key',
      );

      final results = await dataSource.fetchNearbyPlaces(
        location: const GeoCoordinates(-6.2297, 106.8295),
      );

      expect(results.length, 1);
      expect(results.first.geoapifyPlaceId, 'dup_101');
    });
  });

  group('8. Stable canonical venue identity', () {
    test(
      'Geoapify venue preserves stable canonical key across lookups and merges',
      () {
        const geoapifyId = 'geo_blokm_777';
        final identity = PlaceIdentity.geoapify(geoapifyId);
        expect(identity.canonicalKey, 'geoapify:geo_blokm_777');
        expect(identity.primarySource, PlaceSource.geoapify);

        const geoPlace = GeoapifyPlaceData(
          geoapifyPlaceId: geoapifyId,
          name: 'Blok M Coffee',
          location: GeoCoordinates(-6.2440, 106.8000),
        );

        final place = Place.fromSources(geoapify: geoPlace);
        expect(place.id, 'geoapify:geo_blokm_777');
        expect(place.source, PlaceSource.geoapify);
        expect(place.geoapifyPlaceId, 'geo_blokm_777');
      },
    );
  });

  group('9. Network timeout', () {
    test('Throws GeoapifyNetworkException on HTTP timeout', () async {
      final client = MockHttpClient((req) async {
        throw TimeoutException('Request timed out');
      });

      final dataSource = HttpGeoapifyPlacesDataSource(
        client: client,
        apiKey: 'test_key',
      );

      expect(
        () => dataSource.fetchNearbyPlaces(
          location: const GeoCoordinates(-6.2297, 106.8295),
        ),
        throwsA(isA<GeoapifyNetworkException>()),
      );
    });
  });

  group('10. HTTP errors', () {
    test('Throws GeoapifyAuthException on HTTP 401 / 403', () async {
      final client401 = MockHttpClient(
        (req) async => http.Response('Unauthorized', 401),
      );
      final ds401 = HttpGeoapifyPlacesDataSource(
        client: client401,
        apiKey: 'bad_key',
      );

      expect(
        () => ds401.fetchNearbyPlaces(
          location: const GeoCoordinates(-6.2297, 106.8295),
        ),
        throwsA(isA<GeoapifyAuthException>()),
      );

      final client403 = MockHttpClient(
        (req) async => http.Response('Forbidden', 403),
      );
      final ds403 = HttpGeoapifyPlacesDataSource(
        client: client403,
        apiKey: 'forbidden_key',
      );

      expect(
        () => ds403.fetchNearbyPlaces(
          location: const GeoCoordinates(-6.2297, 106.8295),
        ),
        throwsA(isA<GeoapifyAuthException>()),
      );
    });

    test('Throws GeoapifyServerException on HTTP 500+', () async {
      final client500 = MockHttpClient(
        (req) async => http.Response('Internal Server Error', 500),
      );
      final ds500 = HttpGeoapifyPlacesDataSource(
        client: client500,
        apiKey: 'test_key',
      );

      expect(
        () => ds500.fetchNearbyPlaces(
          location: const GeoCoordinates(-6.2297, 106.8295),
        ),
        throwsA(isA<GeoapifyServerException>()),
      );
    });
  });

  group('11. Rate limiting', () {
    test('Throws GeoapifyRateLimitException on HTTP 429', () async {
      final client429 = MockHttpClient(
        (req) async => http.Response('Rate limit exceeded', 429),
      );
      final ds429 = HttpGeoapifyPlacesDataSource(
        client: client429,
        apiKey: 'test_key',
      );

      expect(
        () => ds429.fetchNearbyPlaces(
          location: const GeoCoordinates(-6.2297, 106.8295),
        ),
        throwsA(isA<GeoapifyRateLimitException>()),
      );
    });
  });

  group('12. Repository provider integration', () {
    test(
      'GeoapifyPlaceRepository queries dataSource, merges places, and sorts correctly',
      () async {
        final client = MockHttpClient((req) async {
          if (req.url.queryParameters['name'] == 'Cofilab') {
            return http.Response(
              json.encode({
                'type': 'FeatureCollection',
                'features': [(sampleGeoJson['features'] as List)[0]],
              }),
              200,
            );
          }
          return http.Response(json.encode(sampleGeoJson), 200);
        });

        final dataSource = HttpGeoapifyPlacesDataSource(
          client: client,
          apiKey: 'test_key',
        );
        final repository = GeoapifyPlaceRepository(dataSource: dataSource);

        final places = await repository.getNearbyPlaces(
          origin: const GeoCoordinates(-6.2297, 106.8295),
        );

        expect(places.length, 2);
        expect(places[0].id, 'geoapify:geo_cafe_001');
        expect(places[0].source, PlaceSource.geoapify);
        expect(places[0].distanceKm, 0.0); // Exactly at origin

        // Search with text
        final searchResults = await repository.searchPlaces(
          const PlaceSearchQuery(
            text: 'Cofilab',
            origin: GeoCoordinates(-6.2297, 106.8295),
          ),
        );
        expect(searchResults.length, 1);
        expect(searchResults.first.name, 'Cofilab Jakarta');
      },
    );
  });

  group('13. Firebase bookmark compatibility', () {
    test(
      'Geoapify place can be bookmarked and retrieved with stable canonical key',
      () async {
        final savedPlacesRepo = SavedPlacesRepository();

        const geoPlace = GeoapifyPlaceData(
          geoapifyPlaceId: 'geo_save_99',
          name: 'Saved Geoapify Cafe',
          location: GeoCoordinates(-6.2297, 106.8295),
        );
        final place = Place.fromSources(geoapify: geoPlace);

        final savedItem = SavedPlaceItem.fromPlace(place);
        expect(savedItem.placeId, 'geoapify:geo_save_99');
        expect(savedItem.source, 'geoapify');

        // Save place in repository cache
        await savedPlacesRepo.savePlace('user_abc', place);
        final isSaved = await savedPlacesRepo.isPlaceSaved(
          'user_abc',
          'geoapify:geo_save_99',
        );
        expect(isSaved, isTrue);

        // Unsave place
        await savedPlacesRepo.removeSavedPlace(
          'user_abc',
          'geoapify:geo_save_99',
        );
        final isSavedAfter = await savedPlacesRepo.isPlaceSaved(
          'user_abc',
          'geoapify:geo_save_99',
        );
        expect(isSavedAfter, isFalse);
      },
    );
  });

  group('14. Community review compatibility', () {
    test(
      'Reviews reference canonical Geoapify place ID without colliding with provider data',
      () async {
        final reviewRepo = ReviewRepository();
        const user = UserProfile(uid: 'reg_user_1', name: 'Budi Belajar');

        await reviewRepo.publishReview(
          placeId: 'geoapify:geo_cafe_001',
          user: user,
          rating: 5.0,
          comment: 'Sangat nyaman untuk nugas di Kuningan!',
          wifiRating: 5.0,
          outletRating: 4.5,
          comfortRating: 4.0,
          noiseRating: 4.5,
          priceValueRating: 4.0,
          visitPurpose: 'Skripsi',
        );

        final reviews = await reviewRepo
            .streamReviews('geoapify:geo_cafe_001')
            .first;
        expect(reviews.length, 1);
        expect(reviews.first.placeId, 'geoapify:geo_cafe_001');
        expect(reviews.first.comment, contains('Kuningan'));
      },
    );
  });

  group('15. Guest permission regression', () {
    test('Guest user cannot publish review on Geoapify venue', () async {
      final reviewRepo = ReviewRepository();

      const guestProfile = UserProfile(
        uid: 'guest_user_99',
        name: 'Tamu SpotNugas',
        isGuest: true,
      );

      expect(
        () => reviewRepo.publishReview(
          placeId: 'geoapify:geo_cafe_001',
          user: guestProfile,
          rating: 4.0,
          comment: 'Mencoba submit review',
        ),
        throwsA(isA<ReviewException>()),
      );
    });
  });

  group('16. Skor Nugas regression', () {
    test(
      'Geoapify place without reviews shows no Skor Nugas, updates dynamically with reviews',
      () {
        final reviewRepo = ReviewRepository();

        const geoPlace = GeoapifyPlaceData(
          geoapifyPlaceId: 'geo_cafe_scores',
          name: 'Fresh Geoapify Spot',
          location: GeoCoordinates(-6.2297, 106.8295),
        );
        final place = Place.fromSources(geoapify: geoPlace);

        // 1. Without reviews: resolvedStudyScore is null, label is Belum Dinilai
        expect(place.resolvedStudyScore, isNull);
        expect(place.studyScoreLabel, 'Belum Dinilai');

        // 2. Add community review with scores
        final review = PlaceReviewModel(
          id: 'rev_score',
          placeId: place.id,
          userId: 'reviewer_1',
          userName: 'Mahasiswa UI',
          rating: 5.0,
          wifiRating: 5.0, // weight 0.25
          outletRating: 5.0, // weight 0.20
          comfortRating: 5.0, // weight 0.20
          noiseRating: 5.0, // weight 0.15
          priceValueRating: 5.0, // weight 0.10
          visitPurpose: 'Belajar',
          comment: 'Tempat sempurna untuk nugas',
          createdAt: DateTime.now(),
        );

        final dynamicScore = reviewRepo.computeDynamicSkorNugas(
          place: place,
          reviews: [review],
        );

        expect(dynamicScore, 10.0);
      },
    );
  });

  group('17. Missing photo and metadata UI states', () {
    testWidgets(
      'PlaceCard and PlaceDetailScreen render without crashing when photos are absent',
      (tester) async {
        const emptyPhotoPlace = GeoapifyPlaceData(
          geoapifyPlaceId: 'geo_no_photo_01',
          name: 'Tanpa Foto Cafe',
          location: GeoCoordinates(-6.2297, 106.8295),
          photoUrls: [],
        );

        final place = Place.fromSources(geoapify: emptyPhotoPlace);
        expect(place.photoUrls, isEmpty);
        expect(place.image, isEmpty);

        // 1. PlaceCard test
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: PlaceCard(place: place)),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Tanpa Foto Cafe'), findsOneWidget);
        expect(find.byIcon(Icons.coffee_rounded), findsOneWidget);

        // 2. PlaceDetailScreen test
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: PlaceDetailScreen(place: place)),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Tanpa Foto Cafe'), findsOneWidget);
        expect(find.text(GeoapifyConfig.attributionText), findsOneWidget);
      },
    );
  });

  group('18. Live category taxonomy & radius expansion fallback', () {
    test(
      'Maps general-to-specific Geoapify categories to Indonesian display label and expands radius when 5km is empty',
      () async {
        final requestedFilters = <String>[];
        final client = MockHttpClient((req) async {
          final filter = req.url.queryParameters['filter'] ?? '';
          requestedFilters.add(filter);
          if (filter.endsWith(',5000')) {
            return http.Response(
              json.encode({'type': 'FeatureCollection', 'features': []}),
              200,
            );
          }
          return http.Response(
            json.encode({
              'type': 'FeatureCollection',
              'features': [
                {
                  'type': 'Feature',
                  'properties': {
                    'place_id': 'geo_suburb_cafe_01',
                    'name': 'Kopi Pinggiran Kota',
                    'categories': [
                      'catering',
                      'catering.cafe',
                      'catering.cafe.coffee_shop',
                    ],
                    'formatted': 'Jl. Raya Bogor, Depok',
                    'lat': -6.3500,
                    'lon': 106.8300,
                  },
                  'geometry': {
                    'type': 'Point',
                    'coordinates': [106.8300, -6.3500],
                  },
                },
              ],
            }),
            200,
          );
        });

        final dataSource = HttpGeoapifyPlacesDataSource(
          client: client,
          apiKey: 'test_key',
        );
        final repository = GeoapifyPlaceRepository(dataSource: dataSource);

        final places = await repository.getNearbyPlaces(
          origin: const GeoCoordinates(-6.4025, 106.7942),
        );

        expect(requestedFilters.length, 2);
        expect(requestedFilters[0], contains(',5000'));
        expect(requestedFilters[1], contains(',20000'));
        expect(places.length, 1);
        expect(places.first.name, 'Kopi Pinggiran Kota');
        expect(places.first.category, 'Cafe');
      },
    );
  });

  group('19. GPS integrity and search center preservation', () {
    test(
      'Empty search results at an arbitrary origin (e.g. Mountain View) never query Jakarta or replace the search center',
      () async {
        final requests = <Uri>[];
        final client = MockHttpClient((req) async {
          requests.add(req.url);
          // Return 0 places for all queries
          return http.Response(
            json.encode({'type': 'FeatureCollection', 'features': []}),
            200,
          );
        });

        final dataSource = HttpGeoapifyPlacesDataSource(
          client: client,
          apiKey: 'test_key',
        );
        final repository = GeoapifyPlaceRepository(dataSource: dataSource);

        const testOrigin = GeoCoordinates(37.4219983, -122.084);
        final places = await repository.getNearbyPlaces(origin: testOrigin);

        expect(places, isEmpty);
        expect(requests, hasLength(2));
        expect(requests.map((request) => request.queryParameters['filter']), [
          'circle:-122.084000,37.421998,5000',
          'circle:-122.084000,37.421998,20000',
        ]);
        for (final request in requests) {
          expect(
            request.queryParameters['bias'],
            'proximity:-122.084000,37.421998',
          );
        }
      },
    );

    test(
      'Manually selected locations (Jakarta, Bandung, Depok) preserve their search origin',
      () async {
        final requests = <Uri>[];
        final client = MockHttpClient((req) async {
          requests.add(req.url);
          return http.Response(
            json.encode({'type': 'FeatureCollection', 'features': []}),
            200,
          );
        });

        final dataSource = HttpGeoapifyPlacesDataSource(
          client: client,
          apiKey: 'test_key',
        );
        final repository = GeoapifyPlaceRepository(dataSource: dataSource);

        for (final origin in [
          AppLocation.defaultJakarta,
          AppLocation.bandung,
          AppLocation.depok,
        ]) {
          requests.clear();
          await repository.getNearbyPlaces(origin: origin);
          final center =
              '${origin.longitude.toStringAsFixed(6)},${origin.latitude.toStringAsFixed(6)}';
          expect(requests, hasLength(2));
          expect(requests.map((request) => request.queryParameters['filter']), [
            'circle:$center,5000',
            'circle:$center,20000',
          ]);
          expect(requests.map((request) => request.queryParameters['bias']), [
            'proximity:$center',
            'proximity:$center',
          ]);
        }
      },
    );

    for (final statusCode in [401, 429, 500]) {
      test(
        'HTTP $statusCode propagates without retrying another center',
        () async {
          final requests = <Uri>[];
          final dataSource = HttpGeoapifyPlacesDataSource(
            client: MockHttpClient((req) async {
              requests.add(req.url);
              return http.Response('API failure', statusCode);
            }),
            apiKey: 'test_key',
          );
          final repository = GeoapifyPlaceRepository(dataSource: dataSource);

          await expectLater(
            repository.getNearbyPlaces(
              origin: const GeoCoordinates(37.4219983, -122.084),
            ),
            throwsA(
              isA<GeoapifyException>().having(
                (error) => error.statusCode,
                'statusCode',
                statusCode,
              ),
            ),
          );
          expect(requests, hasLength(1));
          expect(
            requests.single.queryParameters['filter'],
            'circle:-122.084000,37.421998,5000',
          );
        },
      );
    }

    test('An error during radius expansion remains an error', () async {
      final requests = <Uri>[];
      final dataSource = HttpGeoapifyPlacesDataSource(
        client: MockHttpClient((req) async {
          requests.add(req.url);
          if (requests.length == 1) {
            return http.Response(json.encode({'features': []}), 200);
          }
          throw TimeoutException('Request timed out');
        }),
        apiKey: 'test_key',
      );
      final repository = GeoapifyPlaceRepository(dataSource: dataSource);

      await expectLater(
        repository.getNearbyPlaces(origin: AppLocation.bandung),
        throwsA(isA<GeoapifyNetworkException>()),
      );
      expect(requests.map((request) => request.queryParameters['filter']), [
        'circle:107.619100,-6.917500,5000',
        'circle:107.619100,-6.917500,20000',
      ]);
    });
  });

  group('20. Honest API errors and safe diagnostics', () {
    final malformedBodies = <String, String>{
      'invalid JSON': '{invalid-json',
      'a non-object response': '[]',
      'missing features': '{}',
      'null features': '{"features":null}',
      'non-list features': '{"features":{}}',
      'a non-object feature': '{"features":[null]}',
      'a feature without a place ID': '{"features":[{"properties":{}}]}',
    };

    for (final entry in malformedBodies.entries) {
      test('HTTP 200 with ${entry.key} raises a server error', () async {
        var requestCount = 0;
        final repository = GeoapifyPlaceRepository(
          dataSource: HttpGeoapifyPlacesDataSource(
            client: MockHttpClient((req) async {
              requestCount++;
              return http.Response(entry.value, 200);
            }),
            apiKey: 'test_key',
          ),
        );

        await expectLater(
          repository.getNearbyPlaces(origin: AppLocation.bandung),
          throwsA(isA<GeoapifyServerException>()),
        );
        expect(requestCount, 1);
      });
    }

    test(
      'Network and parse errors never expose credentials in diagnostics',
      () async {
        const sentinel = 'sentinel-secret-do-not-log';
        final messages = <String>[];
        final originalDebugPrint = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message != null) messages.add(message);
        };
        addTearDown(() => debugPrint = originalDebugPrint);

        final clients = [
          MockHttpClient((req) async {
            throw http.ClientException('Request failed: $sentinel', req.url);
          }),
          MockHttpClient((req) async {
            throw const SocketException('Connection failed: $sentinel');
          }),
          MockHttpClient((req) async {
            return http.Response('{"features":[$sentinel]}', 200);
          }),
        ];

        for (final client in clients) {
          final dataSource = HttpGeoapifyPlacesDataSource(
            client: client,
            apiKey: sentinel,
          );
          await expectLater(
            dataSource.fetchNearbyPlaces(location: AppLocation.bandung),
            throwsA(
              isA<GeoapifyException>().having(
                (error) => error.message,
                'safe message',
                allOf(isNot(contains(sentinel)), isNot(contains('apiKey='))),
              ),
            ),
          );
        }
        expect(messages, isNotEmpty);
        expect(messages.join('\n'), isNot(contains(sentinel)));
        expect(messages.join('\n'), isNot(contains('apiKey=')));
      },
    );

    test('Details distinguish an absent venue from an API failure', () async {
      final emptyDataSource = HttpGeoapifyPlacesDataSource(
        client: MockHttpClient((req) async {
          return http.Response(json.encode({'features': []}), 200);
        }),
        apiKey: 'test_key',
      );
      expect(await emptyDataSource.getPlaceDetails('missing-place'), isNull);

      for (final statusCode in [401, 429, 500]) {
        final dataSource = HttpGeoapifyPlacesDataSource(
          client: MockHttpClient((req) async {
            return http.Response('API failure', statusCode);
          }),
          apiKey: 'test_key',
        );
        await expectLater(
          dataSource.getPlaceDetails('place-id'),
          throwsA(
            isA<GeoapifyException>().having(
              (error) => error.statusCode,
              'statusCode',
              statusCode,
            ),
          ),
        );
      }
    });
  });
}
