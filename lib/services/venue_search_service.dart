import '../utils/google_search_helper.dart';

class VenueSearchResult {
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  const VenueSearchResult({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  String get openStreetMapUrl =>
      'https://www.openstreetmap.org/?mlat=$latitude&mlon=$longitude#map=16/$latitude/$longitude';

  factory VenueSearchResult.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? '';
    final address = json['formatted_address']?.toString() ?? '';
    final geometry = json['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;
    final parsedLatitude = double.tryParse(location?['lat']?.toString() ?? '');
    final parsedLongitude = double.tryParse(location?['lng']?.toString() ?? '');

    return VenueSearchResult(
      name: name.isNotEmpty ? name : address,
      address: address,
      latitude: parsedLatitude ?? 0,
      longitude: parsedLongitude ?? 0,
    );
  }
}

class VenueSearchService {
  Future<List<VenueSearchResult>> searchVenues(String query) async {
    final venues = await searchGooglePlaces(query);
    return venues.map((v) => VenueSearchResult(
      name: v.name,
      address: v.formattedAddress,
      latitude: v.latitude,
      longitude: v.longitude,
    )).toList();
  }
}
