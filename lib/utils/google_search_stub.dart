import '../models/venue.dart';

Future<List<Venue>> searchGooglePlaces(String query, {String? city, Map<String, dynamic>? filters}) {
  throw UnimplementedError('searchGooglePlaces has not been implemented on this platform.');
}

Future<List<Map<String, dynamic>>> searchGoogleGeocoding(String query) {
  throw UnimplementedError('searchGoogleGeocoding has not been implemented on this platform.');
}

Future<Map<String, String>?> reverseGeocodeAddress(double lat, double lng) {
  throw UnimplementedError('reverseGeocodeAddress has not been implemented on this platform.');
}
