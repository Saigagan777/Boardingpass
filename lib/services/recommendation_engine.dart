import '../models/enums.dart';
import '../models/venue.dart';
import 'venue_repository.dart';
import 'user_service.dart';

class MeetingCityResult {
  final bool sameCity;
  final String primaryCity;
  final List<String> cityOptions;

  const MeetingCityResult({
    required this.sameCity,
    required this.primaryCity,
    required this.cityOptions,
  });
}

class RecommendationEngine {
  static final RecommendationEngine _instance = RecommendationEngine._internal();
  factory RecommendationEngine() => _instance;
  RecommendationEngine._internal();

  final VenueRepository _venueRepository = VenueRepositoryImpl();

  /// Automatically detects same-city or multi-city options based on profile homeBases
  Future<MeetingCityResult> detectMeetingCity(List<String> participantIds) async {
    final List<String> cities = [];
    String hostCity = ''; // Default fallback

    for (int i = 0; i < participantIds.length; i++) {
      final profile = await UserService().getUserProfile(participantIds[i]);
      if (profile != null) {
        // Use homeBase first, then currentLocationName
        final city = profile.homeBase ?? profile.currentLocationName;
        if (city != null && city.trim().isNotEmpty) {
          cities.add(city.trim());
          if (i == 0) {
            hostCity = city.trim(); // The host is always the first item in allParticipants list
          }
        }
      }
    }

    if (cities.isEmpty) {
      return MeetingCityResult(
        sameCity: true,
        primaryCity: '',
        cityOptions: const [],
      );
    }

    final uniqueCities = cities.toSet().toList();

    if (uniqueCities.length == 1) {
      return MeetingCityResult(
        sameCity: true,
        primaryCity: uniqueCities.first,
        cityOptions: [uniqueCities.first],
      );
    }

    // Participants in different cities
    return MeetingCityResult(
      sameCity: false,
      primaryCity: hostCity,
      cityOptions: [
        ...uniqueCities,
        'Midpoint (Virtual)',
      ],
    );
  }

  /// Recommends venues (4.0+) in a city filtered by purpose
  Future<List<Venue>> getPurposeRecommendations({
    required String city,
    required MeetingPurpose purpose,
  }) async {
    return _venueRepository.getRecommendations(
      city: city,
      purpose: purpose,
    );
  }
}
