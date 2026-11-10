import 'place_types.dart';

/// Public, third-party place information as returned by the Geoapify Places API.
///
/// This is intentionally a *transient* DTO:
/// - it is fetched at runtime by Geoapify data sources,
/// - it is **never** written directly to Firestore (deliberately no `toMap`),
///   because SpotNugas only stores curated productivity overlays at `places/{id}`,
///   not vendor-owned third-party copies.
/// - Only `geoapifyPlaceId` is referenced inside `SpotNugasPlaceData`.
class GeoapifyPlaceData {
  /// Geoapify's stable place identifier (`properties.place_id`).
  final String geoapifyPlaceId;

  final String name;

  /// Primary type/category display label, e.g. `Cafe` or `Coworking Space`.
  final String? primaryCategory;

  /// Full category taxonomy from Geoapify, e.g. `['catering', 'catering.cafe']`.
  final List<String> categories;

  final String? formattedAddress;
  final GeoCoordinates location;

  final PlaceOpeningHours? openingHours;
  final bool? isOpenNow;

  final PlacePriceLevel? priceLevel;
  final PlacePriceRange? priceRange;

  /// Photo URLs or local assets for demo/mock seeds.
  final List<String> photoUrls;

  final String? contactPhone;
  final String? website;

  /// Underlying source, e.g. `openstreetmap`.
  final String? datasource;

  const GeoapifyPlaceData({
    required this.geoapifyPlaceId,
    required this.name,
    required this.location,
    this.primaryCategory,
    this.categories = const [],
    this.formattedAddress,
    this.openingHours,
    this.isOpenNow,
    this.priceLevel,
    this.priceRange,
    this.photoUrls = const [],
    this.contactPhone,
    this.website,
    this.datasource,
  });

  /// Factory from standard Geoapify GeoJSON Feature object.
  ///
  /// Defensive parsing with coordinate validation, bounds clamping,
  /// detection of reversed coordinate ordering, and fallbacks for missing properties.
  factory GeoapifyPlaceData.fromGeoJson(Map<String, dynamic> feature) {
    final properties =
        (feature['properties'] as Map<String, dynamic>?) ?? feature;
    final geometry = feature['geometry'] as Map<String, dynamic>?;

    final rawPlaceId =
        (properties['place_id'] as String?) ??
        (properties['id'] as String?) ??
        (feature['id'] as String?);
    final placeId = (rawPlaceId != null && rawPlaceId.trim().isNotEmpty)
        ? rawPlaceId.trim()
        : '';

    final rawName = properties['name'] as String?;
    final name = (rawName != null && rawName.trim().isNotEmpty)
        ? rawName.trim()
        : 'Tempat Tanpa Nama';

    // Parse coordinates from geometry.coordinates [lng, lat] or properties.lon / properties.lat
    double rawLng = 0.0;
    double rawLat = 0.0;
    if (geometry != null && geometry['coordinates'] is List) {
      final coords = geometry['coordinates'] as List;
      if (coords.length >= 2) {
        rawLng = _parseCoordinate(coords[0]);
        rawLat = _parseCoordinate(coords[1]);
      }
    } else {
      rawLat = _parseCoordinate(properties['lat']);
      rawLng = _parseCoordinate(properties['lon']);
    }

    // Detect and correct reversed coordinates: GeoJSON standard is [longitude, latitude].
    // If rawLat exceeds 90 (e.g. Jakarta lon ~106.8295 accidentally placed in lat) and rawLng is <= 90:
    double lat = rawLat;
    double lng = rawLng;
    if (lat.abs() > 90.0 && lng.abs() <= 90.0) {
      final temp = lat;
      lat = lng;
      lng = temp;
    }

    // Clamp coordinates to safe valid geographic bounds to prevent assertions from throwing
    lat = lat.clamp(-90.0, 90.0);
    lng = lng.clamp(-180.0, 180.0);

    final rawCategories = properties['categories'] as List?;
    final categories = rawCategories?.map((c) => c.toString()).toList() ?? [];

    String? primaryCat;
    if (categories.isNotEmpty) {
      primaryCat = categories.firstWhere(
        (c) =>
            c == 'catering.cafe' ||
            c == 'office.coworking' ||
            c == 'education.library',
        orElse: () => categories.firstWhere(
          (c) => c.contains('.'),
          orElse: () => categories.first,
        ),
      );
    }

    final formattedAddress =
        (properties['formatted'] as String?) ??
        (properties['address_line2'] as String?) ??
        (properties['street'] != null
            ? '${properties['street']}, ${properties['city'] ?? ''}'
            : null);

    // Opening hours parsing
    final rawHours = properties['opening_hours'] as String?;
    PlaceOpeningHours? hours;
    if (rawHours != null && rawHours.isNotEmpty) {
      hours = PlaceOpeningHours(statusLabel: rawHours);
    }

    return GeoapifyPlaceData(
      geoapifyPlaceId: placeId,
      name: name,
      location: GeoCoordinates(lat, lng),
      primaryCategory: primaryCat,
      categories: categories,
      formattedAddress: formattedAddress,
      openingHours: hours,
      isOpenNow: properties['is_open'] as bool?,
      contactPhone: properties['contact']?['phone'] as String?,
      website: properties['website'] as String?,
      datasource: properties['datasource']?['sourcename'] as String?,
    );
  }

  static double _parseCoordinate(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }
}
