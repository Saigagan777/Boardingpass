import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Singleton service wrapping the Geolocator plugin.
///
/// Provides helpers for requesting permissions, obtaining the current
/// position, calculating distances, generating geohashes, and streaming
/// position changes (foreground only).
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  /// Requests location permission from the user.
  ///
  /// Returns the resulting [LocationPermission].
  Future<LocationPermission> requestPermission() async {
    try {
      return await Geolocator.requestPermission();
    } catch (e) {
      throw Exception('Failed to request location permission: $e');
    }
  }

  /// Returns `true` if location permission is currently granted
  /// (either `always` or `whileInUse`).
  Future<bool> isPermissionGranted() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      return false;
    }
  }

  /// Checks whether the device's location service is enabled.
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Current position
  // ---------------------------------------------------------------------------

  /// Returns the device's current position.
  ///
  /// Requests permission first if not already granted.  Throws on failure.
  Future<Position> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permissions are permanently denied. '
          'Please enable them in Settings.',
        );
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      throw Exception('Failed to get current position: $e');
    }
  }

  /// Convenience – returns the current position as a Firestore [GeoPoint].
  Future<GeoPoint> getCurrentGeoPoint() async {
    final position = await getCurrentPosition();
    return GeoPoint(position.latitude, position.longitude);
  }

  // ---------------------------------------------------------------------------
  // Distance
  // ---------------------------------------------------------------------------

  /// Calculates the distance in **metres** between two coordinates.
  double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Calculates the distance in **kilometres** between two [GeoPoint]s.
  double distanceBetweenGeoPoints(GeoPoint a, GeoPoint b) {
    return distanceBetween(
      startLatitude: a.latitude,
      startLongitude: a.longitude,
      endLatitude: b.latitude,
      endLongitude: b.longitude,
    ) / 1000.0;
  }

  // ---------------------------------------------------------------------------
  // Geohash generation
  // ---------------------------------------------------------------------------

  /// Generates a geohash string of the given [precision] (default 9) for the
  /// supplied [latitude] and [longitude].
  ///
  /// This is a self-contained implementation so the service has no hard
  /// dependency on GeoFlutterFire at runtime, but is compatible with its
  /// geohash format.
  String generateGeohash(
    double latitude,
    double longitude, {
    int precision = 9,
  }) {
    const base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

    double minLat = -90, maxLat = 90;
    double minLon = -180, maxLon = 180;

    final buffer = StringBuffer();
    bool isEven = true;
    int bit = 0;
    int ch = 0;

    while (buffer.length < precision) {
      if (isEven) {
        final mid = (minLon + maxLon) / 2;
        if (longitude >= mid) {
          ch |= (1 << (4 - bit));
          minLon = mid;
        } else {
          maxLon = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2;
        if (latitude >= mid) {
          ch |= (1 << (4 - bit));
          minLat = mid;
        } else {
          maxLat = mid;
        }
      }

      isEven = !isEven;
      bit++;

      if (bit == 5) {
        buffer.write(base32[ch]);
        bit = 0;
        ch = 0;
      }
    }

    return buffer.toString();
  }

  /// Convenience – generates a geohash from a [Position].
  String geohashFromPosition(Position position, {int precision = 9}) {
    return generateGeohash(position.latitude, position.longitude,
        precision: precision);
  }

  // ---------------------------------------------------------------------------
  // Streaming
  // ---------------------------------------------------------------------------

  /// Streams position updates while the app is in the foreground.
  ///
  /// Use [distanceFilter] (in metres) to control how often updates fire.
  Stream<Position> streamPosition({int distanceFilter = 100}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    );
  }
}
