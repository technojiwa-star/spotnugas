import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/geoapify_config.dart';
import '../constants/app_location.dart';
import '../models/place_types.dart';
import '../services/device_location_service.dart';
import '../services/reverse_geocoding_service.dart';

/// Source origin of the current active location.
enum LocationSource {
  /// Acquired from device GPS/network location hardware.
  deviceGps,

  /// Explicitly chosen by the user from preset or manual options.
  manual,

  /// Fallback demo location for offline mode or test harness.
  demoFallback,
}

/// Represents user/application location state.
class LocationState {
  static const _unchangedError = Object();

  final GeoCoordinates coordinates;
  final String label;
  final bool isMock;
  final LocationSource source;
  final LocationPermissionStatus permissionStatus;
  final bool isLoading;
  final String? errorMessage;
  final bool isApproximate;
  final bool hasSelectedLocation;

  const LocationState({
    required this.coordinates,
    required this.label,
    this.isMock = false,
    this.source = LocationSource.demoFallback,
    this.permissionStatus = LocationPermissionStatus.granted,
    this.isLoading = false,
    this.errorMessage,
    this.isApproximate = false,
    this.hasSelectedLocation = true,
  });

  /// No GPS fix or explicit selection yet. Coordinates are a map placeholder
  /// and must not be used for discovery until [hasSelectedLocation] is true.
  factory LocationState.unresolved() => const LocationState(
    coordinates: AppLocation.defaultJakarta,
    label: 'Pilih Lokasi',
    permissionStatus: LocationPermissionStatus.denied,
    hasSelectedLocation: false,
  );

  /// Default production target for SpotNugas (Jakarta).
  factory LocationState.jakarta({
    LocationSource source = LocationSource.manual,
    LocationPermissionStatus permissionStatus =
        LocationPermissionStatus.granted,
  }) => LocationState(
    coordinates: AppLocation.defaultJakarta,
    label: AppLocation.defaultJakartaLabel,
    isMock: false,
    source: source,
    permissionStatus: permissionStatus,
  );

  /// Explicit mock location for tests and offline seed data.
  factory LocationState.mockYogyakarta() => const LocationState(
    coordinates: AppLocation.mockYogyakartaOrigin,
    label: AppLocation.mockYogyakartaLabel,
    isMock: true,
    source: LocationSource.demoFallback,
    permissionStatus: LocationPermissionStatus.granted,
  );

  LocationState copyWith({
    GeoCoordinates? coordinates,
    String? label,
    bool? isMock,
    LocationSource? source,
    LocationPermissionStatus? permissionStatus,
    bool? isLoading,
    Object? errorMessage = _unchangedError,
    bool? isApproximate,
    bool? hasSelectedLocation,
  }) {
    return LocationState(
      coordinates: coordinates ?? this.coordinates,
      label: label ?? this.label,
      isMock: isMock ?? this.isMock,
      source: source ?? this.source,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _unchangedError)
          ? this.errorMessage
          : errorMessage as String?,
      isApproximate: isApproximate ?? this.isApproximate,
      hasSelectedLocation: hasSelectedLocation ?? this.hasSelectedLocation,
    );
  }
}

/// State notifier managing device GPS discovery, permissions, and manual overrides.
class LocationNotifier extends StateNotifier<LocationState> {
  final DeviceLocationService locationService;
  final ReverseGeocodingService reverseGeocodingService;
  int _requestGeneration = 0;

  LocationNotifier({
    required this.locationService,
    required this.reverseGeocodingService,
    LocationState? initialState,
  }) : super(
         initialState ??
             (GeoapifyConfig.hasApiKey
                 ? LocationState.unresolved()
                 : LocationState.mockYogyakarta()),
       );

  /// Requests device location and updates active coordinates & human-readable label.
  Future<void> detectDeviceLocation({bool force = false}) async {
    if (!mounted || (state.isLoading && !force)) return;
    final requestGeneration = ++_requestGeneration;

    if (kDebugMode) {
      debugPrint(
        '[SpotNugas][Location] detectDeviceLocation(force: $force) start (${GeoapifyConfig.debugConfigStatus})',
      );
    }
    state = state.copyWith(isLoading: true, errorMessage: null);

    DeviceLocationResult result;
    try {
      result = await locationService.getCurrentLocation();
    } catch (_) {
      result = DeviceLocationResult.failure(
        LocationPermissionStatus.error,
        message:
            'Gagal mendapatkan lokasi perangkat. Coba lagi atau pilih lokasi manual.',
      );
    }
    if (!_isCurrentRequest(requestGeneration)) return;
    if (!result.isSuccess) {
      if (kDebugMode) {
        debugPrint(
          '[SpotNugas][Location] getCurrentLocation failed: status=${result.status}',
        );
      }
      String fallbackLabel = state.label;
      if (!state.hasSelectedLocation &&
          result.status == LocationPermissionStatus.denied) {
        fallbackLabel = 'Pilih Lokasi (Izin Ditolak)';
      } else if (!state.hasSelectedLocation &&
          result.status == LocationPermissionStatus.permanentlyDenied) {
        fallbackLabel = 'Pilih Lokasi (Izin Dinonaktifkan)';
      } else if (!state.hasSelectedLocation &&
          result.status == LocationPermissionStatus.serviceDisabled) {
        fallbackLabel = 'Pilih Lokasi (GPS Mati)';
      }

      state = state.copyWith(
        isLoading: false,
        permissionStatus: result.status,
        errorMessage: result.errorMessage,
        label: fallbackLabel,
      );
      return;
    }

    final coords = result.coordinates!;
    if (kDebugMode) {
      debugPrint(
        '[SpotNugas][Location] GPS coordinates acquired (approximate: ${result.isApproximate})',
      );
    }
    String? resolvedLabel;
    try {
      resolvedLabel = await reverseGeocodingService.reverseGeocode(coords);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[SpotNugas][Location] reverseGeocode error: ${e.runtimeType}',
        );
      }
    }
    if (!_isCurrentRequest(requestGeneration)) return;

    final finalLabel = resolvedLabel ?? 'Lokasi Terdeteksi';
    if (kDebugMode) {
      debugPrint('[SpotNugas][Location] Location updated: label="$finalLabel"');
    }

    state = state.copyWith(
      coordinates: coords,
      label: finalLabel,
      isMock: false,
      source: LocationSource.deviceGps,
      permissionStatus: LocationPermissionStatus.granted,
      isApproximate: result.isApproximate,
      isLoading: false,
      errorMessage: null,
      hasSelectedLocation: true,
    );
  }

  /// Manually selects a city / district without requesting GPS.
  void setManualLocation(GeoCoordinates coords, String label) {
    if (!mounted) return;
    ++_requestGeneration;
    final isMock = label.contains('Sleman') || label.contains('Demo');
    if (kDebugMode) {
      debugPrint(
        '[SpotNugas][Location] setManualLocation: label="$label", isMock=$isMock',
      );
    }
    state = state.copyWith(
      coordinates: coords,
      label: label,
      isMock: isMock,
      source: LocationSource.manual,
      permissionStatus: LocationPermissionStatus.granted,
      isLoading: false,
      errorMessage: null,
      isApproximate: false,
      hasSelectedLocation: true,
    );
  }

  bool _isCurrentRequest(int requestGeneration) =>
      mounted && requestGeneration == _requestGeneration;

  Future<bool> openAppSettings() => locationService.openAppSettings();
  Future<bool> openLocationSettings() => locationService.openLocationSettings();
}

/// Provider for the [DeviceLocationService].
final deviceLocationServiceProvider = Provider<DeviceLocationService>((ref) {
  return const GeolocatorDeviceLocationService();
});

/// Provider for the [ReverseGeocodingService].
final reverseGeocodingServiceProvider = Provider<ReverseGeocodingService>((
  ref,
) {
  return GeoapifyReverseGeocodingService();
});

/// Provides the active location state and notifier for the entire application.
final currentLocationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
      final locService = ref.watch(deviceLocationServiceProvider);
      final reverseGeo = ref.watch(reverseGeocodingServiceProvider);
      return LocationNotifier(
        locationService: locService,
        reverseGeocodingService: reverseGeo,
      );
    });

/// Convenience provider for the human-readable location label in app bars.
final currentLocationLabelProvider = Provider<String>((ref) {
  return ref.watch(currentLocationProvider).label;
});
