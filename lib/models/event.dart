class Event {
  final String id;
  final String illustrationPath;
  final String month;
  final String day;
  final String title;
  final String location;
  final String time;
  final String attendees;
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
    this.isJoined = false,
  });
}
