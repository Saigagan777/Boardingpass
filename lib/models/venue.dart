import 'enums.dart';

class Venue {
  final String id;
  final String providerId;
  final String provider; // 'mock' | 'osm' | 'google'
  final String name;
  final VenueCategory category;
  final String description;
  final double rating;
  final int ratingCount;
  final int priceLevel; // 1 to 4
  final String formattedAddress;
  final String city;
  final String country;
  final double latitude;
  final double longitude;
  final double? distance; // in km
  final String? estimatedTravelTime; // e.g. "15 mins"
  final String phone;
  final String website;
  final String openingHours;
  final bool isOpen;
  final bool parkingAvailable;
  final bool wifiAvailable;
  final bool wheelchairAccessible;
  final List<String> imageUrls;
  final String coverImage;
  final DateTime createdAt;

  const Venue({
    required this.id,
    required this.providerId,
    required this.provider,
    required this.name,
    required this.category,
    required this.description,
    required this.rating,
    required this.ratingCount,
    required this.priceLevel,
    required this.formattedAddress,
    required this.city,
    required this.country,
    required this.latitude,
    required this.longitude,
    this.distance,
    this.estimatedTravelTime,
    required this.phone,
    required this.website,
    required this.openingHours,
    required this.isOpen,
    required this.parkingAvailable,
    required this.wifiAvailable,
    required this.wheelchairAccessible,
    required this.imageUrls,
    required this.coverImage,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'providerId': providerId,
      'provider': provider,
      'name': name,
      'category': category.name,
      'description': description,
      'rating': rating,
      'ratingCount': ratingCount,
      'priceLevel': priceLevel,
      'formattedAddress': formattedAddress,
      'city': city,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      if (distance != null) 'distance': distance,
      if (estimatedTravelTime != null) 'estimatedTravelTime': estimatedTravelTime,
      'phone': phone,
      'website': website,
      'openingHours': openingHours,
      'isOpen': isOpen,
      'parkingAvailable': parkingAvailable,
      'wifiAvailable': wifiAvailable,
      'wheelchairAccessible': wheelchairAccessible,
      'imageUrls': imageUrls,
      'coverImage': coverImage,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Venue.fromMap(Map<String, dynamic> map) {
    double parsedDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    int parsedInt(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? 0;
    }

    bool parsedBool(dynamic val) {
      if (val == null) return false;
      if (val is bool) return val;
      return val.toString().toLowerCase() == 'true';
    }

    final rawImages = map['imageUrls'];
    final List<String> parsedImages = rawImages is List
        ? List<String>.from(rawImages.map((e) => e.toString()))
        : [];

    return Venue(
      id: map['id']?.toString() ?? '',
      providerId: map['providerId']?.toString() ?? '',
      provider: map['provider']?.toString() ?? 'mock',
      name: map['name']?.toString() ?? '',
      category: VenueCategoryExtension.fromString(map['category']?.toString() ?? 'custom'),
      description: map['description']?.toString() ?? '',
      rating: parsedDouble(map['rating']),
      ratingCount: parsedInt(map['ratingCount']),
      priceLevel: parsedInt(map['priceLevel']),
      formattedAddress: map['formattedAddress']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      country: map['country']?.toString() ?? '',
      latitude: parsedDouble(map['latitude']),
      longitude: parsedDouble(map['longitude']),
      distance: map['distance'] != null ? parsedDouble(map['distance']) : null,
      estimatedTravelTime: map['estimatedTravelTime']?.toString(),
      phone: map['phone']?.toString() ?? '',
      website: map['website']?.toString() ?? '',
      openingHours: map['openingHours']?.toString() ?? '',
      isOpen: parsedBool(map['isOpen']),
      parkingAvailable: parsedBool(map['parkingAvailable']),
      wifiAvailable: parsedBool(map['wifiAvailable']),
      wheelchairAccessible: parsedBool(map['wheelchairAccessible']),
      imageUrls: parsedImages,
      coverImage: map['coverImage']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
