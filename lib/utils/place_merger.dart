import '../models/google_place_data.dart';
import '../models/place.dart';
import '../models/spotnugas_place_data.dart';

/// Merges public third-party place data (Geoapify / Google) with SpotNugas Firestore productivity data.
///
/// Ensures:
/// 1. Public Geoapify/Google places appear EVEN WITHOUT a SpotNugas partner or document.
/// 2. Places with a SpotNugas overlay are enriched with study scores and facilities.
/// 3. Manual SpotNugas places (which do not exist on third-party providers) are preserved.
/// 4. Deduplicates duplicate third-party Place IDs.
class PlaceMerger {
  PlaceMerger._();

  /// Assembles a unified [List<Place>] from separate Geoapify and SpotNugas sources.
  static List<Place> mergeGeoapify({
    required List<GeoapifyPlaceData> geoapifyPlaces,
    List<SpotNugasPlaceData> spotNugasPlaces = const [],
    GeoCoordinates? origin,
  }) {
    final overlaysByGeoapifyId = <String, SpotNugasPlaceData>{};
    final manualPlaces = <SpotNugasPlaceData>[];

    for (final sn in spotNugasPlaces) {
      if (!sn.isActive) continue;

      if (sn.isManual) {
        manualPlaces.add(sn);
      } else if (sn.geoapifyPlaceId != null) {
        overlaysByGeoapifyId[sn.geoapifyPlaceId!] = sn;
      }
    }

    final mergedPlaces = <Place>[];
    final processedGeoapifyIds = <String>{};

    // 1. Process Geoapify Places (both with and without SpotNugas overlays)
    for (final gp in geoapifyPlaces) {
      if (processedGeoapifyIds.contains(gp.geoapifyPlaceId)) continue;
      processedGeoapifyIds.add(gp.geoapifyPlaceId);

      final overlay = overlaysByGeoapifyId[gp.geoapifyPlaceId];
      final rawDist = origin?.distanceKmTo(gp.location);
      final distanceKm = rawDist != null ? (rawDist * 10).round() / 10 : null;

      mergedPlaces.add(
        Place.fromSources(
          geoapify: gp,
          spotNugas: overlay,
          distanceKm: distanceKm,
        ),
      );
    }

    // 2. Process Manual SpotNugas Places
    for (final manual in manualPlaces) {
      final loc = manual.location;
      final rawDist = loc != null ? origin?.distanceKmTo(loc) : null;
      final distanceKm = rawDist != null ? (rawDist * 10).round() / 10 : null;

      mergedPlaces.add(
        Place.fromSources(spotNugas: manual, distanceKm: distanceKm),
      );
    }

    return mergedPlaces;
  }

  /// Assembles a unified [List<Place>] from separate Google and SpotNugas sources.
  static List<Place> merge({
    required List<GooglePlaceData> googlePlaces,
    required List<SpotNugasPlaceData> spotNugasPlaces,
    GeoCoordinates? origin,
  }) {
    final overlaysByGoogleId = <String, SpotNugasPlaceData>{};
    final manualPlaces = <SpotNugasPlaceData>[];

    for (final sn in spotNugasPlaces) {
      if (!sn.isActive) continue;

      if (sn.isManual) {
        manualPlaces.add(sn);
      } else if (sn.isGoogle && sn.googlePlaceId != null) {
        overlaysByGoogleId[sn.googlePlaceId!] = sn;
      }
    }

    final mergedPlaces = <Place>[];
    final processedGoogleIds = <String>{};

    // 1. Process Google Places (both with and without SpotNugas overlays)
    for (final gp in googlePlaces) {
      if (processedGoogleIds.contains(gp.googlePlaceId)) continue;
      processedGoogleIds.add(gp.googlePlaceId);

      final overlay = overlaysByGoogleId[gp.googlePlaceId];
      final distanceKm = origin?.distanceKmTo(gp.location);

      mergedPlaces.add(
        Place.fromSources(
          google: gp,
          spotNugas: overlay,
          distanceKm: distanceKm,
        ),
      );
    }

    // 2. Process Manual SpotNugas Places
    for (final manual in manualPlaces) {
      final loc = manual.location;
      final distanceKm = loc != null ? origin?.distanceKmTo(loc) : null;

      mergedPlaces.add(
        Place.fromSources(spotNugas: manual, distanceKm: distanceKm),
      );
    }

    return mergedPlaces;
  }
}
