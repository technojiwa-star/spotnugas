import 'place_types.dart';

/// Provider-independent and stable place identity for SpotNugas.
///
/// Ensures bookmarks (`users/{uid}/saved_places/{placeId}`) and reviews
/// (`places/{placeId}/reviews/{reviewId}`) always reference the SAME
/// canonical SpotNugas place key across provider migrations and data merges.
///
/// Identity is NEVER derived from mutable attributes like place name or address,
/// preventing orphaned bookmarks and duplicate review trees when places are
/// renamed or addresses are formatted differently.
class PlaceIdentity {
  /// The canonical place key used in Firestore paths.
  final String canonicalKey;

  /// The primary provider source for this place.
  final PlaceSource primarySource;

  /// Optional Geoapify place identifier (primary public places provider).
  final String? geoapifyPlaceId;

  /// Optional Google place identifier (secondary / legacy provider).
  final String? googlePlaceId;

  /// Optional SpotNugas curated document ID.
  final String? spotNugasPlaceId;

  /// Known aliases (e.g. previous provider IDs, cross-provider references)
  /// mapping to this same physical venue to prevent duplicate records.
  final List<String> aliases;

  const PlaceIdentity({
    required this.canonicalKey,
    required this.primarySource,
    this.geoapifyPlaceId,
    this.googlePlaceId,
    this.spotNugasPlaceId,
    this.aliases = const [],
  });

  /// Factory for a Geoapify-sourced place.
  factory PlaceIdentity.geoapify(
    String geoapifyId, {
    String? spotNugasPlaceId,
    List<String> aliases = const [],
  }) {
    if (geoapifyId.trim().isEmpty) {
      throw ArgumentError('geoapifyId must not be empty');
    }
    final cleanId = geoapifyId.trim();
    final canonical = spotNugasPlaceId ?? formatGeoapifyKey(cleanId);
    return PlaceIdentity(
      canonicalKey: canonical,
      primarySource: PlaceSource.geoapify,
      geoapifyPlaceId: cleanId,
      spotNugasPlaceId: spotNugasPlaceId,
      aliases: [
        ?spotNugasPlaceId,
        formatGeoapifyKey(cleanId),
        cleanId,
        ...aliases,
      ],
    );
  }

  /// Factory for a Google-sourced place.
  factory PlaceIdentity.google(
    String googleId, {
    String? spotNugasPlaceId,
    List<String> aliases = const [],
  }) {
    if (googleId.trim().isEmpty) {
      throw ArgumentError('googleId must not be empty');
    }
    final cleanId = googleId.trim();
    final canonical = spotNugasPlaceId ?? cleanId;
    return PlaceIdentity(
      canonicalKey: canonical,
      primarySource: PlaceSource.google,
      googlePlaceId: cleanId,
      spotNugasPlaceId: spotNugasPlaceId,
      aliases: [
        ?spotNugasPlaceId,
        formatGoogleKey(cleanId),
        cleanId,
        ...aliases,
      ],
    );
  }

  /// Factory for a manually registered SpotNugas place.
  factory PlaceIdentity.manual(
    String placeId, {
    List<String> aliases = const [],
  }) {
    if (placeId.trim().isEmpty) {
      throw ArgumentError('placeId must not be empty');
    }
    final cleanId = placeId.trim();
    return PlaceIdentity(
      canonicalKey: cleanId,
      primarySource: PlaceSource.manual,
      spotNugasPlaceId: cleanId,
      aliases: [cleanId, ...aliases],
    );
  }

  /// Formats a Geoapify place ID into a namespaced key if not already formatted.
  static String formatGeoapifyKey(String rawId) {
    if (rawId.startsWith('geoapify:')) return rawId;
    return 'geoapify:$rawId';
  }

  /// Formats a Google place ID into a namespaced key if not already formatted.
  static String formatGoogleKey(String rawId) {
    if (rawId.startsWith('google:')) return rawId;
    return 'google:$rawId';
  }

  /// Checks if two place identities refer to the same venue (deduplication check).
  bool matches(PlaceIdentity other) {
    if (canonicalKey == other.canonicalKey) return true;
    if (geoapifyPlaceId != null &&
        other.geoapifyPlaceId != null &&
        geoapifyPlaceId == other.geoapifyPlaceId) {
      return true;
    }
    if (googlePlaceId != null &&
        other.googlePlaceId != null &&
        googlePlaceId == other.googlePlaceId) {
      return true;
    }
    if (spotNugasPlaceId != null &&
        other.spotNugasPlaceId != null &&
        spotNugasPlaceId == other.spotNugasPlaceId) {
      return true;
    }
    for (final alias in aliases) {
      if (other.aliases.contains(alias) || alias == other.canonicalKey) {
        return true;
      }
    }
    for (final otherAlias in other.aliases) {
      if (aliases.contains(otherAlias) || otherAlias == canonicalKey) {
        return true;
      }
    }
    return false;
  }

  /// Validates that a canonical key is Firestore-compatible (no forward slashes, non-empty).
  static bool isValidKey(String key) {
    if (key.trim().isEmpty) return false;
    if (key.contains('/')) return false;
    if (key.contains('..')) return false;
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaceIdentity &&
          runtimeType == other.runtimeType &&
          canonicalKey == other.canonicalKey;

  @override
  int get hashCode => canonicalKey.hashCode;

  @override
  String toString() => 'PlaceIdentity($canonicalKey, ${primarySource.value})';
}
