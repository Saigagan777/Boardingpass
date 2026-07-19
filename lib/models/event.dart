class Event {
  final String id;
  final String illustrationPath;
  final String month;
  final String day;
  final String title;
  final String location;
  final String time;
  final String attendees;
  final List<String> attendeeIds;
  final String category;
  final String price;
  final String? mapUrl;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  /// Firebase uid of the event host / organiser.
  final String? organiserId;
  bool isJoined;
  /// True when the current user has a ticket registration for this event.
  bool isRegistered;
  /// Registration document id when [isRegistered] is true.
  String? registrationId;

  Event({
    required this.id,
    required this.illustrationPath,
    required this.month,
    required this.day,
    required this.title,
    required this.location,
    required this.time,
    required this.attendees,
    this.attendeeIds = const [],
    this.category = 'Meetups',
    this.price = 'Free',
    this.mapUrl,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.organiserId,
    this.isJoined = false,
    this.isRegistered = false,
    this.registrationId,
  });

  bool isHostedBy(String? uid) =>
      uid != null && organiserId != null && organiserId == uid;
}
