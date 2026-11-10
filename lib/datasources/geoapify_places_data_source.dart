import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/geoapify_config.dart';
import '../models/geoapify_place_data.dart';
import '../models/place_types.dart';

/// Base exception for Geoapify Places API errors.
class GeoapifyException implements Exception {
  final String message;
  final int? statusCode;

  const GeoapifyException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Thrown when API key is missing, unauthorized (401), or forbidden (403).
class GeoapifyAuthException extends GeoapifyException {
  const GeoapifyAuthException(super.message, {super.statusCode});
}

/// Thrown when Geoapify rate limit / daily quota is exceeded (429).
class GeoapifyRateLimitException extends GeoapifyException {
  const GeoapifyRateLimitException(super.message, {super.statusCode});
}

/// Thrown when network is disconnected or request times out.
class GeoapifyNetworkException extends GeoapifyException {
  const GeoapifyNetworkException(super.message);
}

/// Thrown when Geoapify server responds with 5xx error.
class GeoapifyServerException extends GeoapifyException {
  const GeoapifyServerException(super.message, {super.statusCode});
}

/// Contract for fetching third-party place data from Geoapify Places API.
abstract class GeoapifyPlacesDataSource {
  /// Fetches nearby places within [radiusMeters] of [location].
  Future<List<GeoapifyPlaceData>> fetchNearbyPlaces({
    required GeoCoordinates location,
    int radiusMeters = GeoapifyConfig.defaultRadiusMeters,
    List<String> categories = GeoapifyConfig.defaultCategories,
    int limit = GeoapifyConfig.defaultLimit,
  });

  /// Searches places matching [query] around optional [location].
  Future<List<GeoapifyPlaceData>> searchPlaces({
    required String query,
    GeoCoordinates? location,
    int radiusMeters = GeoapifyConfig.defaultRadiusMeters,
    List<String> categories = GeoapifyConfig.defaultCategories,
    int limit = GeoapifyConfig.defaultLimit,
  });

  /// Retrieves place details by [geoapifyPlaceId].
  Future<GeoapifyPlaceData?> getPlaceDetails(String geoapifyPlaceId);

  /// Clears the in-memory cache.
  void clearCache();
}

/// In-memory cache entry with expiration timestamp.
class _CacheEntry<T> {
  final T data;
  final DateTime expiresAt;

  _CacheEntry(this.data, {Duration ttl = const Duration(minutes: 5)})
    : expiresAt = DateTime.now().add(ttl);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Production implementation of [GeoapifyPlacesDataSource] using HTTP.
class HttpGeoapifyPlacesDataSource implements GeoapifyPlacesDataSource {
  final http.Client _client;
  final String _apiKey;
  final Duration _timeout;

  /// In-memory response cache to prevent redundant network calls across screen changes.
  final Map<String, _CacheEntry<List<GeoapifyPlaceData>>> _cache = {};

  /// In-flight request deduplication map.
  final Map<String, Future<List<GeoapifyPlaceData>>> _inFlightRequests = {};

  HttpGeoapifyPlacesDataSource({
    http.Client? client,
    String? apiKey,
    Duration? timeout,
  }) : _client = client ?? http.Client(),
       _apiKey = apiKey ?? GeoapifyConfig.apiKey,
       _timeout = timeout ?? GeoapifyConfig.requestTimeout;

  @override
  void clearCache() {
    _cache.clear();
    _inFlightRequests.clear();
  }

  @override
  Future<List<GeoapifyPlaceData>> fetchNearbyPlaces({
    required GeoCoordinates location,
    int radiusMeters = GeoapifyConfig.defaultRadiusMeters,
    List<String> categories = GeoapifyConfig.defaultCategories,
    int limit = GeoapifyConfig.defaultLimit,
  }) async {
    final catParam = categories.join(',');
    // Cache key based on rounded coordinates and parameters
    final cacheKey =
        'nearby:${location.latitude.toStringAsFixed(4)},${location.longitude.toStringAsFixed(4)}:$radiusMeters:$catParam:$limit';

    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      if (kDebugMode) {
        debugPrint(
          '[SpotNugas][GeoapifyDataSource] Cache hit: ${cached.data.length} places',
        );
      }
      return cached.data;
    }

    if (_inFlightRequests.containsKey(cacheKey)) {
      return _inFlightRequests[cacheKey]!;
    }

    if (kDebugMode) {
      debugPrint(
        '[SpotNugas][GeoapifyDataSource] fetchNearbyPlaces: radius=${radiusMeters}m, limit=$limit, ${GeoapifyConfig.debugConfigStatus}',
      );
    }

    // GeoJSON circle filter format: circle:lon,lat,radiusMeters
    final queryParams = {
      'categories': catParam,
      'filter':
          'circle:${location.longitude.toStringAsFixed(6)},${location.latitude.toStringAsFixed(6)},$radiusMeters',
      'bias':
          'proximity:${location.longitude.toStringAsFixed(6)},${location.latitude.toStringAsFixed(6)}',
      'limit': limit.toString(),
      'apiKey': _apiKey.trim(),
    };

    final uri = Uri.parse(
      GeoapifyConfig.baseUrl,
    ).replace(queryParameters: queryParams);

    final future = _executeRequest(uri)
        .then((data) {
          _cache[cacheKey] = _CacheEntry(data);
          _inFlightRequests.remove(cacheKey);
          return data;
        })
        .catchError((error) {
          _inFlightRequests.remove(cacheKey);
          throw error;
        });

    _inFlightRequests[cacheKey] = future;
    return future;
  }

  @override
  Future<List<GeoapifyPlaceData>> searchPlaces({
    required String query,
    GeoCoordinates? location,
    int radiusMeters = GeoapifyConfig.defaultRadiusMeters,
    List<String> categories = GeoapifyConfig.defaultCategories,
    int limit = GeoapifyConfig.defaultLimit,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      if (location != null) {
        return fetchNearbyPlaces(
          location: location,
          radiusMeters: radiusMeters,
          categories: categories,
          limit: limit,
        );
      }
      return const [];
    }

    final catParam = categories.join(',');
    final locKey = location != null
        ? '${location.latitude.toStringAsFixed(4)},${location.longitude.toStringAsFixed(4)}'
        : 'no_loc';
    final cacheKey =
        'search:$cleanQuery:$locKey:$radiusMeters:$catParam:$limit';

    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }

    if (_inFlightRequests.containsKey(cacheKey)) {
      return _inFlightRequests[cacheKey]!;
    }

    final queryParams = <String, String>{
      'name': cleanQuery,
      'categories': catParam,
      'limit': limit.toString(),
      'apiKey': _apiKey.trim(),
    };

    if (location != null) {
      queryParams['filter'] =
          'circle:${location.longitude.toStringAsFixed(6)},${location.latitude.toStringAsFixed(6)},$radiusMeters';
      queryParams['bias'] =
          'proximity:${location.longitude.toStringAsFixed(6)},${location.latitude.toStringAsFixed(6)}';
    }

    final uri = Uri.parse(
      GeoapifyConfig.baseUrl,
    ).replace(queryParameters: queryParams);

    final future = _executeRequest(uri)
        .then((data) {
          _cache[cacheKey] = _CacheEntry(data);
          _inFlightRequests.remove(cacheKey);
          return data;
        })
        .catchError((error) {
          _inFlightRequests.remove(cacheKey);
          throw error;
        });

    _inFlightRequests[cacheKey] = future;
    return future;
  }

  @override
  Future<GeoapifyPlaceData?> getPlaceDetails(String geoapifyPlaceId) async {
    final cleanId = geoapifyPlaceId.trim().replaceAll('geoapify:', '');
    if (cleanId.isEmpty) return null;

    // Check existing cached items first
    for (final entry in _cache.values) {
      if (!entry.isExpired) {
        for (final item in entry.data) {
          if (item.geoapifyPlaceId == cleanId) {
            return item;
          }
        }
      }
    }

    // Direct place lookup using place_id query
    final queryParams = {'id': cleanId, 'apiKey': _apiKey.trim()};

    final uri = Uri.parse(
      GeoapifyConfig.baseUrl,
    ).replace(queryParameters: queryParams);

    final results = await _executeRequest(uri);
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<GeoapifyPlaceData>> _executeRequest(Uri uri) async {
    if (_apiKey.trim().isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[SpotNugas][GeoapifyDataSource] Aborted: API key is empty (${GeoapifyConfig.debugConfigStatus})',
        );
      }
      throw const GeoapifyAuthException(
        'Kunci API Geoapify belum dikonfigurasi. Jalankan dengan --dart-define-from-file=.secrets/geoapify.dev.json',
      );
    }

    http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
      if (kDebugMode) {
        debugPrint(
          '[SpotNugas][GeoapifyDataSource] HTTP ${response.statusCode}',
        );
      }
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint(
          '[SpotNugas][GeoapifyDataSource] HTTP timeout after $_timeout',
        );
      }
      throw const GeoapifyNetworkException(
        'Permintaan ke Geoapify melebihi batas waktu (timeout). Periksa koneksi internet Anda.',
      );
    } on SocketException {
      if (kDebugMode) {
        debugPrint('[SpotNugas][GeoapifyDataSource] Connection failed');
      }
      throw const GeoapifyNetworkException(
        'Gagal terhubung ke Geoapify. Periksa koneksi internet Anda.',
      );
    } catch (_) {
      if (kDebugMode) {
        debugPrint('[SpotNugas][GeoapifyDataSource] Network request failed');
      }
      throw const GeoapifyNetworkException(
        'Terjadi kendala jaringan saat menghubungi Geoapify. Silakan coba lagi.',
      );
    }

    if (response.statusCode == 200) {
      try {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        if (decoded is! Map<String, dynamic> || decoded['features'] is! List) {
          throw const FormatException('Expected a features list');
        }
        final features = decoded['features'] as List;
        if (features.isEmpty) {
          if (kDebugMode) {
            debugPrint(
              '[SpotNugas][GeoapifyDataSource] HTTP 200 but features list is empty (0 places)',
            );
          }
          return const [];
        }

        final parsedList = <GeoapifyPlaceData>[];
        final seenIds = <String>{};

        for (final f in features) {
          if (f is! Map<String, dynamic>) {
            throw const FormatException('Expected a place feature');
          }
          final place = GeoapifyPlaceData.fromGeoJson(f);
          if (place.geoapifyPlaceId.isEmpty) {
            throw const FormatException('Missing place identifier');
          }
          if (seenIds.add(place.geoapifyPlaceId)) {
            parsedList.add(place);
          }
        }

        if (kDebugMode) {
          debugPrint(
            '[SpotNugas][GeoapifyDataSource] HTTP 200 -> rawFeatures=${features.length}, uniqueParsedPlaces=${parsedList.length}',
          );
        }
        return parsedList;
      } catch (_) {
        if (kDebugMode) {
          debugPrint('[SpotNugas][GeoapifyDataSource] Invalid response format');
        }
        throw const GeoapifyServerException(
          'Format respons Geoapify tidak valid. Silakan coba lagi.',
        );
      }
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw GeoapifyAuthException(
        'Akses Geoapify ditolak (HTTP ${response.statusCode}). Periksa konfigurasi API key.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode == 429) {
      throw GeoapifyRateLimitException(
        'Batas permintaan Geoapify tercapai (HTTP 429). Silakan tunggu beberapa saat.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 500) {
      throw GeoapifyServerException(
        'Server Geoapify mengalami kendala (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    throw GeoapifyException(
      'Gagal mengambil data dari Geoapify (HTTP ${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }
}
