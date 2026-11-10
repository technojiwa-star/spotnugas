/// Safe, production-ready configuration for Google Places API (New).
///
/// ═════════════════════════════════════════════════════════════════════════════
/// ⚠️ CRITICAL SECURITY & BILLING ARCHITECTURE NOTICE:
/// ═════════════════════════════════════════════════════════════════════════════
/// 1. SECRET STORAGE:
///    `--dart-define` is NOT a secret storage mechanism for a distributed Flutter APK.
///    Any string passed via `--dart-define` is compiled directly into `libapp.so`
///    and can be extracted via basic reverse engineering (`strings libapp.so`).
///
/// 2. PRODUCTION ARCHITECTURE RECOMMENDATIONS:
///    - RECOMMENDED: Authenticated Backend Proxy (Cloud Functions / Cloud Run).
///      The mobile client sends user's Firebase Auth JWT. The server verifies
///      the user, enforces rate limits, bounds queries, and accesses Google Places
///      API (New) using a secret stored in Google Cloud Secret Manager.
///      Geographic caching can reduce redundant calls for popular student hubs
///      depending on traffic patterns and cache hit ratios.
///    - ALTERNATIVE: Native Places SDK Integration (Android + iOS Places SDK).
///      Authenticates via platform certificates (SHA-1 fingerprint on Android,
///      package name: `com.spotnugas.app`; Bundle ID on iOS: `com.example.spotNugas`).
///
/// 3. GOOGLE MAPS PLATFORM & FIREBASE BILLING NOTICE:
///    Google Maps Platform APIs and Cloud Functions require an active Google Cloud
///    billing account. Activating a billing account on the Firebase project will
///    automatically upgrade the Firebase project from the free Spark plan to the
///    pay-as-you-go Blaze plan. Set budget alerts and quota caps in the Google
///    Cloud Console before enabling any live calls.
/// ═════════════════════════════════════════════════════════════════════════════
class PlacesApiConfig {
  PlacesApiConfig._();

  /// Development-only build-time key. NEVER use with an unrestricted billing-enabled key!
  static const String apiKey = String.fromEnvironment(
    'GOOGLE_PLACES_API_KEY',
    defaultValue: '',
  );

  /// Whether a valid non-empty API key is configured.
  static bool get hasApiKey => apiKey.trim().isNotEmpty;

  /// Google Places API (New) base endpoint.
  static const String baseUrl = 'https://places.googleapis.com/v1';

  // ═══════════════════════════════════════════════════════════════════════════
  // ── Official Google Places API (New) Field Masks & SKU Breakdown ──────────
  // ═══════════════════════════════════════════════════════════════════════════
  // Official Pricing Structure:
  // - Nearby Search Pro:       5,000 free requests/mo, then $32.00 / 1,000 req.
  // - Nearby Search Enterprise:  1,000 free requests/mo, then $35.00 / 1,000 req.
  // - Place Details Pro:       5,000 free requests/mo, then $17.00 / 1,000 req.
  // - Place Details Enterprise: 1,000 free requests/mo, then $20.00 / 1,000 req.
  //
  // Field rules:
  // - Requesting `places.rating`, `places.userRatingCount`, `places.priceLevel`,
  //   or `places.regularOpeningHours` triggers the Enterprise SKU for Nearby Search.
  // - `places.photos` alone triggers Nearby Search Pro, NOT Atmosphere.
  // - Photos on Place Details (`photos`) are Pro fields, NOT Atmosphere.
  // - Wildcard masks ('*') are strictly prohibited in production!
  // ═══════════════════════════════════════════════════════════════════════════

  /// Low-cost Nearby Search Field Mask: triggers ONLY Nearby Search Pro
  /// (5,000 free requests/month, $32/1,000 after free cap).
  ///
  /// Omits `places.rating`, `places.priceLevel`, and `places.regularOpeningHours`
  /// to avoid incurring the more expensive Enterprise tier on discovery lists.
  /// `places.photos` alone remains within Nearby Search Pro.
  static const String nearbySearchProFieldMask =
      'places.id,'
      'places.displayName,'
      'places.formattedAddress,'
      'places.location,'
      'places.primaryType,'
      'places.photos';

  /// Full Nearby Search Field Mask: triggers Nearby Search Enterprise
  /// (1,000 free requests/month, $35/1,000 after free cap).
  ///
  /// Incurs Enterprise SKU because it requests `places.rating`,
  /// `places.userRatingCount`, `places.priceLevel`, and `places.regularOpeningHours`.
  /// Use only when operational indicators are strictly required on initial search cards.
  static const String nearbySearchEnterpriseFieldMask =
      'places.id,'
      'places.displayName,'
      'places.formattedAddress,'
      'places.location,'
      'places.primaryType,'
      'places.rating,'
      'places.userRatingCount,'
      'places.priceLevel,'
      'places.regularOpeningHours,'
      'places.photos';

  /// Text Search Pro Field Mask (5,000 free/mo, $32/1k).
  static const String textSearchProFieldMask = nearbySearchProFieldMask;

  /// Text Search Enterprise Field Mask (1,000 free/mo, $35/1k).
  static const String textSearchEnterpriseFieldMask =
      nearbySearchEnterpriseFieldMask;

  /// Default search masks: low-cost Pro tier is recommended for home discovery.
  static const String nearbySearchFieldMask = nearbySearchProFieldMask;
  static const String textSearchFieldMask = textSearchProFieldMask;

  /// Low-cost Place Details Field Mask: triggers ONLY Place Details Pro
  /// (5,000 free requests/month, $17/1,000 after free cap).
  ///
  /// `photos` on Place Details is a Pro field. Omits ratings, price ranges,
  /// opening hours, and phone/website to stay in the Pro tier.
  static const String placeDetailsProFieldMask =
      'id,'
      'displayName,'
      'formattedAddress,'
      'location,'
      'primaryType,'
      'photos';

  /// Full Place Details Field Mask: triggers Place Details Enterprise
  /// (1,000 free requests/month, $20/1,000 after free cap).
  ///
  /// Includes operational details (`rating`, `priceLevel`, `priceRange`,
  /// `regularOpeningHours`, `websiteUri`, `internationalPhoneNumber`).
  /// Note: SpotNugas provides its own student reviews; Google reviews (`reviews`)
  /// are omitted.
  static const String placeDetailsEnterpriseFieldMask =
      'id,'
      'displayName,'
      'formattedAddress,'
      'location,'
      'primaryType,'
      'rating,'
      'userRatingCount,'
      'priceLevel,'
      'priceRange,'
      'regularOpeningHours,'
      'photos,'
      'websiteUri,'
      'internationalPhoneNumber';

  /// Default detail mask used when viewing place details.
  static const String placeDetailsFieldMask = placeDetailsEnterpriseFieldMask;

  // ── Throttling & Policy Guardrails ────────────────────────────────────────
  /// Debounce duration for interactive text search to prevent rapid keystroke queries.
  static const Duration searchDebounceDuration = Duration(milliseconds: 400);

  /// Minimum text query length before firing Google Places search.
  static const int minSearchQueryLength = 3;

  /// Default search radius in metres (5 km).
  static const double defaultSearchRadiusMeters = 5000.0;

  /// Maximum search radius allowed (15 km).
  static const double maxSearchRadiusMeters = 15000.0;

  /// Cache TTL for in-memory place search responses within a single session.
  ///
  /// Adheres to Google Maps Platform terms (caching beyond 30 days is prohibited;
  /// in-session 15-minute caching complies with permitted performance caching).
  static const Duration inMemoryCacheTtl = Duration(minutes: 15);

  /// Maximum photos retrieved per place in search result lists.
  static const int maxPhotosPerPlace = 2;

  /// Max photo dimensions requested from the API to control bandwidth.
  static const int maxPhotoWidthPx = 800;
  static const int maxPhotoHeightPx = 600;
}
