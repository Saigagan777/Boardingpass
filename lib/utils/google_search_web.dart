import 'dart:convert';
// ignore: uri_does_not_exist, avoid_web_libraries_in_flutter
import 'dart:js_util' as js_util;
import '../models/venue.dart';
import '../models/enums.dart';

Future<List<Venue>> searchGooglePlaces(String query, {String? city, Map<String, dynamic>? filters}) async {
  try {
    // Perform global search without appending the city restriction
    final promise = js_util.callMethod(js_util.globalThis, 'googlePlacesSearch', [query]);
    final jsonResult = await js_util.promiseToFuture<String>(promise);

    final resultsJson = jsonDecode(jsonResult);
    if (resultsJson is! List) return [];

    final List<Venue> results = [];
    for (final rawJson in resultsJson) {
      if (rawJson is! Map) continue;
      final json = Map<String, dynamic>.from(rawJson);

      final name = json['name']?.toString() ?? '';
      if (name.isEmpty) continue;

      final displayName = json['formatted_address']?.toString() ?? '';
      final placeId = json['place_id']?.toString() ?? 'unknown_${results.length}';

      final rawGeometry = json['geometry'];
      final geometry = rawGeometry is Map ? Map<String, dynamic>.from(rawGeometry) : null;
      final rawLocation = geometry?['location'];
      final location = rawLocation is Map ? Map<String, dynamic>.from(rawLocation) : null;
      final lat = double.tryParse(location?['lat']?.toString() ?? '') ?? 0.0;
      final lon = double.tryParse(location?['lng']?.toString() ?? '') ?? 0.0;

      final rawTypes = json['types'];
      final types = rawTypes is List ? rawTypes : <dynamic>[];

      VenueCategory category = VenueCategory.custom;
      if (types.contains('cafe') || types.contains('coffee_shop')) {
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

      final coverImg = json['cover_image']?.toString() ?? 'https://images.unsplash.com/photo-1497366216548-37526070297c?w=500&auto=format&fit=crop&q=60';
      final rawImageUrls = json['image_urls'];
      final imageUrls = rawImageUrls is List
          ? rawImageUrls.map((e) => e.toString()).toList()
          : [coverImg];

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
        formattedAddress: displayName.isNotEmpty ? displayName : name,
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

    var filtered = results;
    if (filters != null) {
      if (filters['category'] != null) {
        final cat = VenueCategoryExtension.fromString(filters['category'].toString());
        filtered = filtered.where((v) => v.category == cat).toList();
      }
    }
    return filtered;
  } catch (e) {
    return [];
  }
}

Future<List<Map<String, dynamic>>> searchGoogleGeocoding(String query) async {
  try {
    final promise = js_util.callMethod(js_util.globalThis, 'googleGeocode', [query]);
    final jsonResult = await js_util.promiseToFuture<String>(promise);
    final resultsJson = jsonDecode(jsonResult);
    if (resultsJson is! List) return [];

    final List<Map<String, dynamic>> output = [];
    for (final rawItem in resultsJson) {
      if (rawItem is! Map) continue;
      final item = Map<String, dynamic>.from(rawItem);
      final rawGeom = item['geometry'];
      if (rawGeom is! Map) continue;
      final geom = Map<String, dynamic>.from(rawGeom);
      final rawLoc = geom['location'];
      if (rawLoc is! Map) continue;
      final loc = Map<String, dynamic>.from(rawLoc);
      output.add({
        'display_name': item['formatted_address']?.toString() ?? '',
        'lat': double.tryParse(loc['lat']?.toString() ?? '') ?? 0.0,
        'lon': double.tryParse(loc['lng']?.toString() ?? '') ?? 0.0,
      });
    }
    return output;
  } catch (e) {
    return [];
  }
}

Future<Map<String, String>?> reverseGeocodeAddress(double lat, double lng) async {
  try {
    final promise = js_util.callMethod(js_util.globalThis, 'googleReverseGeocode', [lat, lng]);
    final jsonResult = await js_util.promiseToFuture<String>(promise);
    final decoded = jsonDecode(jsonResult);
    if (decoded is Map) {
      return {
        'city': decoded['city']?.toString() ?? '',
        'state': decoded['state']?.toString() ?? '',
        'country': decoded['country']?.toString() ?? '',
        'formatted_address': decoded['formatted_address']?.toString() ?? '',
      };
    }
    return null;
  } catch (e) {
    return null;
  }
}
