import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/geoapify_config.dart';
import '../models/place_types.dart';

/// Contract for reverse geocoding geographic coordinates to human-readable district/city names.
abstract class ReverseGeocodingService {
  Future<String?> reverseGeocode(GeoCoordinates coordinates);
  void clearCache();
}

/// Production implementation of [ReverseGeocodingService] using the Geoapify Geocoding API.
class GeoapifyReverseGeocodingService implements ReverseGeocodingService {
  final http.Client _client;
  final String _apiKey;
  final Duration _timeout;

  /// In-memory cache for reverse-geocoded coordinates (rounded to ~100m).
  final Map<String, String> _cache = {};

  @override
  void clearCache() => _cache.clear();

  GeoapifyReverseGeocodingService({
    http.Client? client,
    String? apiKey,
    Duration? timeout,
  }) : _client = client ?? http.Client(),
       _apiKey = apiKey ?? GeoapifyConfig.apiKey,
       _timeout = timeout ?? GeoapifyConfig.requestTimeout;

  @override
  Future<String?> reverseGeocode(GeoCoordinates coordinates) async {
    // Round to 3 decimal places (~110 meters) for caching efficiency
    final cacheKey =
        '${coordinates.latitude.toStringAsFixed(3)},${coordinates.longitude.toStringAsFixed(3)}';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    if (_apiKey.trim().isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[SpotNugas][ReverseGeocode] Skipped: API key is empty (${GeoapifyConfig.debugConfigStatus})',
        );
      }
      return null;
    }

    try {
      final uri = Uri.parse('https://api.geoapify.com/v1/geocode/reverse')
          .replace(
            queryParameters: {
              'lat': coordinates.latitude.toString(),
              'lon': coordinates.longitude.toString(),
              'lang': 'id',
              'apiKey': _apiKey.trim(),
            },
          );

      final response = await _client.get(uri).timeout(_timeout);
      if (kDebugMode) {
        debugPrint('[SpotNugas][ReverseGeocode] HTTP ${response.statusCode}');
      }
      if (response.statusCode != 200) {
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final features = json['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) {
        if (kDebugMode) {
          debugPrint('[SpotNugas][ReverseGeocode] 0 features returned');
        }
        return null;
      }

      final first = features.first as Map<String, dynamic>;
      final props = first['properties'] as Map<String, dynamic>?;
      if (props == null) return null;

      final label = _formatLocationName(props);
      if (kDebugMode) {
        debugPrint('[SpotNugas][ReverseGeocode] Resolved label="$label"');
      }
      if (label != null && label.isNotEmpty) {
        _cache[cacheKey] = label;
        return label;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SpotNugas][ReverseGeocode] Error: ${e.runtimeType}');
      }
    }

    return null;
  }

  /// Formats raw Geoapify properties into a natural district/city label.
  ///
  /// Examples:
  /// - "Tebet, Jakarta Selatan"
  /// - "Cengkareng, Jakarta Barat"
  /// - "Bandung"
  /// - "Depok"
  String? _formatLocationName(Map<String, dynamic> props) {
    final suburb = props['suburb'] as String?;
    final district = props['district'] as String?;
    final city = props['city'] as String?;
    final county = props['county'] as String?;
    final state = props['state'] as String?;

    final subArea = suburb ?? district;
    final mainArea = city ?? county ?? state;

    if (subArea != null && mainArea != null && subArea != mainArea) {
      return '$subArea, $mainArea';
    }

    if (mainArea != null && mainArea.isNotEmpty) {
      return mainArea;
    }

    if (subArea != null && subArea.isNotEmpty) {
      return subArea;
    }

    final formatted = props['formatted'] as String?;
    if (formatted != null && formatted.isNotEmpty) {
      final parts = formatted.split(',');
      if (parts.length >= 2) {
        return '${parts[0].trim()}, ${parts[1].trim()}';
      }
      return parts.first.trim();
    }

    return null;
  }
}
