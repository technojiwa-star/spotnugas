import 'package:cloud_firestore/cloud_firestore.dart';

import 'place_types.dart';

/// SpotNugas-owned place data — the shape of a future Firestore document at
/// `places/{placeId}`.
///
/// The document has two shapes depending on [source]:
///
/// **`source: "google"`** — an *overlay* on a Google place. It stores only the
/// Google reference plus SpotNugas productivity data. Google public content
/// (name, address, rating, hours, photos) is NOT stored here; it is fetched
/// live via `GooglePlacesDataSource` and merged in `Place.fromSources`.
///
/// **`source: "manual"`** — a place that does not exist on Google. SpotNugas
/// owns everything, so public info (name, address, location, photos, hours,
/// price level) and a [verificationStatus] are stored here too.
///
/// Partner fields ([isVerifiedPartner], [verifiedPartnerUid]) are optional for
/// both sources and never affect visibility — only [isActive] does.
class SpotNugasPlaceData {
  /// Firestore document id.
  final String placeId;
  final PlaceSource source;

  /// Required for `geoapify`, null for manual places.
  final String? geoapifyPlaceId;

  /// Required for `google`, always null for `manual`.
  final String? googlePlaceId;

  /// Known aliases for cross-provider mapping and deduplication.
  final List<String> aliases;

  // ── Public info: stored ONLY for manual places ─────────────────────────
  final String? name;
  final String? address;
  final GeoCoordinates? location;
  final List<String> photoUrls;
  final PlacePriceLevel? priceLevel;
  final PlaceOpeningHours? openingHours;

  /// Moderation status. Non-null for manual places, null for google places.
  final PlaceVerificationStatus? verificationStatus;

  // ── Editorial overrides: allowed for any source ────────────────────────
  /// SpotNugas category label (falls back to Google's primary type).
  final String? category;
  final String? description;

  /// Typical student spend per visit (falls back to Google's price range).
  final PlacePriceRange? priceRange;

  // ── SpotNugas productivity data ────────────────────────────────────────
  /// Overall 0–10 study score (curated / server-computed).
  final double? studyScore;

  /// Sub-scores on a 0–5 scale.
  final double? wifiScore;
  final double? outletScore;
  final double? comfortScore;

  /// Noise *suitability*: higher = quieter / better for focus.
  final double? noiseScore;
  final double? priceValueScore;

  final List<PlaceFacility> facilities;
  final List<PlaceAtmosphere> atmosphere;
  final List<PlaceSuitability> suitableFor;

  /// Curated highlight labels shown on cards and used by quick filters.
  final List<String> tags;

  /// Aggregate of SpotNugas user reviews (maintained server-side later).
  /// The only rating available for manual places.
  final double? communityRating;
  final int? communityRatingCount;

  // ── Partner / lifecycle ────────────────────────────────────────────────
  final bool isVerifiedPartner;
  final String? verifiedPartnerUid;
  final bool isActive;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SpotNugasPlaceData._({
    required this.placeId,
    required this.source,
    this.geoapifyPlaceId,
    this.googlePlaceId,
    this.aliases = const [],
    this.name,
    this.address,
    this.location,
    this.photoUrls = const [],
    this.priceLevel,
    this.openingHours,
    this.verificationStatus,
    this.category,
    this.description,
    this.priceRange,
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
    this.isVerifiedPartner = false,
    this.verifiedPartnerUid,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Overlay document for a Google-sourced place.
  factory SpotNugasPlaceData.google({
    required String placeId,
    required String googlePlaceId,
    String? category,
    String? description,
    PlacePriceRange? priceRange,
    double? studyScore,
    double? wifiScore,
    double? outletScore,
    double? comfortScore,
    double? noiseScore,
    double? priceValueScore,
    List<PlaceFacility> facilities = const [],
    List<PlaceAtmosphere> atmosphere = const [],
    List<PlaceSuitability> suitableFor = const [],
    List<String> tags = const [],
    double? communityRating,
    int? communityRatingCount,
    bool isVerifiedPartner = false,
    String? verifiedPartnerUid,
    bool isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    if (googlePlaceId.trim().isEmpty) {
      throw ArgumentError.value(
        googlePlaceId,
        'googlePlaceId',
        'Google-sourced places require a googlePlaceId',
      );
    }
    return SpotNugasPlaceData._(
      placeId: placeId,
      source: PlaceSource.google,
      googlePlaceId: googlePlaceId,
      category: category,
      description: description,
      priceRange: priceRange,
      studyScore: studyScore,
      wifiScore: wifiScore,
      outletScore: outletScore,
      comfortScore: comfortScore,
      noiseScore: noiseScore,
      priceValueScore: priceValueScore,
      facilities: List.unmodifiable(facilities),
      atmosphere: List.unmodifiable(atmosphere),
      suitableFor: List.unmodifiable(suitableFor),
      tags: List.unmodifiable(tags),
      communityRating: communityRating,
      communityRatingCount: communityRatingCount,
      isVerifiedPartner: isVerifiedPartner,
      verifiedPartnerUid: verifiedPartnerUid,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Fully SpotNugas-owned document for a place that is not on Google.
  factory SpotNugasPlaceData.manual({
    required String placeId,
    required String name,
    required GeoCoordinates location,
    String? address,
    List<String> photoUrls = const [],
    PlacePriceLevel? priceLevel,
    PlaceOpeningHours? openingHours,
    PlaceVerificationStatus verificationStatus =
        PlaceVerificationStatus.unverified,
    String? category,
    String? description,
    PlacePriceRange? priceRange,
    double? studyScore,
    double? wifiScore,
    double? outletScore,
    double? comfortScore,
    double? noiseScore,
    double? priceValueScore,
    List<PlaceFacility> facilities = const [],
    List<PlaceAtmosphere> atmosphere = const [],
    List<PlaceSuitability> suitableFor = const [],
    List<String> tags = const [],
    double? communityRating,
    int? communityRatingCount,
    bool isVerifiedPartner = false,
    String? verifiedPartnerUid,
    bool isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Manual places require a name');
    }
    return SpotNugasPlaceData._(
      placeId: placeId,
      source: PlaceSource.manual,
      name: name,
      address: address,
      location: location,
      photoUrls: List.unmodifiable(photoUrls),
      priceLevel: priceLevel,
      openingHours: openingHours,
      verificationStatus: verificationStatus,
      category: category,
      description: description,
      priceRange: priceRange,
      studyScore: studyScore,
      wifiScore: wifiScore,
      outletScore: outletScore,
      comfortScore: comfortScore,
      noiseScore: noiseScore,
      priceValueScore: priceValueScore,
      facilities: List.unmodifiable(facilities),
      atmosphere: List.unmodifiable(atmosphere),
      suitableFor: List.unmodifiable(suitableFor),
      tags: List.unmodifiable(tags),
      communityRating: communityRating,
      communityRatingCount: communityRatingCount,
      isVerifiedPartner: isVerifiedPartner,
      verifiedPartnerUid: verifiedPartnerUid,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Overlay document for a Geoapify-sourced place.
  factory SpotNugasPlaceData.geoapify({
    required String placeId,
    required String geoapifyPlaceId,
    List<String> aliases = const [],
    String? category,
    String? description,
    PlacePriceRange? priceRange,
    double? studyScore,
    double? wifiScore,
    double? outletScore,
    double? comfortScore,
    double? noiseScore,
    double? priceValueScore,
    List<PlaceFacility> facilities = const [],
    List<PlaceAtmosphere> atmosphere = const [],
    List<PlaceSuitability> suitableFor = const [],
    List<String> tags = const [],
    double? communityRating,
    int? communityRatingCount,
    bool isVerifiedPartner = false,
    String? verifiedPartnerUid,
    bool isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    if (geoapifyPlaceId.trim().isEmpty) {
      throw ArgumentError.value(
        geoapifyPlaceId,
        'geoapifyPlaceId',
        'Geoapify-sourced places require a geoapifyPlaceId',
      );
    }
    return SpotNugasPlaceData._(
      placeId: placeId,
      source: PlaceSource.geoapify,
      geoapifyPlaceId: geoapifyPlaceId,
      aliases: List.unmodifiable(aliases),
      category: category,
      description: description,
      priceRange: priceRange,
      studyScore: studyScore,
      wifiScore: wifiScore,
      outletScore: outletScore,
      comfortScore: comfortScore,
      noiseScore: noiseScore,
      priceValueScore: priceValueScore,
      facilities: List.unmodifiable(facilities),
      atmosphere: List.unmodifiable(atmosphere),
      suitableFor: List.unmodifiable(suitableFor),
      tags: List.unmodifiable(tags),
      communityRating: communityRating,
      communityRatingCount: communityRatingCount,
      isVerifiedPartner: isVerifiedPartner,
      verifiedPartnerUid: verifiedPartnerUid,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  bool get isGeoapify => source == PlaceSource.geoapify;
  bool get isGoogle => source == PlaceSource.google;
  bool get isManual => source == PlaceSource.manual;

  /// Parses a Firestore document map.
  ///
  /// Throws [FormatException] when the document violates the per-source
  /// contract (geoapify without `geoapifyPlaceId`, google without `googlePlaceId`,
  /// manual without name/location).
  factory SpotNugasPlaceData.fromMap(Map<String, dynamic> map, String placeId) {
    final geoapifyPlaceId = _string(map['geoapifyPlaceId']);
    final googlePlaceId = _string(map['googlePlaceId']);
    final aliases = map['aliases'] is Iterable
        ? (map['aliases'] as Iterable).whereType<String>().toList()
        : const <String>[];
    final source =
        PlaceSource.tryParse(map['source']) ??
        (geoapifyPlaceId != null
            ? PlaceSource.geoapify
            : (googlePlaceId != null
                  ? PlaceSource.google
                  : PlaceSource.manual));

    final facilities = parseEnumList(map['facilities'], PlaceFacility.tryParse);
    final atmosphere = parseEnumList(
      map['atmosphere'],
      PlaceAtmosphere.tryParse,
    );
    final suitableFor = parseEnumList(
      map['suitableFor'],
      PlaceSuitability.tryParse,
    );
    final tags = map['tags'] is Iterable
        ? (map['tags'] as Iterable).whereType<String>().toList()
        : const <String>[];

    final createdAt = _date(map['createdAt']);
    final updatedAt = _date(map['updatedAt']);

    switch (source) {
      case PlaceSource.geoapify:
        if (geoapifyPlaceId == null) {
          throw FormatException(
            'places/$placeId: source "geoapify" requires geoapifyPlaceId',
          );
        }
        return SpotNugasPlaceData.geoapify(
          placeId: placeId,
          geoapifyPlaceId: geoapifyPlaceId,
          aliases: aliases,
          category: _string(map['category']),
          description: _string(map['description']),
          priceRange: PlacePriceRange.fromMap(map['priceRange']),
          studyScore: _double(map['studyScore']),
          wifiScore: _double(map['wifiScore']),
          outletScore: _double(map['outletScore']),
          comfortScore: _double(map['comfortScore']),
          noiseScore: _double(map['noiseScore']),
          priceValueScore: _double(map['priceValueScore']),
          facilities: facilities,
          atmosphere: atmosphere,
          suitableFor: suitableFor,
          tags: tags,
          communityRating: _double(map['communityRating']),
          communityRatingCount: (map['communityRatingCount'] as num?)?.toInt(),
          isVerifiedPartner: (map['isVerifiedPartner'] as bool?) ?? false,
          verifiedPartnerUid: _string(map['verifiedPartnerUid']),
          isActive: (map['isActive'] as bool?) ?? true,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );
      case PlaceSource.google:
        if (googlePlaceId == null) {
          throw FormatException(
            'places/$placeId: source "google" requires googlePlaceId',
          );
        }
        return SpotNugasPlaceData.google(
          placeId: placeId,
          googlePlaceId: googlePlaceId,
          category: _string(map['category']),
          description: _string(map['description']),
          priceRange: PlacePriceRange.fromMap(map['priceRange']),
          studyScore: _double(map['studyScore']),
          wifiScore: _double(map['wifiScore']),
          outletScore: _double(map['outletScore']),
          comfortScore: _double(map['comfortScore']),
          noiseScore: _double(map['noiseScore']),
          priceValueScore: _double(map['priceValueScore']),
          facilities: facilities,
          atmosphere: atmosphere,
          suitableFor: suitableFor,
          tags: tags,
          communityRating: _double(map['communityRating']),
          communityRatingCount: (map['communityRatingCount'] as num?)?.toInt(),
          isVerifiedPartner: (map['isVerifiedPartner'] as bool?) ?? false,
          verifiedPartnerUid: _string(map['verifiedPartnerUid']),
          isActive: (map['isActive'] as bool?) ?? true,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );
      case PlaceSource.manual:
        final name = _string(map['name']);
        final lat = _double(map['latitude']);
        final lng = _double(map['longitude']);
        if (name == null || lat == null || lng == null) {
          throw FormatException(
            'places/$placeId: source "manual" requires name, latitude and '
            'longitude',
          );
        }
        return SpotNugasPlaceData.manual(
          placeId: placeId,
          name: name,
          location: GeoCoordinates(lat, lng),
          address: _string(map['address']),
          photoUrls: map['photoUrls'] is Iterable
              ? (map['photoUrls'] as Iterable).whereType<String>().toList()
              : const [],
          priceLevel: PlacePriceLevel.tryParse(map['priceLevel']),
          openingHours: PlaceOpeningHours.fromMap(map['openingHours']),
          verificationStatus:
              PlaceVerificationStatus.tryParse(map['verificationStatus']) ??
              PlaceVerificationStatus.unverified,
          category: _string(map['category']),
          description: _string(map['description']),
          priceRange: PlacePriceRange.fromMap(map['priceRange']),
          studyScore: _double(map['studyScore']),
          wifiScore: _double(map['wifiScore']),
          outletScore: _double(map['outletScore']),
          comfortScore: _double(map['comfortScore']),
          noiseScore: _double(map['noiseScore']),
          priceValueScore: _double(map['priceValueScore']),
          facilities: facilities,
          atmosphere: atmosphere,
          suitableFor: suitableFor,
          tags: tags,
          communityRating: _double(map['communityRating']),
          communityRatingCount: (map['communityRatingCount'] as num?)?.toInt(),
          isVerifiedPartner: (map['isVerifiedPartner'] as bool?) ?? false,
          verifiedPartnerUid: _string(map['verifiedPartnerUid']),
          isActive: (map['isActive'] as bool?) ?? true,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );
    }
  }

  factory SpotNugasPlaceData.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return SpotNugasPlaceData.fromMap(doc.data() ?? {}, doc.id);
  }

  /// Serializes to the Firestore document shape.
  ///
  /// For `google` documents, public Google content is intentionally omitted.
  /// Not used for writes in C1 — prepared for a later phase.
  Map<String, dynamic> toMap() {
    return {
      'source': source.value,
      if (isGeoapify) 'geoapifyPlaceId': geoapifyPlaceId,
      if (isGoogle) 'googlePlaceId': googlePlaceId,
      if (aliases.isNotEmpty) 'aliases': aliases,
      if (isManual) ...{
        'name': name,
        'address': address,
        'latitude': location?.latitude,
        'longitude': location?.longitude,
        'photoUrls': photoUrls,
        'priceLevel': priceLevel?.value,
        'openingHours': openingHours?.toMap(),
        'verificationStatus': verificationStatus?.value,
      },
      'category': category,
      'description': description,
      'priceRange': priceRange?.toMap(),
      'studyScore': studyScore,
      'wifiScore': wifiScore,
      'outletScore': outletScore,
      'comfortScore': comfortScore,
      'noiseScore': noiseScore,
      'priceValueScore': priceValueScore,
      'facilities': facilities.map((e) => e.value).toList(),
      'atmosphere': atmosphere.map((e) => e.value).toList(),
      'suitableFor': suitableFor.map((e) => e.value).toList(),
      'tags': tags,
      'communityRating': communityRating,
      'communityRatingCount': communityRatingCount,
      'isVerifiedPartner': isVerifiedPartner,
      'verifiedPartnerUid': verifiedPartnerUid,
      'isActive': isActive,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static String? _string(Object? v) =>
      (v is String && v.trim().isNotEmpty) ? v : null;

  static double? _double(Object? v) => v is num ? v.toDouble() : null;

  static DateTime? _date(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }
}
