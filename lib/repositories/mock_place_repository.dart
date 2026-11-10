import '../constants/app_location.dart';
import '../data/place_mock_data.dart';
import '../models/place.dart';
import 'place_repository.dart';

/// In-memory [PlaceRepository] backed by [PlaceMockData].
///
/// - No network, no Firestore.
/// - Returns the *same* [Place] instances on every call so the session-only
///   `isSaved` toggle stays consistent across screens (pre-C1 behaviour).
/// - `getNearbyPlaces` keeps the curated seed order so existing screens
///   (featured card, carousels, mock map markers) render exactly as before
///   when queried from the mock Yogyakarta origin.
/// - When queried from an external origin (e.g. Jakarta target), calculates
///   real geographic distance and does not present mock Yogyakarta distances
///   as real Jakarta distances.
class MockPlaceRepository implements PlaceRepository {
  MockPlaceRepository({List<Place>? places})
    : _places = places ?? PlaceMockData.places;

  final List<Place> _places;

  Iterable<Place> get _visible => _places.where((p) => p.isVisible);

  double _distanceFrom(Place place, GeoCoordinates? origin) {
    if (origin == null) return place.distanceKm ?? double.infinity;
    if (origin == AppLocation.mockYogyakartaOrigin) {
      return place.distanceKm ?? 0.0;
    }
    return origin.distanceKmTo(place.coordinates);
  }

  Place _placeWithDistance(Place place, GeoCoordinates? origin) {
    if (origin == null || origin == AppLocation.mockYogyakartaOrigin) {
      return place;
    }
    final dist = origin.distanceKmTo(place.coordinates);
    return place.copyWithDistance((dist * 10).round() / 10);
  }

  @override
  Future<List<Place>> getNearbyPlaces({
    required GeoCoordinates origin,
    double radiusKm = 5.0,
    int? limit,
  }) async {
    Iterable<Place> results = _visible
        .where((p) => _distanceFrom(p, origin) <= radiusKm)
        .map((p) => _placeWithDistance(p, origin));

    if (limit != null) results = results.take(limit);
    return results.toList();
  }

  @override
  Future<List<Place>> searchPlaces(PlaceSearchQuery query) async {
    final text = query.text.toLowerCase().trim();
    final tag = query.tag;
    final origin = query.origin;

    final results = _visible
        .where((p) {
          if (tag != null && !p.tags.contains(tag)) return false;
          if (text.isEmpty) return true;
          return p.name.toLowerCase().contains(text) ||
              p.category.toLowerCase().contains(text) ||
              p.tags.any((t) => t.toLowerCase().contains(text)) ||
              (p.address?.toLowerCase().contains(text) ?? false) ||
              (p.description?.toLowerCase().contains(text) ?? false);
        })
        .map((p) => _placeWithDistance(p, origin))
        .toList();

    results.sort(query.sort.compare);

    final limit = query.limit;
    return limit != null ? results.take(limit).toList() : results;
  }

  @override
  Future<Place?> getPlaceById(String id) async {
    for (final place in _visible) {
      if (place.id == id ||
          place.geoapifyPlaceId == id ||
          place.googlePlaceId == id ||
          place.aliases.contains(id)) {
        return place;
      }
    }
    return null;
  }
}
