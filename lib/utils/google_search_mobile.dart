import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/venue.dart';
import '../models/enums.dart';

Future<List<Venue>> searchGooglePlaces(String query, {String? city, Map<String, dynamic>? filters}) async {
  final trimmedQuery = query.trim();
  if (trimmedQuery.length < 3) return [];

  final uri = Uri.https(
    'maps.googleapis.com',
    '/maps/api/place/textsearch/json',
    {
      'query': trimmedQuery,
      'key': 'AIzaSyAXjzGoUZVyISPLug4ZeovvBPr6vAJSxWw',
    },
  );

  try {
    final response = await http.get(
      uri,
      headers: const {
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return [];

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return [];
    final resultsJson = decoded['results'];
    if (resultsJson is! List) return [];

    final List<Venue> results = [];
    for (final json in resultsJson) {
      if (json is! Map<String, dynamic>) continue;
      final geometry = json['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;
      final lat = double.tryParse(location?['lat']?.toString() ?? '') ?? 0.0;
      final lon = double.tryParse(location?['lng']?.toString() ?? '') ?? 0.0;

      final displayName = json['formatted_address']?.toString() ?? '';
      final name = json['name']?.toString() ?? '';
      final placeId = json['place_id']?.toString() ?? 'unknown';

      final types = json['types'] as List? ?? [];

      // Map Google Places types to our VenueCategory enum
      VenueCategory category = VenueCategory.custom;
      if (types.contains('cafe')) {
        category = VenueCategory.cafe;
      } else if (types.contains('restaurant') || types.contains('food')) {
        category = VenueCategory.restaurant;
      } else if (types.contains('library') || types.contains('book_store')) {
        category = VenueCategory.library;
      } else if (types.contains('lodging') || types.contains('hotel')) {
        category = VenueCategory.hotel;
      }

      final rating = double.tryParse(json['rating']?.toString() ?? '') ?? 4.0;
      final reviews = int.tryParse(json['user_ratings_total']?.toString() ?? '') ?? 50;

      // Get real image from Google Places Photo API
      String coverImg = 'https://images.unsplash.com/photo-1497366216548-37526070297c?w=500&auto=format&fit=crop&q=60';
      List<String> imageUrls = [coverImg];
      final rawPhotos = json['photos'];
      if (rawPhotos is List && rawPhotos.isNotEmpty) {
        final firstPhoto = rawPhotos[0];
        if (firstPhoto is Map) {
          final photoRef = firstPhoto['photo_reference']?.toString() ?? '';
          if (photoRef.isNotEmpty) {
            coverImg = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$photoRef&key=AIzaSyAXjzGoUZVyISPLug4ZeovvBPr6vAJSxWw';
          }
        }
        imageUrls = [];
        for (final p in rawPhotos) {
          if (p is Map) {
            final ref = p['photo_reference']?.toString() ?? '';
            if (ref.isNotEmpty) {
              imageUrls.add('https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$ref&key=AIzaSyAXjzGoUZVyISPLug4ZeovvBPr6vAJSxWw');
            }
          }
        }
        if (imageUrls.isEmpty) imageUrls.add(coverImg);
      }

      results.add(Venue(
        id: 'google_$placeId',
        providerId: placeId,
        provider: 'google',
        name: name,
        category: category,
        description: '$name is a verified location.',
        rating: rating,
        ratingCount: reviews,
        priceLevel: int.tryParse(json['price_level']?.toString() ?? '') ?? 2,
        formattedAddress: displayName,
        city: city ?? '',
        country: 'India',
        latitude: lat,
        longitude: lon,
        phone: '',
        website: '',
        openingHours: 'Open',
        isOpen: true,
        parkingAvailable: true,
        wifiAvailable: true,
        wheelchairAccessible: true,
        imageUrls: imageUrls,
        coverImage: coverImg,
        createdAt: DateTime.now(),
      ));
    }

    // Apply Filters if provided
    var filtered = results;
    if (filters != null) {
      if (filters['category'] != null) {
        final cat = VenueCategoryExtension.fromString(filters['category'].toString());
        filtered = filtered.where((v) => v.category == cat).toList();
      }
    }

    return filtered;
  } catch (_) {
    return [];
  }
}

Future<List<Map<String, dynamic>>> searchGoogleGeocoding(String query) async {
  try {
    final url = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(query)}&key=AIzaSyAXjzGoUZVyISPLug4ZeovvBPr6vAJSxWw');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'OK' && data['results'] != null) {
        final results = data['results'] as List;
        return results.map((item) {
          final loc = item['geometry']['location'];
          return {
            'display_name': item['formatted_address'] as String,
            'lat': loc['lat'] as double,
            'lon': loc['lng'] as double,
          };
        }).toList();
      }
    }
  } catch (_) {
    // Fail silently
  }
  return [];
}

Future<Map<String, String>?> reverseGeocodeAddress(double lat, double lng) async {
  try {
    final url = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=AIzaSyAXjzGoUZVyISPLug4ZeovvBPr6vAJSxWw');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'OK' && data['results'] != null) {
        final results = data['results'] as List;
        if (results.isNotEmpty) {
          final firstResult = results[0];
          final components = firstResult['address_components'] as List? ?? [];
          String city = '', state = '', country = '';
          for (final comp in components) {
            if (comp is Map) {
              final types = comp['types'] as List? ?? [];
              if (types.contains('locality')) {
                city = comp['long_name']?.toString() ?? '';
              } else if (types.contains('administrative_area_level_1')) {
                state = comp['long_name']?.toString() ?? '';
              } else if (types.contains('country')) {
                country = comp['long_name']?.toString() ?? '';
              }
            }
          }
          return {
            'city': city,
            'state': state,
            'country': country,
            'formatted_address': firstResult['formatted_address']?.toString() ?? '',
          };
        }
      }
    }
  } catch (_) {
    // Fail silently
  }
  return null;
}
