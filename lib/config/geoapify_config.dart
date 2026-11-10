/// Configuration and constants for Geoapify Places API.
///
/// ═════════════════════════════════════════════════════════════════════════════
/// ⚠️ ARCHITECTURE & SECURITY NOTICE:
/// ═════════════════════════════════════════════════════════════════════════════
/// - Development prototype reads the API key via `--dart-define` / `--dart-define-from-file`.
/// - The local secrets file `.secrets/geoapify.dev.json` is Git-ignored and must never
///   be checked into source control or exposed in logs.
/// - Production release will transition to an authenticated backend proxy
///   to prevent embedding external vendor credentials inside compiled mobile binaries.
/// ═════════════════════════════════════════════════════════════════════════════
class GeoapifyConfig {
  GeoapifyConfig._();

  /// Build-time API key provided via `--dart-define=GEOAPIFY_API_KEY=...`
  /// or `--dart-define-from-file=.secrets/geoapify.dev.json`.
  static const String apiKey = String.fromEnvironment(
    'GEOAPIFY_API_KEY',
    defaultValue: '',
  );

  /// Whether a valid non-empty API key is configured.
  static bool get hasApiKey => apiKey.trim().isNotEmpty;

  /// Safe diagnostic summary of Geoapify configuration (never exposes the key).
  static String get debugConfigStatus =>
      'hasApiKey=$hasApiKey, keyLength=${apiKey.trim().length}';

  /// Geoapify Places v2 base endpoint.
  static const String baseUrl = 'https://api.geoapify.com/v2/places';

  /// Supported initial categories for SpotNugas venue discovery.
  static const List<String> defaultCategories = [
    'catering.cafe',
    'office.coworking',
    'education.library',
  ];

  /// Default development center: Jakarta Selatan (-6.2297, 106.8295).
  static const double defaultLatitude = -6.2297;
  static const double defaultLongitude = 106.8295;

  /// Default search radius in meters (5,000 meters = 5 km).
  static const int defaultRadiusMeters = 5000;

  /// Default result limit per request.
  static const int defaultLimit = 20;

  /// Request timeout for live HTTP calls.
  static const Duration requestTimeout = Duration(seconds: 10);

  /// Attribution notice required by Geoapify and OpenStreetMap licensing.
  static const String attributionText =
      'Powered by Geoapify | © OpenStreetMap contributors';

  /// Tile URL template for raster map tiles in flutter_map.
  /// When a valid Geoapify API key is present, uses Geoapify bright raster tiles:
  /// https://maps.geoapify.com/v1/tile/osm-bright/{z}/{x}/{y}.png?apiKey=...
  /// Otherwise falls back cleanly to standard OpenStreetMap tiles:
  /// https://tile.openstreetmap.org/{z}/{x}/{y}.png
  static String get tileUrlTemplate {
    if (hasApiKey) {
      return 'https://maps.geoapify.com/v1/tile/osm-bright/{z}/{x}/{y}.png?apiKey=$apiKey';
    }
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  /// Converts a Geoapify category taxonomy key to a user-friendly Indonesian display label.
  static String mapCategoryLabel(String? categoryKey) {
    if (categoryKey == null || categoryKey.isEmpty) return 'Tempat Nugas';

    final lower = categoryKey.toLowerCase();
    if (lower.contains('coworking') || lower.contains('office.coworking')) {
      return 'Coworking Space';
    }
    if (lower.contains('library') || lower.contains('education.library')) {
      return 'Perpustakaan';
    }
    if (lower.contains('cafe') || lower.contains('catering.cafe')) {
      return 'Cafe';
    }
    if (lower.contains('catering.restaurant')) {
      return 'Cafe & Resto';
    }
    if (lower.contains('education')) {
      return 'Ruang Belajar';
    }
    return 'Tempat Nugas';
  }
}
