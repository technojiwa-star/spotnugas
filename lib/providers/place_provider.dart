import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/geoapify_config.dart';
import '../datasources/geoapify_places_data_source.dart';
import '../datasources/google_places_data_source.dart';
import '../models/place.dart';
import '../repositories/geoapify_place_repository.dart';
import '../repositories/mock_place_repository.dart';
import '../repositories/place_repository.dart';
import 'location_provider.dart';

/// Provides the Geoapify Places API data source.
final geoapifyPlacesDataSourceProvider = Provider<GeoapifyPlacesDataSource>((
  ref,
) {
  return HttpGeoapifyPlacesDataSource();
});

/// Provides the repository instance backed by live Geoapify API.
final geoapifyPlaceRepositoryProvider = Provider<PlaceRepository>((ref) {
  final dataSource = ref.watch(geoapifyPlacesDataSourceProvider);
  return GeoapifyPlaceRepository(dataSource: dataSource);
});

/// Explicit toggle to force mock places (useful for offline development & tests).
final forceMockPlacesProvider = StateProvider<bool>((ref) => false);

/// Provides the active [PlaceRepository] instance.
///
/// In Phase G1:
/// - When [GeoapifyConfig.hasApiKey] is true and not forced to mock, injects [GeoapifyPlaceRepository].
/// - Otherwise, injects [MockPlaceRepository] for offline-safe tests and seed development.
final placeRepositoryProvider = Provider<PlaceRepository>((ref) {
  final forceMock = ref.watch(forceMockPlacesProvider);
  if (GeoapifyConfig.hasApiKey && !forceMock) {
    return ref.watch(geoapifyPlaceRepositoryProvider);
  }
  return MockPlaceRepository();
});

/// Provides the Google Places API data source.
final googlePlacesDataSourceProvider = Provider<GooglePlacesDataSource>((ref) {
  return const MockGooglePlacesDataSource();
});

/// Convenience FutureProvider for nearby places using the active location.
final nearbyPlacesProvider = FutureProvider<List<Place>>((ref) async {
  final repo = ref.watch(placeRepositoryProvider);
  final location = ref.watch(currentLocationProvider);
  if (!location.hasSelectedLocation) return const [];
  return repo.getNearbyPlaces(origin: location.coordinates);
});
