import '../models/enums.dart';
import '../models/venue.dart';
import '../utils/google_search_helper.dart';

abstract class VenueRepository {
  Future<List<Venue>> searchVenues(String query, {String? city, Map<String, dynamic>? filters});
  Future<List<Venue>> getRecommendations({required String city, MeetingPurpose? purpose, VenueCategory? category});
  Future<Venue?> getVenueDetails(String venueId, String provider);
}

class VenueRepositoryImpl implements VenueRepository {
  static final VenueRepositoryImpl _instance = VenueRepositoryImpl._internal();
  factory VenueRepositoryImpl() => _instance;
  VenueRepositoryImpl._internal();

  final GooglePlacesProvider _googleProvider = GooglePlacesProvider();

  @override
  Future<List<Venue>> searchVenues(String query, {String? city, Map<String, dynamic>? filters}) async {
    try {
      return await _googleProvider.searchVenues(query, city: city, filters: filters);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Venue>> getRecommendations({required String city, MeetingPurpose? purpose, VenueCategory? category}) async {
    return [];
  }

  @override
  Future<Venue?> getVenueDetails(String venueId, String provider) async {
    return _googleProvider.getVenueDetails(venueId, provider);
  }
}
class GooglePlacesProvider implements VenueRepository {
  @override
  Future<List<Venue>> searchVenues(String query, {String? city, Map<String, dynamic>? filters}) async {
    return searchGooglePlaces(query, city: city, filters: filters);
  }

  @override
  Future<List<Venue>> getRecommendations({required String city, MeetingPurpose? purpose, VenueCategory? category}) async {
    return [];
  }

  @override
  Future<Venue?> getVenueDetails(String venueId, String provider) async {
    return null;
  }
}
