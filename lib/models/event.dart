class Event {
  final String id;
  final String illustrationPath;
  final String month;
  final String day;
  final String title;
  final String location;
  final String time;
  final String attendees;
  final String category;
  final String price;
  final String? mapUrl;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  bool isJoined;

  Event({
    required this.id,
    required this.illustrationPath,
    required this.month,
    required this.day,
    required this.title,
    required this.location,
    required this.time,
    required this.attendees,
    this.category = 'Meetups',
    this.price = 'Free',
    this.mapUrl,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.isJoined = false,
  });
}
