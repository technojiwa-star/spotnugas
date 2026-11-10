import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/place_types.dart';

/// Status of location permissions and device hardware availability.
enum LocationPermissionStatus {
  /// Foreground permission granted (fine or coarse).
  granted,

  /// Permission denied by user, but can be requested again.
  denied,

  /// Permission permanently denied. User must enable in App Settings.
  permanentlyDenied,

  /// Location service (GPS/network) is turned off on the device.
  serviceDisabled,

  /// GPS fix timed out before a valid location was obtained.
  timeout,

  /// Unexpected error during location acquisition.
  error,
}

/// Result of querying the device's physical location.
class DeviceLocationResult {
  final GeoCoordinates? coordinates;
  final LocationPermissionStatus status;
  final String? errorMessage;
  final bool isApproximate;

  const DeviceLocationResult({
    this.coordinates,
    required this.status,
    this.errorMessage,
    this.isApproximate = false,
  });

  bool get isSuccess =>
      status == LocationPermissionStatus.granted && coordinates != null;

  factory DeviceLocationResult.success(
    GeoCoordinates coords, {
    bool isApproximate = false,
  }) {
    return DeviceLocationResult(
      coordinates: coords,
      status: LocationPermissionStatus.granted,
      isApproximate: isApproximate,
    );
  }

  factory DeviceLocationResult.failure(
    LocationPermissionStatus status, {
    String? message,
  }) {
    return DeviceLocationResult(
      coordinates: null,
      status: status,
      errorMessage: message,
    );
  }
}

/// Abstract contract for device location services to enable 100% mocked testing.
abstract class DeviceLocationService {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermissionStatus> checkPermission();
  Future<LocationPermissionStatus> requestPermission();
  Future<DeviceLocationResult> getCurrentLocation({
    Duration timeout = const Duration(seconds: 8),
  });
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

/// Production implementation of [DeviceLocationService] using the `geolocator` package.
class GeolocatorDeviceLocationService implements DeviceLocationService {
  const GeolocatorDeviceLocationService();

  @override
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<LocationPermissionStatus> checkPermission() async {
    try {
      final perm = await Geolocator.checkPermission();
      return _mapPermission(perm);
    } catch (e) {
      return LocationPermissionStatus.error;
    }
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    try {
      final perm = await Geolocator.requestPermission();
      return _mapPermission(perm);
    } catch (e) {
      return LocationPermissionStatus.error;
    }
  }

  @override
  Future<DeviceLocationResult> getCurrentLocation({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      // 1. Verify service status
      final isServiceOn = await isLocationServiceEnabled();
      if (!isServiceOn) {
        return DeviceLocationResult.failure(
          LocationPermissionStatus.serviceDisabled,
          message:
              'Layanan lokasi (GPS) sedang dinonaktifkan di perangkat ini.',
        );
      }

      // 2. Check/request permission
      var status = await checkPermission();
      if (status == LocationPermissionStatus.denied) {
        status = await requestPermission();
      }

      if (status != LocationPermissionStatus.granted) {
        return DeviceLocationResult.failure(
          status,
          message: status == LocationPermissionStatus.permanentlyDenied
              ? 'Izin lokasi ditolak permanen. Silakan aktifkan di Pengaturan.'
              : 'Izin lokasi dibutuhkan untuk menampilkan spot terdekat.',
        );
      }

      // 3. Acquire current location with strict timeout to prevent infinite hangs
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: timeout,
          ),
        );

        final isApprox =
            position.accuracy >
            500; // Greater than 500m indicates coarse/approximate
        return DeviceLocationResult.success(
          GeoCoordinates(position.latitude, position.longitude),
          isApproximate: isApprox,
        );
      } on TimeoutException {
        // Fallback to last known position on timeout
        try {
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null) {
            return DeviceLocationResult.success(
              GeoCoordinates(lastKnown.latitude, lastKnown.longitude),
              isApproximate: true,
            );
          }
        } catch (_) {}

        return DeviceLocationResult.failure(
          LocationPermissionStatus.timeout,
          message:
              'Waktu pencarian GPS habis. Coba lagi atau pilih lokasi manual.',
        );
      }
    } catch (_) {
      return DeviceLocationResult.failure(
        LocationPermissionStatus.error,
        message:
            'Gagal mendapatkan lokasi perangkat. Coba lagi atau pilih lokasi manual.',
      );
    }
  }

  @override
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  LocationPermissionStatus _mapPermission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.granted;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.permanentlyDenied;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.denied;
    }
  }
}
