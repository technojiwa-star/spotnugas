import '../models/place_types.dart';

/// Centralized geographic locations for SpotNugas.
///
/// Decouples the Jakarta production/development target from the
/// mock Yogyakarta test dataset.
class AppLocation {
  AppLocation._();

  /// Default production/development target for SpotNugas (Jakarta Selatan).
  ///
  /// Centered around the active student/cafe belt (Kuningan / Senopati / Blok M).
  static const GeoCoordinates defaultJakarta = GeoCoordinates(
    -6.2297,
    106.8295,
  );

  static const String defaultJakartaLabel = 'Jakarta Selatan';

  /// Preset: Bandung
  static const GeoCoordinates bandung = GeoCoordinates(-6.9175, 107.6191);
  static const String bandungLabel = 'Bandung';

  /// Preset: Depok
  static const GeoCoordinates depok = GeoCoordinates(-6.4025, 106.7942);
  static const String depokLabel = 'Depok';

  /// Explicit mock origin for the offline Yogyakarta demo dataset.
  ///
  /// Centered at Jl. Kaliurang km 5, Sleman.
  /// Used for test assertions and offline mock repository seeding only.
  static const GeoCoordinates mockYogyakartaOrigin = GeoCoordinates(
    -7.7545,
    110.3830,
  );

  static const String mockYogyakartaLabel = 'Jl. Kaliurang km 5, Sleman';
}
