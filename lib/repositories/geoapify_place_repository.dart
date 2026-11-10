import 'package:flutter/foundation.dart';
import '../datasources/geoapify_places_data_source.dart';
import '../models/place.dart';
import '../models/spotnugas_place_data.dart';
import '../utils/place_merger.dart';
import 'place_repository.dart';

/// Live [PlaceRepository] backed by Geoapify Places API.
///
/// Discovers public cafes, coworking spaces, and libraries around the user
/// without requiring prior business registration.
class GeoapifyPlaceRepository implements PlaceRepository {
  final GeoapifyPlacesDataSource dataSource;
  final List<SpotNugasPlaceData> overlays;

  /// In-memory cache of most recently fetched places for instantaneous lookups.
  final Map<String, Place> _placeCache = {};

  GeoapifyPlaceRepository({required this.dataSource, this.overlays = const []});

  @override
  Future<List<Place>> getNearbyPlaces({
    required GeoCoordinates origin,
    double radiusKm = 5.0,
    int? limit,
  }) async {
    final radiusMeters = (radiusKm * 1000).round();
    var geoapifyPlaces = await dataSource.fetchNearbyPlaces(
      location: origin,
      radiusMeters: radiusMeters,
      limit: limit ?? 20,
    );

    // If 5km radius around user's origin has 0 mapped OSM venues, expand radius to 20km
    // keeping the exact same origin location.
    if (geoapifyPlaces.isEmpty && radiusMeters < 20000) {
      if (kDebugMode) {
        debugPrint(
          '[SpotNugas][GeoapifyRepo] 0 places within ${radiusMeters}m; retrying with 20000m radius around origin',
        );
      }
      geoapifyPlaces = await dataSource.fetchNearbyPlaces(
        location: origin,
        radiusMeters: 20000,
        limit: limit ?? 20,
      );
    }

    final merged = PlaceMerger.mergeGeoapify(
      geoapifyPlaces: geoapifyPlaces,
      spotNugasPlaces: overlays,
      origin: origin,
    );

    for (final p in merged) {
      _placeCache[p.id] = p;
      if (p.geoapifyPlaceId != null) {
        _placeCache[p.geoapifyPlaceId!] = p;
      }
    }

    final returned = (limit != null && merged.length > limit)
        ? merged.take(limit).toList()
        : merged;
    if (kDebugMode) {
      debugPrint(
        '[SpotNugas][GeoapifyRepo] getNearbyPlaces: radiusKm=$radiusKm -> apiCount=${geoapifyPlaces.length}, mergedCount=${merged.length}, returnedCount=${returned.length}',
      );
    }
    return returned;
  }

  @override
  Future<List<Place>> searchPlaces(PlaceSearchQuery query) async {
    final text = query.text.trim();
    List<Place> results;

    if (text.isEmpty) {
      if (query.origin != null) {
        results = await getNearbyPlaces(
          origin: query.origin!,
          limit: query.limit ?? 20,
        );
      } else {
        results = _placeCache.values.toList();
      }
    } else {
      // Remote search via Geoapify name query
      final geoResults = await dataSource.searchPlaces(
        query: text,
        location: query.origin,
        limit: query.limit ?? 20,
      );

      results = PlaceMerger.mergeGeoapify(
        geoapifyPlaces: geoResults,
        spotNugasPlaces: overlays,
        origin: query.origin,
      );

      for (final p in results) {
        _placeCache[p.id] = p;
        if (p.geoapifyPlaceId != null) {
          _placeCache[p.geoapifyPlaceId!] = p;
        }
      }
    }

    final beforeFilterCount = results.length;

    // Apply local tag / category filter
    if (query.tag != null && query.tag!.isNotEmpty && query.tag != 'Semua') {
      final tagLower = query.tag!.toLowerCase();
      results = results.where((p) {
        if (p.tags.contains(query.tag)) return true;
        if (p.category.toLowerCase().contains(tagLower)) return true;
        if (tagLower.contains('wifi') || tagLower.contains('wi-fi')) {
          return p.facilities.contains(PlaceFacility.wifi) ||
              (p.wifiScore ?? 0) >= 4.5 ||
              p.category.toLowerCase().contains('cafe') ||
              p.category.toLowerCase().contains('coworking');
        }
        if (tagLower.contains('colokan')) {
          return p.facilities.contains(PlaceFacility.powerOutlet) ||
              (p.outletScore ?? 0) >= 4.5 ||
              p.category.toLowerCase().contains('coworking');
        }
        if (tagLower.contains('hemat')) {
          return p.priceLevel == PlacePriceLevel.free ||
              p.priceLevel == PlacePriceLevel.inexpensive ||
              p.category.toLowerCase().contains('perpustakaan');
        }
        if (tagLower.contains('malam') || tagLower.contains('24 jam')) {
          return p.openStatusLabel.toLowerCase().contains('24') ||
              p.suitableFor.contains(PlaceSuitability.lateNight);
        }
        if (tagLower.contains('fokus') || tagLower.contains('tenang')) {
          return p.facilities.contains(PlaceFacility.quietZone) ||
              p.category.toLowerCase().contains('perpustakaan');
        }
        if (tagLower.contains('kelompok')) {
          return p.facilities.contains(PlaceFacility.groupSeating) ||
              p.category.toLowerCase().contains('coworking');
        }
        return false;
      }).toList();
    }

    // Sort according to requested option
    results.sort(query.sort.compare);

    final finalResults = (query.limit != null && results.length > query.limit!)
        ? results.take(query.limit!).toList()
        : results;
    if (kDebugMode) {
      debugPrint(
        '[SpotNugas][GeoapifyRepo] searchPlaces text="${query.text}", tag=${query.tag ?? "Semua"} -> beforeFilter=$beforeFilterCount, afterFilter=${finalResults.length}',
      );
    }
    return finalResults;
  }

  @override
  Future<Place?> getPlaceById(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return null;

    if (_placeCache.containsKey(cleanId)) {
      return _placeCache[cleanId];
    }

    // If formatted key like 'geoapify:xxx', also check raw 'xxx'
    final rawId = cleanId.replaceAll('geoapify:', '');
    if (_placeCache.containsKey(rawId)) {
      return _placeCache[rawId];
    }

    // Fetch place details from data source
    final geoapifyData = await dataSource.getPlaceDetails(rawId);
    if (geoapifyData == null) return null;

    final merged = PlaceMerger.mergeGeoapify(
      geoapifyPlaces: [geoapifyData],
      spotNugasPlaces: overlays,
    );

    if (merged.isNotEmpty) {
      final place = merged.first;
      _placeCache[place.id] = place;
      _placeCache[rawId] = place;
      return place;
    }

    return null;
  }
}
