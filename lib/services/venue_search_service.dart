import 'dart:convert';

import 'package:http/http.dart' as http;

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
    final displayName = json['display_name']?.toString() ?? '';
    final parts = displayName.split(',').map((part) => part.trim()).toList();
    final parsedLatitude = double.tryParse(json['lat']?.toString() ?? '');
    final parsedLongitude = double.tryParse(json['lon']?.toString() ?? '');

    return VenueSearchResult(
      name: (json['name']?.toString().isNotEmpty == true)
          ? json['name'].toString()
          : (parts.isNotEmpty ? parts.first : displayName),
      address: displayName,
      latitude: parsedLatitude ?? 0,
      longitude: parsedLongitude ?? 0,
    );
  }
}

class VenueSearchService {
  Future<List<VenueSearchResult>> searchVenues(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 3) return [];

    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      {
        'q': trimmedQuery,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '8',
      },
    );

    final response = await http.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'NexMeet/1.0 contact@NexMeet.app',
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw Exception('Venue search failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return [];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(VenueSearchResult.fromJson)
        .where((result) => result.latitude != 0 && result.longitude != 0)
        .toList();
  }
}
