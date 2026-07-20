import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

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
  /// Requests permission first if not already granted. Throws on failure.
  Future<Position> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled on device');
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
          'Location permissions are permanently denied. Please enable them in device settings.',
        );
      }

      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 12),
          ),
        );
      } catch (e) {
        // Fallback to getLastKnownPosition if getCurrentPosition fails or times out
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          return lastKnown;
        }
        // If last known is also null, try with lowest accuracy
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.lowest,
            timeLimit: Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      throw Exception('Failed to get current position: $e');
    }
  }

  /// Reverse geocodes coordinates to get City, State, and Country.
  /// Uses native placemarkFromCoordinates with OpenStreetMap web fallback.
  Future<Map<String, String>> reverseGeocode(double latitude, double longitude) async {
    String city = '';
    String state = '';
    String country = '';

    // 1. Try native geocoding plugin
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude).timeout(const Duration(seconds: 6));
      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        country = pm.country ?? '';
        state = pm.administrativeArea ?? '';
        city = (pm.locality?.isNotEmpty == true)
            ? pm.locality!
            : ((pm.subAdministrativeArea?.isNotEmpty == true)
                ? pm.subAdministrativeArea!
                : (pm.subLocality ?? ''));
      }
    } catch (_) {}

    // 2. Fallback to OpenStreetMap Nominatim API if native geocoding is empty
    if (city.isEmpty && country.isEmpty) {
      try {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&zoom=10',
        );
        final response = await http.get(uri, headers: {
          'User-Agent': 'NexMeetApp/1.0',
        }).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>?;
          final address = data?['address'] as Map<String, dynamic>?;
          if (address != null) {
            city = address['city'] ??
                address['town'] ??
                address['village'] ??
                address['municipality'] ??
                address['county'] ??
                address['state_district'] ??
                '';
            state = address['state'] ?? '';
            country = address['country'] ?? '';
          }
        }
      } catch (_) {}
    }

    return {
      'city': city,
      'state': state,
      'country': country,
    };
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
