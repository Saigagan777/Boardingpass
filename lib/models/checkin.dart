enum CheckinType { event, airport, hotel }

class Checkin {
  final String id;
  final CheckinType type;
  final String name;
  final String location;
  final String? link;
  final String checkinDate;
  final String checkinTime;
  final String checkoutDate;
  final String checkoutTime;

  const Checkin({
    required this.id,
    required this.type,
    required this.name,
    required this.location,
    this.link,
    required this.checkinDate,
    required this.checkinTime,
    required this.checkoutDate,
    required this.checkoutTime,
  });
}
