import '../config/places_api_config.dart';
import '../data/place_mock_data.dart';
import '../models/google_place_data.dart';
import '../models/place_types.dart';

/// Contract for fetching public place data from Google Places API (New).
///
/// In Phase C2A, live HTTP requests are strictly offline-safe.
/// The [MockGooglePlacesDataSource] implementation serves seed data
/// for offline development and testing without making network calls.
abstract class GooglePlacesDataSource {
  /// Searches for places around [location] within [radiusMeters].
  Future<List<GooglePlaceData>> searchNearby({
    required GeoCoordinates location,
    double radiusMeters = PlacesApiConfig.defaultSearchRadiusMeters,
    String? pageToken,
  });

  /// Searches for places matching [text] with an optional location bias.
  Future<List<GooglePlaceData>> searchByText(
    String text, {
    GeoCoordinates? location,
    double? radiusMeters,
  });

  /// Retrieves comprehensive place details for [googlePlaceId].
  Future<GooglePlaceData?> getPlaceDetails(String googlePlaceId);
}

/// Offline mock data source providing simulated Google Places API responses
/// from local seed data with zero network calls and zero cost.
class MockGooglePlacesDataSource implements GooglePlacesDataSource {
  const MockGooglePlacesDataSource();

  List<GooglePlaceData> get _allMockGooglePlaces {
    final list = <GooglePlaceData>[];
    for (final p in PlaceMockData.places) {
      if (p.isGoogleSourced && p.googlePlaceId != null) {
        list.add(
          GooglePlaceData(
            googlePlaceId: p.googlePlaceId!,
            name: p.name,
            location: p.coordinates,
            primaryType: p.category,
            formattedAddress: p.address,
            rating: p.googleRating,
            userRatingCount: p.googleRatingCount,
            priceLevel: p.priceLevel,
            priceRange: p.priceRange,
            openingHours: p.openingHours,
            isOpenNow: p.isOpenNow,
            photoUrls: p.photoUrls,
          ),
        );
      }
    }
    return list;
  }

  @override
  Future<List<GooglePlaceData>> searchNearby({
    required GeoCoordinates location,
    double radiusMeters = PlacesApiConfig.defaultSearchRadiusMeters,
    String? pageToken,
  }) async {
    final radiusKm = radiusMeters / 1000.0;
    return _allMockGooglePlaces.where((gp) {
      final dist = location.distanceKmTo(gp.location);
      return dist <= radiusKm;
    }).toList();
  }

  @override
  Future<List<GooglePlaceData>> searchByText(
    String text, {
    GeoCoordinates? location,
    double? radiusMeters,
  }) async {
    final q = text.toLowerCase().trim();
    if (q.isEmpty) return _allMockGooglePlaces;

    return _allMockGooglePlaces.where((gp) {
      return gp.name.toLowerCase().contains(q) ||
          (gp.primaryType?.toLowerCase().contains(q) ?? false) ||
          (gp.formattedAddress?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Future<GooglePlaceData?> getPlaceDetails(String googlePlaceId) async {
    for (final gp in _allMockGooglePlaces) {
      if (gp.googlePlaceId == googlePlaceId) return gp;
    }
    return null;
  }
}
