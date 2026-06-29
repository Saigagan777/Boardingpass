import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/enums.dart';
import '../models/venue.dart';

abstract class VenueRepository {
  Future<List<Venue>> searchVenues(String query, {String? city, Map<String, dynamic>? filters});
  Future<List<Venue>> getRecommendations({required String city, MeetingPurpose? purpose, VenueCategory? category});
  Future<Venue?> getVenueDetails(String venueId, String provider);
}

class VenueRepositoryImpl implements VenueRepository {
  static final VenueRepositoryImpl _instance = VenueRepositoryImpl._internal();
  factory VenueRepositoryImpl() => _instance;
  VenueRepositoryImpl._internal();

  final MockVenueProvider _mockProvider = MockVenueProvider();
  final OpenStreetMapProvider _osmProvider = OpenStreetMapProvider();

  // Settings to switch providers
  bool useMockProvider = true; 

  @override
  Future<List<Venue>> searchVenues(String query, {String? city, Map<String, dynamic>? filters}) async {
    if (useMockProvider) {
      return _mockProvider.searchVenues(query, city: city, filters: filters);
    }
    try {
      final results = await _osmProvider.searchVenues(query, city: city, filters: filters);
      if (results.isEmpty) {
        return _mockProvider.searchVenues(query, city: city, filters: filters);
      }
      return results;
    } catch (_) {
      // Fallback to mock on error
      return _mockProvider.searchVenues(query, city: city, filters: filters);
    }
  }

  @override
  Future<List<Venue>> getRecommendations({required String city, MeetingPurpose? purpose, VenueCategory? category}) async {
    return _mockProvider.getRecommendations(city: city, purpose: purpose, category: category);
  }

  @override
  Future<Venue?> getVenueDetails(String venueId, String provider) async {
    if (provider == 'mock') {
      return _mockProvider.getVenueDetails(venueId, provider);
    }
    return _osmProvider.getVenueDetails(venueId, provider);
  }
}

class MockVenueProvider implements VenueRepository {
  // Curated database of mock venues with 4.0+ rating
  final List<Venue> _curatedVenues = [
    // Vijayawada
    Venue(
      id: 'mock_vj_novotel',
      providerId: 'vj_novotel',
      provider: 'mock',
      name: 'Novotel Vijayawada Varun',
      category: VenueCategory.hotel,
      description: 'Premium 5-star hotel featuring modern meeting spaces, business lounges, and a rooftop bar overlooking the city skyline. Ideal for executive discussions and presentations.',
      rating: 4.6,
      ratingCount: 820,
      priceLevel: 4,
      formattedAddress: 'Near Benz Circle, Bharathi Nagar, Vijayawada, Andhra Pradesh 520008',
      city: 'Vijayawada',
      country: 'India',
      latitude: 16.5011,
      longitude: 80.6432,
      phone: '+91 866 668 3333',
      website: 'https://all.accor.com/hotel/B2R0/index.en.shtml',
      openingHours: 'Open 24 Hours',
      isOpen: true,
      parkingAvailable: true,
      wifiAvailable: true,
      wheelchairAccessible: true,
      imageUrls: [
        'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=500&auto=format&fit=crop&q=60',
        'https://images.unsplash.com/photo-1582719508461-905c673771fd?w=500&auto=format&fit=crop&q=60'
      ],
      coverImage: 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=500&auto=format&fit=crop&q=60',
      createdAt: DateTime.now(),
    ),
    Venue(
      id: 'mock_vj_gateway',
      providerId: 'vj_gateway',
      provider: 'mock',
      name: 'The Gateway Hotel M G Road',
      category: VenueCategory.hotel,
      description: 'High-end business hotel by Taj Group. Featuring elegant banquet rooms, quiet dining spots, and professional conference facilities perfect for candidate interviews and corporate meetings.',
      rating: 4.5,
      ratingCount: 650,
      priceLevel: 4,
      formattedAddress: '39-1-57 MG Road, Labbipet, Vijayawada, Andhra Pradesh 520010',
      city: 'Vijayawada',
      country: 'India',
      latitude: 16.5055,
      longitude: 80.6322,
      phone: '+91 866 664 4444',
      website: 'https://www.tajhotels.com',
      openingHours: 'Open 24 Hours',
      isOpen: true,
      parkingAvailable: true,
      wifiAvailable: true,
      wheelchairAccessible: true,
      imageUrls: [
        'https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?w=500&auto=format&fit=crop&q=60',
        'https://images.unsplash.com/photo-1445019980597-93fa8acb246c?w=500&auto=format&fit=crop&q=60'
      ],
      coverImage: 'https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?w=500&auto=format&fit=crop&q=60',
      createdAt: DateTime.now(),
    ),
    Venue(
      id: 'mock_vj_dvmanor',
      providerId: 'vj_dvmanor',
      provider: 'mock',
      name: 'Hotel DV Manor',
      category: VenueCategory.hotel,
      description: 'Iconic upscale business hotel in Vijayawada offering a quiet, sophisticated environment for business lunches, coffee chats, and contract signings.',
      rating: 4.3,
      ratingCount: 520,
      priceLevel: 3,
      formattedAddress: 'MG Road, Labbipet, Vijayawada, Andhra Pradesh 520010',
      city: 'Vijayawada',
      country: 'India',
      latitude: 16.5062,
      longitude: 80.6341,
      phone: '+91 866 247 4444',
      website: 'http://www.hoteldvmanor.com',
      openingHours: 'Open 24 Hours',
      isOpen: true,
      parkingAvailable: true,
      wifiAvailable: true,
      wheelchairAccessible: true,
      imageUrls: [
        'https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=500&auto=format&fit=crop&q=60'
      ],
      coverImage: 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=500&auto=format&fit=crop&q=60',
      createdAt: DateTime.now(),
    ),
    Venue(
      id: 'mock_vj_temptations',
      providerId: 'vj_temptations',
      provider: 'mock',
      name: 'Temptations Restaurant',
      category: VenueCategory.restaurant,
      description: 'Acclaimed multi-cuisine restaurant known for authentic Andhra specialities, delicious biryanis, and comfortable group seating. Great for informal team lunches.',
      rating: 4.4,
      ratingCount: 420,
      priceLevel: 2,
      formattedAddress: 'Tickle Road, Labbipet, Vijayawada, Andhra Pradesh 520010',
      city: 'Vijayawada',
      country: 'India',
      latitude: 16.5081,
      longitude: 80.6355,
      phone: '+91 866 249 9999',
      website: 'https://temptationsvijayawada.com',
      openingHours: '11:00 AM - 11:00 PM',
      isOpen: true,
      parkingAvailable: true,
      wifiAvailable: false,
      wheelchairAccessible: true,
      imageUrls: [
        'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&auto=format&fit=crop&q=60'
      ],
      coverImage: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&auto=format&fit=crop&q=60',
      createdAt: DateTime.now(),
    ),
    Venue(
      id: 'mock_vj_crossroads',
      providerId: 'vj_crossroads',
      provider: 'mock',
      name: 'Crossroads Buffet & Restaurant',
      category: VenueCategory.restaurant,
      description: 'Modern, highly rated restaurant serving extensive global buffet options. Vibrant and spacious, perfect for networking events or team celebratory dinners.',
      rating: 4.2,
      ratingCount: 310,
      priceLevel: 2,
      formattedAddress: 'Moghalrajpuram, Vijayawada, Andhra Pradesh 520010',
      city: 'Vijayawada',
      country: 'India',
      latitude: 16.5068,
      longitude: 80.6421,
      phone: '+91 866 248 1111',
      website: 'http://crossroadsrestaurant.in',
      openingHours: '12:00 PM - 10:30 PM',
      isOpen: true,
      parkingAvailable: true,
      wifiAvailable: true,
      wheelchairAccessible: false,
      imageUrls: [
        'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=500&auto=format&fit=crop&q=60'
      ],
      coverImage: 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=500&auto=format&fit=crop&q=60',
      createdAt: DateTime.now(),
    ),
    Venue(
      id: 'mock_vj_sweetmagic',
      providerId: 'vj_sweetmagic',
      provider: 'mock',
      name: 'Sweet Magic Coffee Shop',
      category: VenueCategory.cafe,
      description: 'Lively cafe and restaurant serving legendary South Indian breakfasts, traditional sweets, coffees, and mocktails. Excellent for casual networking or quick chats.',
      rating: 4.3,
      ratingCount: 950,
      priceLevel: 2,
      formattedAddress: 'Benz Circle, Vijayawada, Andhra Pradesh 520008',
      city: 'Vijayawada',
      country: 'India',
      latitude: 16.5005,
      longitude: 80.6444,
      phone: '+91 866 666 5555',
      website: 'https://sweetmagic.in',
      openingHours: '07:00 AM - 10:30 PM',
      isOpen: true,
      parkingAvailable: true,
      wifiAvailable: true,
      wheelchairAccessible: true,
      imageUrls: [
        'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=500&auto=format&fit=crop&q=60'
      ],
      coverImage: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=500&auto=format&fit=crop&q=60',
      createdAt: DateTime.now(),
    ),

    // Hyderabad
    Venue(
      id: 'mock_hyd_tajkrishna',
      providerId: 'hyd_tajkrishna',
      provider: 'mock',
      name: 'Taj Krishna Hyderabad',
      category: VenueCategory.hotel,
      description: 'Luxury hotel located in Banjara Hills. Set in manicured gardens, featuring extensive business facilities and private dining for VIP client meetings.',
      rating: 4.7,
      ratingCount: 1200,
      priceLevel: 4,
      formattedAddress: 'Road No. 1, Banjara Hills, Hyderabad, Telangana 500034',
      city: 'Hyderabad',
      country: 'India',
      latitude: 17.4162,
      longitude: 78.4501,
      phone: '+91 40 6666 2323',
      website: 'https://www.tajhotels.com/en-in/taj/taj-krishna-hyderabad',
      openingHours: 'Open 24 Hours',
      isOpen: true,
      parkingAvailable: true,
      wifiAvailable: true,
      wheelchairAccessible: true,
      imageUrls: ['https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=500&auto=format&fit=crop&q=60'],
      coverImage: 'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=500&auto=format&fit=crop&q=60',
      createdAt: DateTime.now(),
    ),
    Venue(
      id: 'mock_hyd_roastery',
      providerId: 'hyd_roastery',
      provider: 'mock',
      name: 'Roastery Coffee House',
      category: VenueCategory.cafe,
      description: 'Beautiful bungalow cafe serving artisanal coffee and delicious bites. A quiet, green garden setup perfect for professional coffee chats and brainstorming.',
      rating: 4.6,
      ratingCount: 1800,
      priceLevel: 2,
      formattedAddress: 'Road No. 14, Banjara Hills, Hyderabad, Telangana 500034',
      city: 'Hyderabad',
      country: 'India',
      latitude: 17.4188,
      longitude: 78.4395,
      phone: '+91 40 2335 1515',
      website: 'http://roasterycoffeehouse.com',
      openingHours: '08:00 AM - 11:00 PM',
      isOpen: true,
      parkingAvailable: true,
      wifiAvailable: true,
      wheelchairAccessible: true,
      imageUrls: ['https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=500&auto=format&fit=crop&q=60'],
      coverImage: 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=500&auto=format&fit=crop&q=60',
      createdAt: DateTime.now(),
    ),

    // Bengaluru
    Venue(
      id: 'mock_blr_leela',
      providerId: 'blr_leela',
      provider: 'mock',
      name: 'The Leela Palace Bengaluru',
      category: VenueCategory.hotel,
      description: 'Palatial luxury hotel with award-winning dining options. Standard for elite business client conferences and upscale private client briefings.',
      rating: 4.8,
      ratingCount: 1500,
      priceLevel: 4,
      formattedAddress: '23, HAL Old Airport Road, Kodihalli, Bengaluru, Karnataka 560008',
      city: 'Bengaluru',
      country: 'India',
      latitude: 12.9606,
      longitude: 77.6484,
      phone: '+91 80 2521 1234',
      website: 'https://www.theleela.com/the-leela-palace-bengaluru',
      openingHours: 'Open 24 Hours',
      isOpen: true,
      parkingAvailable: true,
      wifiAvailable: true,
      wheelchairAccessible: true,
      imageUrls: ['https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=500&auto=format&fit=crop&q=60'],
      coverImage: 'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=500&auto=format&fit=crop&q=60',
      createdAt: DateTime.now(),
    ),
    Venue(
      id: 'mock_blr_thirdwave',
      providerId: 'blr_thirdwave',
      provider: 'mock',
      name: 'Third Wave Coffee Koramangala',
      category: VenueCategory.cafe,
      description: 'Trendy, popular coffee chain offering fast WiFi, work-friendly plug points, and freshly roasted coffee. Perfect for networking and developer discussions.',
      rating: 4.4,
      ratingCount: 880,
      priceLevel: 2,
      formattedAddress: '80 Feet Road, 4th Block, Koramangala, Bengaluru, Karnataka 560034',
      city: 'Bengaluru',
      country: 'India',
      latitude: 12.9341,
      longitude: 77.6229,
      phone: '+91 80 4991 2345',
      website: 'https://www.thirdwavecoffeeroasters.com',
      openingHours: '08:00 AM - 11:30 PM',
      isOpen: true,
      parkingAvailable: false,
      wifiAvailable: true,
      wheelchairAccessible: true,
      imageUrls: ['https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=500&auto=format&fit=crop&q=60'],
      coverImage: 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=500&auto=format&fit=crop&q=60',
      createdAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<Venue>> searchVenues(String query, {String? city, Map<String, dynamic>? filters}) async {
    final lowerQuery = query.toLowerCase();
    final lowerCity = city?.toLowerCase();

    // Check curated first
    var filtered = _curatedVenues.where((v) {
      final matchesQuery = v.name.toLowerCase().contains(lowerQuery) ||
          v.formattedAddress.toLowerCase().contains(lowerQuery) ||
          v.category.name.toLowerCase().contains(lowerQuery);
      final matchesCity = lowerCity == null || v.city.toLowerCase() == lowerCity;
      return matchesQuery && matchesCity;
    }).toList();

    // Apply Filters if provided
    if (filters != null) {
      if (filters['category'] != null) {
        final cat = VenueCategoryExtension.fromString(filters['category'].toString());
        filtered = filtered.where((v) => v.category == cat).toList();
      }
      if (filters['minRating'] != null) {
        final minRating = double.tryParse(filters['minRating'].toString()) ?? 0.0;
        filtered = filtered.where((v) => v.rating >= minRating).toList();
      }
      if (filters['wifi'] == true) {
        filtered = filtered.where((v) => v.wifiAvailable).toList();
      }
      if (filters['parking'] == true) {
        filtered = filtered.where((v) => v.parkingAvailable).toList();
      }
      if (filters['accessible'] == true) {
        filtered = filtered.where((v) => v.wheelchairAccessible).toList();
      }
    }

    if (filtered.isNotEmpty || query.trim().length < 3) return filtered;

    // Generate dynamic mock recommendations for any other searched query
    final targetCity = city ?? (query.contains(',') ? query.split(',').first : query);
    return _generateMockVenuesForCity(targetCity);
  }

  @override
  Future<List<Venue>> getRecommendations({required String city, MeetingPurpose? purpose, VenueCategory? category}) async {
    final targetCity = city.trim();
    var cityVenues = _curatedVenues.where((v) => v.city.toLowerCase() == targetCity.toLowerCase()).toList();

    if (cityVenues.isEmpty) {
      cityVenues = _generateMockVenuesForCity(targetCity);
    }

    if (category != null) {
      cityVenues = cityVenues.where((v) => v.category == category).toList();
    } else if (purpose != null) {
      // Intelligently filter categories based on meeting purpose
      switch (purpose) {
        case MeetingPurpose.interview:
        case MeetingPurpose.presentation:
          cityVenues = cityVenues.where((v) => v.category == VenueCategory.conferenceRoom || v.category == VenueCategory.hotel || v.category == VenueCategory.businessCenter).toList();
          break;
        case MeetingPurpose.coffeeChat:
        case MeetingPurpose.networking:
          cityVenues = cityVenues.where((v) => v.category == VenueCategory.cafe || v.category == VenueCategory.coworking || v.category == VenueCategory.hotel).toList();
          break;
        case MeetingPurpose.clientMeeting:
          cityVenues = cityVenues.where((v) => v.category == VenueCategory.hotel || v.category == VenueCategory.airportLounge || v.category == VenueCategory.restaurant).toList();
          break;
        case MeetingPurpose.teamLunch:
          cityVenues = cityVenues.where((v) => v.category == VenueCategory.restaurant).toList();
          break;
        default:
          break;
      }
    }

    // Rank by rating (high to low)
    cityVenues.sort((a, b) => b.rating.compareTo(a.rating));
    return cityVenues;
  }

  @override
  Future<Venue?> getVenueDetails(String venueId, String provider) async {
    try {
      return _curatedVenues.firstWhere((v) => v.id == venueId);
    } catch (_) {
      // Search in dynamically generated templates
      return null;
    }
  }

  List<Venue> _generateMockVenuesForCity(String city) {
    final cleanCity = city.trim();
    if (cleanCity.isEmpty) return [];

    // Determinstic ratings based on length and characters to keep it consistent
    double ratingForName(String name) {
      final code = name.length + (name.isNotEmpty ? name.codeUnitAt(0) : 0);
      return 4.0 + ((code % 9) / 10.0); // yields 4.0 to 4.8
    }

    int countForName(String name) {
      return 100 + (name.length * 15);
    }

    return [
      Venue(
        id: 'mock_${cleanCity.toLowerCase()}_grandhotel',
        providerId: '${cleanCity.toLowerCase()}_grandhotel',
        provider: 'mock',
        name: 'The Grand $cleanCity Hotel',
        category: VenueCategory.hotel,
        description: 'Exquisite luxury hotel and business conference center located in prime area. Offers quiet meeting spaces, fast WiFi, and multi-cuisine restaurant.',
        rating: ratingForName('Grand Hotel $cleanCity'),
        ratingCount: countForName('Grand Hotel $cleanCity'),
        priceLevel: 4,
        formattedAddress: 'Main Business District Road, $cleanCity',
        city: cleanCity,
        country: 'India',
        latitude: 17.0, // fallback coordinates
        longitude: 79.0,
        phone: '+91 800 123 4567',
        website: 'https://grandhotel${cleanCity.toLowerCase()}.com',
        openingHours: 'Open 24 Hours',
        isOpen: true,
        parkingAvailable: true,
        wifiAvailable: true,
        wheelchairAccessible: true,
        imageUrls: ['https://images.unsplash.com/photo-1566073771259-6a8506099945?w=500&auto=format&fit=crop&q=60'],
        coverImage: 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=500&auto=format&fit=crop&q=60',
        createdAt: DateTime.now(),
      ),
      Venue(
        id: 'mock_${cleanCity.toLowerCase()}_centralbistro',
        providerId: '${cleanCity.toLowerCase()}_centralbistro',
        provider: 'mock',
        name: '$cleanCity Central Bistro',
        category: VenueCategory.restaurant,
        description: 'Cozy and spacious fine-dining restaurant featuring private seating sections and outstanding continental cuisines. Highly recommended for business lunches and team celebrations.',
        rating: ratingForName('Central Bistro $cleanCity'),
        ratingCount: countForName('Central Bistro $cleanCity'),
        priceLevel: 3,
        formattedAddress: 'Gourmet Street, Near High Street Circle, $cleanCity',
        city: cleanCity,
        country: 'India',
        latitude: 17.01,
        longitude: 79.02,
        phone: '+91 800 234 5678',
        website: 'https://centralbistro${cleanCity.toLowerCase()}.com',
        openingHours: '11:00 AM - 11:00 PM',
        isOpen: true,
        parkingAvailable: true,
        wifiAvailable: true,
        wheelchairAccessible: true,
        imageUrls: ['https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&auto=format&fit=crop&q=60'],
        coverImage: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&auto=format&fit=crop&q=60',
        createdAt: DateTime.now(),
      ),
      Venue(
        id: 'mock_${cleanCity.toLowerCase()}_brewbean',
        providerId: '${cleanCity.toLowerCase()}_brewbean',
        provider: 'mock',
        name: 'Brew & Bean Cafe ($cleanCity)',
        category: VenueCategory.cafe,
        description: 'Lively neighborhood cafe serving artisanal single-origin coffee and freshly baked pastries. Features quiet workspace desks and outdoor garden seats.',
        rating: ratingForName('Brew Bean $cleanCity'),
        ratingCount: countForName('Brew Bean $cleanCity'),
        priceLevel: 2,
        formattedAddress: 'Woodlands Road, Sector 3, $cleanCity',
        city: cleanCity,
        country: 'India',
        latitude: 16.99,
        longitude: 78.98,
        phone: '+91 800 345 6789',
        website: 'https://brewbean${cleanCity.toLowerCase()}.com',
        openingHours: '08:00 AM - 10:00 PM',
        isOpen: true,
        parkingAvailable: false,
        wifiAvailable: true,
        wheelchairAccessible: true,
        imageUrls: ['https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=500&auto=format&fit=crop&q=60'],
        coverImage: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=500&auto=format&fit=crop&q=60',
        createdAt: DateTime.now(),
      ),
      Venue(
        id: 'mock_${cleanCity.toLowerCase()}_hubcoworking',
        providerId: '${cleanCity.toLowerCase()}_hubcoworking',
        provider: 'mock',
        name: 'The Hub Coworking & Lounge',
        category: VenueCategory.coworking,
        description: 'Premium modern coworking space equipped with hot desks, meeting rooms, high-speed fiber internet, and professional projector systems.',
        rating: ratingForName('Hub Coworking $cleanCity'),
        ratingCount: countForName('Hub Coworking $cleanCity'),
        priceLevel: 2,
        formattedAddress: 'IT Tech Park, Building A, $cleanCity',
        city: cleanCity,
        country: 'India',
        latitude: 17.02,
        longitude: 79.05,
        phone: '+91 800 456 7890',
        website: 'https://hubcoworking${cleanCity.toLowerCase()}.com',
        openingHours: '09:00 AM - 08:00 PM',
        isOpen: true,
        parkingAvailable: true,
        wifiAvailable: true,
        wheelchairAccessible: true,
        imageUrls: ['https://images.unsplash.com/photo-1497366216548-37526070297c?w=500&auto=format&fit=crop&q=60'],
        coverImage: 'https://images.unsplash.com/photo-1497366216548-37526070297c?w=500&auto=format&fit=crop&q=60',
        createdAt: DateTime.now(),
      ),
    ];
  }
}

class OpenStreetMapProvider implements VenueRepository {
  @override
  Future<List<Venue>> searchVenues(String query, {String? city, Map<String, dynamic>? filters}) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 3) return [];

    final searchString = city != null ? '$trimmedQuery, $city' : trimmedQuery;

    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      {
        'q': searchString,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '10',
      },
    );

    try {
      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'BoardingPause/1.0 contact@boardingpause.app',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return [];

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return [];

      final List<Venue> results = [];
      for (final json in decoded) {
        if (json is! Map<String, dynamic>) continue;
        final lat = double.tryParse(json['lat']?.toString() ?? '') ?? 0.0;
        final lon = double.tryParse(json['lon']?.toString() ?? '') ?? 0.0;
        if (lat == 0.0 || lon == 0.0) continue;

        final addressDetails = json['address'] as Map<String, dynamic>? ?? {};
        final displayName = json['display_name']?.toString() ?? '';
        final name = json['name']?.toString() ?? displayName.split(',').first;
        final parsedCity = addressDetails['city']?.toString() ??
            addressDetails['town']?.toString() ??
            addressDetails['village']?.toString() ??
            '';
        final parsedCountry = addressDetails['country']?.toString() ?? '';

        final type = json['type']?.toString() ?? '';
        final categoryStr = json['category']?.toString() ?? '';

        // Map OSM categories to our VenueCategory enum
        VenueCategory category = VenueCategory.custom;
        if (categoryStr == 'amenity') {
          if (type == 'restaurant') {
            category = VenueCategory.restaurant;
          } else if (type == 'cafe') {
            category = VenueCategory.cafe;
          } else if (type == 'library') {
            category = VenueCategory.library;
          }
        } else if (categoryStr == 'tourism' && type == 'hotel') {
          category = VenueCategory.hotel;
        }

        // Generate consistent rating based on place ID
        final placeId = json['place_id']?.toString() ?? '1';
        final placeIdInt = int.tryParse(placeId) ?? 123;
        final rating = 4.0 + ((placeIdInt % 9) / 10.0);
        final reviews = 50 + (placeIdInt % 250);

        results.add(Venue(
          id: 'osm_$placeId',
          providerId: placeId,
          provider: 'osm',
          name: name,
          category: category,
          description: '$name is a verified location in $parsedCity. Category details: $type.',
          rating: rating,
          ratingCount: reviews,
          priceLevel: 2,
          formattedAddress: displayName,
          city: parsedCity,
          country: parsedCountry,
          latitude: lat,
          longitude: lon,
          phone: '',
          website: '',
          openingHours: 'Contact venue directly',
          isOpen: true,
          parkingAvailable: true,
          wifiAvailable: true,
          wheelchairAccessible: true,
          imageUrls: ['https://images.unsplash.com/photo-1497366216548-37526070297c?w=500&auto=format&fit=crop&q=60'],
          coverImage: 'https://images.unsplash.com/photo-1497366216548-37526070297c?w=500&auto=format&fit=crop&q=60',
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

  @override
  Future<List<Venue>> getRecommendations({required String city, MeetingPurpose? purpose, VenueCategory? category}) async {
    // OSM does not natively support complex recommendation sorting, fallback to mock data recommendations
    return [];
  }

  @override
  Future<Venue?> getVenueDetails(String venueId, String provider) async {
    return null;
  }
}
