import 'google_attribution.dart';
import 'place_types.dart';

/// Public, third-party place information as returned by Google Places.
///
/// This is intentionally a *transient* DTO:
/// - it is fetched at runtime by a future `GooglePlacesDataSource`,
/// - it is **never** written to Firestore (there is deliberately no `toMap`),
///   because SpotNugas should not keep a permanent copy of Google content.
///   Only `googlePlaceId` is persisted, inside `SpotNugasPlaceData`.
///
/// No Google SDK types are used here so the domain stays dependency-free.
class GooglePlaceData {
  /// Google's stable place identifier (`places/{id}` → `id`).
  final String googlePlaceId;

  final String name;

  /// Google's localized primary type, e.g. `Coffee shop`.
  final String? primaryType;

  final String? formattedAddress;
  final GeoCoordinates location;

  final double? rating;
  final int? userRatingCount;

  final PlacePriceLevel? priceLevel;
  final PlacePriceRange? priceRange;

  final PlaceOpeningHours? openingHours;
  final bool? isOpenNow;

  /// Resolved photo URLs (or local asset paths for mock data).
  final List<String> photoUrls;

  /// Required author attributions under Google Maps Platform policy.
  final List<GoogleAttribution> attributions;

  const GooglePlaceData({
    required this.googlePlaceId,
    required this.name,
    required this.location,
    this.primaryType,
    this.formattedAddress,
    this.rating,
    this.userRatingCount,
    this.priceLevel,
    this.priceRange,
    this.openingHours,
    this.isOpenNow,
    this.photoUrls = const [],
    this.attributions = const [],
  });
}
