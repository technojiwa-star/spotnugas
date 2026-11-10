import '../models/place.dart';

/// Sort orders supported by place search.
enum PlaceSortOption { studyScore, distance, rating, price }

extension PlaceSortOptionComparator on PlaceSortOption {
  /// Comparator shared by all repository implementations so results are
  /// ordered identically regardless of the data source. Unknown values
  /// always sort last.
  int compare(Place a, Place b) {
    switch (this) {
      case PlaceSortOption.studyScore:
        return _compareNullable(
          a.resolvedStudyScore,
          b.resolvedStudyScore,
          descending: true,
        );
      case PlaceSortOption.distance:
        return _compareNullable(a.distanceKm, b.distanceKm);
      case PlaceSortOption.rating:
        return _compareNullable(
          a.displayRating,
          b.displayRating,
          descending: true,
        );
      case PlaceSortOption.price:
        return _compareNullable(a.priceLevel?.rank, b.priceLevel?.rank);
    }
  }

  static int _compareNullable(num? a, num? b, {bool descending = false}) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return descending ? b.compareTo(a) : a.compareTo(b);
  }
}

/// Parameters for [PlaceRepository.searchPlaces].
class PlaceSearchQuery {
  /// Free text matched against name, category, tags, address, description.
  final String text;

  /// Optional highlight tag filter (e.g. `Wi-Fi Cepat`). `null` = no filter.
  final String? tag;

  final PlaceSortOption sort;

  /// Origin used to compute distances. Mock data ships fixed distances.
  final GeoCoordinates? origin;

  final int? limit;

  const PlaceSearchQuery({
    this.text = '',
    this.tag,
    this.sort = PlaceSortOption.studyScore,
    this.origin,
    this.limit,
  });

  @override
  bool operator ==(Object other) =>
      other is PlaceSearchQuery &&
      other.text == text &&
      other.tag == tag &&
      other.sort == sort &&
      other.origin == origin &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(text, tag, sort, origin, limit);
}

/// Domain-facing access to places. The UI depends on this abstraction only.
///
/// C1 ships [MockPlaceRepository]. A later implementation will compose:
/// - `GooglePlacesDataSource`   → public Google data (transient),
/// - `FirestorePlaceDataSource` → SpotNugas overlays keyed by googlePlaceId,
/// - `ManualPlaceDataSource`    → SpotNugas-only places,
/// merging them with `Place.fromSources`. Implementations must only return
/// visible places (`Place.isVisible`); partner status never filters results.
abstract class PlaceRepository {
  /// Places around [origin] within [radiusKm], in the repository's default
  /// ranking.
  Future<List<Place>> getNearbyPlaces({
    required GeoCoordinates origin,
    double radiusKm = 5.0,
    int? limit,
  });

  Future<List<Place>> searchPlaces(PlaceSearchQuery query);

  /// Looks up by SpotNugas id (or Google place id). `null` when not found or
  /// inactive.
  Future<Place?> getPlaceById(String id);
}
