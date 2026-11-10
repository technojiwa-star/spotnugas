import '../config/geoapify_config.dart';
import '../utils/study_score_calculator.dart';
import 'geoapify_place_data.dart';
import 'google_place_data.dart';
import 'place_identity.dart';
import 'place_types.dart';
import 'spotnugas_place_data.dart';

export 'geoapify_place_data.dart';
export 'place_identity.dart';
export 'place_types.dart';

/// A user review shown on the place detail screen.
///
/// NOTE: mock-only in C1. Reviews will move to their own collection and
/// repository in a later phase; they are not part of the place document.
class PlaceReview {
  final String id;
  final String userName;
  final String userAvatar;
  final double rating;
  final String date;
  final String comment;
  final String visitPurpose;

  const PlaceReview({
    required this.id,
    required this.userName,
    required this.userAvatar,
    required this.rating,
    required this.date,
    required this.comment,
    required this.visitPurpose,
  });
}

/// Unified SpotNugas place domain model consumed by the UI.
///
/// A `Place` is a *merged view* built by a repository from up to two sources
/// (see [Place.fromSources]):
/// - [GooglePlaceData]  — public third-party data (google places only)
/// - [SpotNugasPlaceData] — SpotNugas-owned productivity data (`places/{id}`)
///
/// UI code should depend on this class only, never on the source DTOs.
class Place {
  // ── Identity ───────────────────────────────────────────────────────────
  /// Canonical SpotNugas id (Firestore doc id).
  /// For Geoapify places without a doc, format is `geoapify:{id}`.
  /// For Google places without a doc, format is `google:{id}` or `{id}`.
  final String id;
  final PlaceSource source;
  final String? geoapifyPlaceId;
  final String? googlePlaceId;
  final List<String> aliases;

  // ── Public info (Geoapify/Google for third-party, SpotNugas for manual) ─
  final String name;
  final String category;
  final String? description;
  final String? address;
  final double latitude;
  final double longitude;
  final PlacePriceLevel? priceLevel;
  final PlacePriceRange? priceRange;
  final double? googleRating;
  final int? googleRatingCount;
  final PlaceOpeningHours? openingHours;
  final bool? isOpenNow;
  final List<String> photoUrls;

  // ── SpotNugas productivity data ────────────────────────────────────────
  final double? studyScore;
  final double? wifiScore;
  final double? outletScore;
  final double? comfortScore;
  final double? noiseScore;
  final double? priceValueScore;
  final List<PlaceFacility> facilities;
  final List<PlaceAtmosphere> atmosphere;
  final List<PlaceSuitability> suitableFor;
  final List<String> tags;
  final double? communityRating;
  final int? communityRatingCount;

  // ── Moderation / partner / lifecycle ───────────────────────────────────
  final PlaceVerificationStatus? verificationStatus;
  final bool isVerifiedPartner;
  final String? verifiedPartnerUid;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ── Contextual / presentation (never persisted) ────────────────────────
  /// Distance from the current search origin, computed by the repository.
  final double? distanceKm;

  /// Mock reviews (see [PlaceReview]).
  final List<PlaceReview> reviews;

  /// SpotAI mock annotations, e.g. `90% cocok`. Presentation-only.
  final String compatibilityScore;
  final String whyRecommended;

  /// Session-only bookmark flag kept for the existing mock UI.
  bool isSaved;

  Place({
    required this.id,
    required this.source,
    this.geoapifyPlaceId,
    this.googlePlaceId,
    this.aliases = const [],
    required this.name,
    required this.category,
    this.description,
    this.address,
    required this.latitude,
    required this.longitude,
    this.priceLevel,
    this.priceRange,
    this.googleRating,
    this.googleRatingCount,
    this.openingHours,
    this.isOpenNow,
    this.photoUrls = const [],
    this.studyScore,
    this.wifiScore,
    this.outletScore,
    this.comfortScore,
    this.noiseScore,
    this.priceValueScore,
    this.facilities = const [],
    this.atmosphere = const [],
    this.suitableFor = const [],
    this.tags = const [],
    this.communityRating,
    this.communityRatingCount,
    this.verificationStatus,
    this.isVerifiedPartner = false,
    this.verifiedPartnerUid,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.distanceKm,
    this.reviews = const [],
    this.compatibilityScore = '',
    this.whyRecommended = '',
    this.isSaved = false,
  }) : assert(
         source != PlaceSource.google ||
             (googlePlaceId != null && googlePlaceId != ''),
         'Google-sourced places require a googlePlaceId',
       ),
       assert(
         source != PlaceSource.geoapify ||
             (geoapifyPlaceId != null && geoapifyPlaceId != ''),
         'Geoapify-sourced places require a geoapifyPlaceId',
       );

  static const String defaultCategory = 'Tempat Nugas';

  /// Returns a copy of this place with an updated [distanceKm] relative to a query origin.
  Place copyWithDistance(double? newDistanceKm) {
    return Place(
      id: id,
      source: source,
      geoapifyPlaceId: geoapifyPlaceId,
      googlePlaceId: googlePlaceId,
      aliases: aliases,
      name: name,
      category: category,
      description: description,
      address: address,
      latitude: latitude,
      longitude: longitude,
      priceLevel: priceLevel,
      priceRange: priceRange,
      googleRating: googleRating,
      googleRatingCount: googleRatingCount,
      openingHours: openingHours,
      isOpenNow: isOpenNow,
      photoUrls: photoUrls,
      studyScore: studyScore,
      wifiScore: wifiScore,
      outletScore: outletScore,
      comfortScore: comfortScore,
      noiseScore: noiseScore,
      priceValueScore: priceValueScore,
      facilities: facilities,
      atmosphere: atmosphere,
      suitableFor: suitableFor,
      tags: tags,
      communityRating: communityRating,
      communityRatingCount: communityRatingCount,
      verificationStatus: verificationStatus,
      isVerifiedPartner: isVerifiedPartner,
      verifiedPartnerUid: verifiedPartnerUid,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      distanceKm: newDistanceKm,
      reviews: reviews,
      compatibilityScore: compatibilityScore,
      whyRecommended: whyRecommended,
      isSaved: isSaved,
    );
  }

  /// Merges source data into a single domain [Place].
  ///
  /// Precedence rules:
  /// - **google places**: identity facts (name, address, location, Google
  ///   rating, hours, photos, price level) come from [google]. A SpotNugas
  ///   overlay is optional — a Google place is valid without one.
  /// - **manual places**: everything comes from [spotNugas]; [google] must be
  ///   null.
  /// - **editorial fields** (category, description, price range) prefer
  ///   SpotNugas when present, else Google.
  /// Merges source data into a single domain [Place].
  ///
  /// Precedence rules:
  /// - **geoapify places**: primary public places provider. Identity facts come
  ///   from [geoapify]. A SpotNugas overlay is optional.
  /// - **google places**: secondary / legacy provider. Identity facts come
  ///   from [google]. A SpotNugas overlay is optional.
  /// - **manual places**: everything comes from [spotNugas]; third-party
  ///   data must be null.
  /// - **editorial fields** (category, description, price range) prefer
  ///   SpotNugas when present, else the third-party provider.
  factory Place.fromSources({
    GeoapifyPlaceData? geoapify,
    GooglePlaceData? google,
    SpotNugasPlaceData? spotNugas,
    double? distanceKm,
    List<PlaceReview> reviews = const [],
    String compatibilityScore = '',
    String whyRecommended = '',
    bool isSaved = false,
  }) {
    final sn = spotNugas;

    if (sn != null && sn.isManual) {
      if (google != null || geoapify != null) {
        throw ArgumentError(
          'Manual place "${sn.placeId}" must not be merged with third-party data',
        );
      }
      final location = sn.location!;
      return Place(
        id: sn.placeId,
        source: PlaceSource.manual,
        name: sn.name!,
        category: sn.category ?? defaultCategory,
        description: sn.description,
        address: sn.address,
        latitude: location.latitude,
        longitude: location.longitude,
        priceLevel: sn.priceLevel,
        priceRange: sn.priceRange,
        openingHours: sn.openingHours,
        photoUrls: sn.photoUrls,
        studyScore: sn.studyScore,
        wifiScore: sn.wifiScore,
        outletScore: sn.outletScore,
        comfortScore: sn.comfortScore,
        noiseScore: sn.noiseScore,
        priceValueScore: sn.priceValueScore,
        facilities: sn.facilities,
        atmosphere: sn.atmosphere,
        suitableFor: sn.suitableFor,
        tags: sn.tags,
        communityRating: sn.communityRating,
        communityRatingCount: sn.communityRatingCount,
        verificationStatus: sn.verificationStatus,
        isVerifiedPartner: sn.isVerifiedPartner,
        verifiedPartnerUid: sn.verifiedPartnerUid,
        isActive: sn.isActive,
        createdAt: sn.createdAt,
        updatedAt: sn.updatedAt,
        distanceKm: distanceKm,
        reviews: reviews,
        compatibilityScore: compatibilityScore,
        whyRecommended: whyRecommended,
        isSaved: isSaved,
        aliases: sn.aliases,
      );
    }

    if (geoapify != null) {
      if (sn != null &&
          sn.geoapifyPlaceId != null &&
          sn.geoapifyPlaceId != geoapify.geoapifyPlaceId) {
        throw ArgumentError(
          'SpotNugas overlay "${sn.placeId}" references '
          '${sn.geoapifyPlaceId}, not ${geoapify.geoapifyPlaceId}',
        );
      }
      final id =
          sn?.placeId ??
          PlaceIdentity.formatGeoapifyKey(geoapify.geoapifyPlaceId);
      return Place(
        id: id,
        source: PlaceSource.geoapify,
        geoapifyPlaceId: geoapify.geoapifyPlaceId,
        name: geoapify.name,
        category:
            sn?.category ??
            (geoapify.primaryCategory != null
                ? GeoapifyConfig.mapCategoryLabel(geoapify.primaryCategory)
                : defaultCategory),
        description: sn?.description,
        address: geoapify.formattedAddress,
        latitude: geoapify.location.latitude,
        longitude: geoapify.location.longitude,
        priceLevel: geoapify.priceLevel,
        priceRange: sn?.priceRange ?? geoapify.priceRange,
        openingHours: geoapify.openingHours,
        isOpenNow: geoapify.isOpenNow,
        photoUrls: geoapify.photoUrls,
        studyScore: sn?.studyScore,
        wifiScore: sn?.wifiScore,
        outletScore: sn?.outletScore,
        comfortScore: sn?.comfortScore,
        noiseScore: sn?.noiseScore,
        priceValueScore: sn?.priceValueScore,
        facilities: sn?.facilities ?? const [],
        atmosphere: sn?.atmosphere ?? const [],
        suitableFor: sn?.suitableFor ?? const [],
        tags: sn?.tags ?? const [],
        communityRating: sn?.communityRating,
        communityRatingCount: sn?.communityRatingCount,
        isVerifiedPartner: sn?.isVerifiedPartner ?? false,
        verifiedPartnerUid: sn?.verifiedPartnerUid,
        isActive: sn?.isActive ?? true,
        createdAt: sn?.createdAt,
        updatedAt: sn?.updatedAt,
        distanceKm: distanceKm,
        reviews: reviews,
        compatibilityScore: compatibilityScore,
        whyRecommended: whyRecommended,
        isSaved: isSaved,
        aliases: sn?.aliases ?? [geoapify.geoapifyPlaceId],
      );
    }

    if (google == null) {
      throw ArgumentError(
        'A third-party place requires GeoapifyPlaceData or GooglePlaceData'
        '${sn != null ? ' (overlay "${sn.placeId}")' : ''}',
      );
    }
    if (sn != null && sn.googlePlaceId != google.googlePlaceId) {
      throw ArgumentError(
        'SpotNugas overlay "${sn.placeId}" references '
        '${sn.googlePlaceId}, not ${google.googlePlaceId}',
      );
    }

    return Place(
      id: sn?.placeId ?? google.googlePlaceId,
      source: PlaceSource.google,
      googlePlaceId: google.googlePlaceId,
      name: google.name,
      category: sn?.category ?? google.primaryType ?? defaultCategory,
      description: sn?.description,
      address: google.formattedAddress,
      latitude: google.location.latitude,
      longitude: google.location.longitude,
      priceLevel: google.priceLevel,
      priceRange: sn?.priceRange ?? google.priceRange,
      googleRating: google.rating,
      googleRatingCount: google.userRatingCount,
      openingHours: google.openingHours,
      isOpenNow: google.isOpenNow,
      photoUrls: google.photoUrls,
      studyScore: sn?.studyScore,
      wifiScore: sn?.wifiScore,
      outletScore: sn?.outletScore,
      comfortScore: sn?.comfortScore,
      noiseScore: sn?.noiseScore,
      priceValueScore: sn?.priceValueScore,
      facilities: sn?.facilities ?? const [],
      atmosphere: sn?.atmosphere ?? const [],
      suitableFor: sn?.suitableFor ?? const [],
      tags: sn?.tags ?? const [],
      communityRating: sn?.communityRating,
      communityRatingCount: sn?.communityRatingCount,
      isVerifiedPartner: sn?.isVerifiedPartner ?? false,
      verifiedPartnerUid: sn?.verifiedPartnerUid,
      isActive: sn?.isActive ?? true,
      createdAt: sn?.createdAt,
      updatedAt: sn?.updatedAt,
      distanceKm: distanceKm,
      reviews: reviews,
      compatibilityScore: compatibilityScore,
      whyRecommended: whyRecommended,
      isSaved: isSaved,
      aliases: sn?.aliases ?? [google.googlePlaceId],
    );
  }

  // ── Derived domain helpers ─────────────────────────────────────────────

  bool get isGeoapify => source == PlaceSource.geoapify;
  bool get isGoogleSourced => source == PlaceSource.google;
  bool get isManual => source == PlaceSource.manual;

  /// Canonical key for referencing in Firestore bookmarks and reviews.
  String get canonicalKey => id;

  /// Structured place identity with deduplication and alias support.
  PlaceIdentity get identity => PlaceIdentity(
    canonicalKey: id,
    primarySource: source,
    geoapifyPlaceId: geoapifyPlaceId,
    googlePlaceId: googlePlaceId,
    spotNugasPlaceId: isManual ? id : (hasSpotNugasData ? id : null),
    aliases: aliases,
  );

  GeoCoordinates get coordinates => GeoCoordinates(latitude, longitude);

  /// Visibility depends ONLY on [isActive]. Partner status and verification
  /// never hide a place.
  bool get isVisible => isActive;

  /// Whether SpotNugas has any productivity data for this place.
  bool get hasSpotNugasData =>
      studyScore != null ||
      wifiScore != null ||
      outletScore != null ||
      comfortScore != null ||
      noiseScore != null ||
      priceValueScore != null;

  /// Google rating when available, otherwise the SpotNugas community rating.
  double? get displayRating => googleRating ?? communityRating;

  int? get displayRatingCount =>
      googleRating != null ? googleRatingCount : communityRatingCount;

  /// Stored study score, or a deterministic fallback from sub-scores.
  double? get resolvedStudyScore =>
      studyScore ??
      const StudyScoreCalculator().compute(
        wifiScore: wifiScore,
        outletScore: outletScore,
        comfortScore: comfortScore,
        noiseScore: noiseScore,
        priceValueScore: priceValueScore,
        rating: displayRating,
      );

  String get studyScoreLabel =>
      StudyScoreCalculator.labelFor(resolvedStudyScore);

  // ── Presentation helpers (keep formatting out of widgets) ──────────────

  String? get primaryPhotoUrl => photoUrls.isNotEmpty ? photoUrls.first : null;

  /// e.g. `850 m`, `1.2 km`, or `-` when unknown.
  String get distanceLabel {
    final km = distanceKm;
    if (km == null) return '-';
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  /// e.g. `Rp25k–50k`, falling back to the price level label.
  String get priceLabel {
    final range = priceRange;
    if (range != null && !range.isEmpty) return range.label;
    return priceLevel?.label ?? '-';
  }

  String get openStatusLabel {
    final label = openingHours?.statusLabel;
    if (label != null && label.isNotEmpty) return label;
    return switch (isOpenNow) {
      true => 'Buka sekarang',
      false => 'Tutup',
      null => 'Jam belum tersedia',
    };
  }

  // ── Compatibility getters for existing UI ─────────────────────────────
  /// Compatibility alias for [primaryPhotoUrl].
  String get image => primaryPhotoUrl ?? '';

  /// Compatibility alias for [distanceLabel].
  String get distance => distanceLabel;

  /// Compatibility alias for [openStatusLabel].
  String get openStatus => openStatusLabel;

  /// Compatibility alias for [isOpenNow].
  bool get isOpen => isOpenNow ?? true;

  /// Compatibility alias for [resolvedStudyScore].
  double get skorNugas => resolvedStudyScore ?? 0.0;

  /// Compatibility alias for [studyScoreLabel].
  String get skorDescription => studyScoreLabel;

  /// Compatibility alias for [displayRating].
  double get rating => displayRating ?? 0.0;

  /// Compatibility alias for [displayRatingCount].
  int get reviewCount => displayRatingCount ?? 0;

  /// Compatibility aliases for SpotNugas productivity sub-scores (0-5).
  double get wifiScoreVal => wifiScore ?? 0.0;
  double get colokanScore => outletScore ?? 0.0;
  double get kenyamananScore => comfortScore ?? 0.0;
  double get ketenanganScore => noiseScore ?? 0.0;
  double get hargaScore => priceValueScore ?? 0.0;

  /// Compatibility aliases for coordinates.
  double get lat => latitude;
  double get lng => longitude;

  /// Helper to get list of facility labels as Strings.
  List<String> get facilityLabels => facilities.map((f) => f.label).toList();

  @override
  String toString() => 'Place($id, ${source.value}, $name)';
}
