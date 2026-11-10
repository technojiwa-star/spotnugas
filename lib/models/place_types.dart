import 'dart:math' as math;

/// Shared enums and value objects for the SpotNugas place domain.
///
/// Every enum carries a stable wire `value` that is used for persistence
/// (Firestore) so that Dart identifier renames never break stored data.

T? _enumByValue<T extends Enum>(
  List<T> values,
  String Function(T) valueOf,
  Object? raw,
) {
  if (raw is! String) return null;
  for (final candidate in values) {
    if (valueOf(candidate) == raw) return candidate;
  }
  return null;
}

/// Where the canonical public information of a place comes from.
enum PlaceSource {
  /// Public info (name, address, hours, photos) comes from
  /// Geoapify Places API at runtime. SpotNugas stores an overlay
  /// with productivity data keyed by canonical place key.
  geoapify('geoapify'),

  /// Public info comes from Google Places at runtime.
  google('google'),

  /// The place is managed directly in SpotNugas. SpotNugas owns all data.
  manual('manual');

  const PlaceSource(this.value);

  final String value;

  static PlaceSource? tryParse(Object? raw) =>
      _enumByValue(values, (e) => e.value, raw);
}

/// Moderation state for places that SpotNugas owns (manual places).
///
/// Google places do not need this: their existence is vouched for by Google.
enum PlaceVerificationStatus {
  unverified('unverified'),
  pending('pending'),
  verified('verified'),
  rejected('rejected');

  const PlaceVerificationStatus(this.value);

  final String value;

  static PlaceVerificationStatus? tryParse(Object? raw) =>
      _enumByValue(values, (e) => e.value, raw);
}

/// Price level, aligned with the Google Places API (New) enum strings so the
/// same wire value works for Google-sourced and manual places.
enum PlacePriceLevel {
  free('PRICE_LEVEL_FREE', 0, 'Gratis'),
  inexpensive('PRICE_LEVEL_INEXPENSIVE', 1, 'Murah'),
  moderate('PRICE_LEVEL_MODERATE', 2, 'Sedang'),
  expensive('PRICE_LEVEL_EXPENSIVE', 3, 'Mahal'),
  veryExpensive('PRICE_LEVEL_VERY_EXPENSIVE', 4, 'Sangat Mahal');

  const PlacePriceLevel(this.value, this.rank, this.label);

  final String value;

  /// Ordinal used for "cheapest first" sorting.
  final int rank;

  /// Indonesian display label.
  final String label;

  static PlacePriceLevel? tryParse(Object? raw) =>
      _enumByValue(values, (e) => e.value, raw);
}

/// SpotNugas-curated facility relevant for studying / working.
enum PlaceFacility {
  wifi('wifi', 'Wi-Fi'),
  powerOutlet('power_outlet', 'Colokan'),
  airConditioning('air_conditioning', 'AC'),
  prayerRoom('prayer_room', 'Musala'),
  parking('parking', 'Parkir'),
  groupSeating('group_seating', 'Cocok Kelompok'),
  quietZone('quiet_zone', 'Zona Hening'),
  meetingRoom('meeting_room', 'Meeting Room'),
  outdoorSeating('outdoor_seating', 'Outdoor');

  const PlaceFacility(this.value, this.label);

  final String value;
  final String label;

  static PlaceFacility? tryParse(Object? raw) =>
      _enumByValue(values, (e) => e.value, raw);
}

/// SpotNugas-curated ambience of a place.
enum PlaceAtmosphere {
  silent('silent', 'Hening'),
  calm('calm', 'Tenang'),
  moderate('moderate', 'Sedang'),
  lively('lively', 'Ramai'),
  outdoor('outdoor', 'Outdoor');

  const PlaceAtmosphere(this.value, this.label);

  final String value;
  final String label;

  static PlaceAtmosphere? tryParse(Object? raw) =>
      _enumByValue(values, (e) => e.value, raw);
}

/// SpotNugas-curated use cases a place is suitable for.
enum PlaceSuitability {
  soloFocus('solo_focus', 'Fokus Sendiri'),
  groupWork('group_work', 'Nugas Kelompok'),
  budgetFriendly('budget_friendly', 'Hemat'),
  lateNight('late_night', 'Buka Malam'),
  remoteWork('remote_work', 'Remote Work'),
  thesisResearch('thesis_research', 'Skripsi & Riset');

  const PlaceSuitability(this.value, this.label);

  final String value;
  final String label;

  static PlaceSuitability? tryParse(Object? raw) =>
      _enumByValue(values, (e) => e.value, raw);
}

/// Parses a list of enum wire values, silently skipping unknown entries so
/// that older clients tolerate newer values written by newer clients.
List<T> parseEnumList<T>(Object? raw, T? Function(Object?) parse) {
  if (raw is! Iterable) return const [];
  return List.unmodifiable(raw.map(parse).whereType<T>());
}

/// Plain latitude/longitude pair. Deliberately independent of Firestore's
/// `GeoPoint` and Google Maps' `LatLng` so the domain has no SDK coupling.
class GeoCoordinates {
  final double latitude;
  final double longitude;

  const GeoCoordinates(this.latitude, this.longitude)
    : assert(latitude >= -90 && latitude <= 90),
      assert(longitude >= -180 && longitude <= 180);

  static const double _earthRadiusKm = 6371.0;

  /// Great-circle (haversine) distance in kilometres.
  double distanceKmTo(GeoCoordinates other) {
    double rad(double deg) => deg * math.pi / 180.0;
    final dLat = rad(other.latitude - latitude);
    final dLng = rad(other.longitude - longitude);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(latitude)) *
            math.cos(rad(other.latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * _earthRadiusKm * math.asin(math.sqrt(a));
  }

  @override
  bool operator ==(Object other) =>
      other is GeoCoordinates &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoCoordinates($latitude, $longitude)';
}

/// Typical spend per visit (in IDR by default).
class PlacePriceRange {
  final int? minPrice;
  final int? maxPrice;
  final String currencyCode;

  const PlacePriceRange({
    this.minPrice,
    this.maxPrice,
    this.currencyCode = 'IDR',
  });

  bool get isEmpty => minPrice == null && maxPrice == null;

  /// Compact Indonesian label, e.g. `Rp25k–50k`.
  String get label {
    String k(int v) =>
        v % 1000 == 0 ? '${v ~/ 1000}k' : '${(v / 1000).toStringAsFixed(1)}k';
    final min = minPrice;
    final max = maxPrice;
    if (min != null && max != null) return 'Rp${k(min)}–${k(max)}';
    if (min != null) return 'Mulai Rp${k(min)}';
    if (max != null) return 'Hingga Rp${k(max)}';
    return '';
  }

  Map<String, dynamic> toMap() => {
    'minPrice': minPrice,
    'maxPrice': maxPrice,
    'currencyCode': currencyCode,
  };

  static PlacePriceRange? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final range = PlacePriceRange(
      minPrice: (raw['minPrice'] as num?)?.toInt(),
      maxPrice: (raw['maxPrice'] as num?)?.toInt(),
      currencyCode: (raw['currencyCode'] as String?) ?? 'IDR',
    );
    return range.isEmpty ? null : range;
  }

  @override
  bool operator ==(Object other) =>
      other is PlacePriceRange &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      other.currencyCode == currencyCode;

  @override
  int get hashCode => Object.hash(minPrice, maxPrice, currencyCode);

  @override
  String toString() => label;
}

/// Opening hours information.
class PlaceOpeningHours {
  /// Human readable per-day lines, e.g. `Senin: 08.00–23.00`
  /// (mirrors Google's `weekdayDescriptions`).
  final List<String> weekdayDescriptions;

  /// Short status label shown on cards, e.g. `Buka sampai 23.00`.
  ///
  /// NOTE: this is time-dependent. In C1 it is a static mock value; once
  /// real hours exist it should be computed from structured periods.
  final String? statusLabel;

  const PlaceOpeningHours({
    this.weekdayDescriptions = const [],
    this.statusLabel,
  });

  Map<String, dynamic> toMap() => {
    'weekdayDescriptions': weekdayDescriptions,
    'statusLabel': statusLabel,
  };

  static PlaceOpeningHours? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final lines = raw['weekdayDescriptions'];
    return PlaceOpeningHours(
      weekdayDescriptions: lines is Iterable
          ? List.unmodifiable(lines.whereType<String>())
          : const [],
      statusLabel: raw['statusLabel'] as String?,
    );
  }
}
