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
  /// True when the event was created by an admin.
  final bool createdByAdmin;

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
    this.createdByAdmin = false,
  });

  bool isHostedBy(String? uid) =>
      uid != null && organiserId != null && organiserId == uid;

  /// Parsed DateTime for the event (assuming year 2026 if not specified).
  DateTime? get eventDateTime {
    final d = int.tryParse(day.trim());
    if (d == null) return null;

    const monthMap = {
      'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
      'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
      'JANUARY': 1, 'FEBRUARY': 2, 'MARCH': 3, 'APRIL': 4,
      'JUNE': 6, 'JULY': 7, 'AUGUST': 8, 'SEPTEMBER': 9,
      'OCTOBER': 10, 'NOVEMBER': 11, 'DECEMBER': 12,
    };
    final cleanMonth = month.trim().toUpperCase();
    final m = monthMap[cleanMonth] ?? int.tryParse(cleanMonth);
    if (m == null) return null;

    return DateTime(2026, m, d);
  }

  /// Whether this event has expired relative to current date.
  bool get isExpired {
    final date = eventDateTime;
    if (date == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return date.isBefore(today);
  }

  /// Day of week string (e.g. Mon, Tue, Sat) calculated accurately based on DateTime.
  String get dayOfWeek {
    final date = eventDateTime;
    if (date == null) return 'Sat';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  /// Returns clean time without hardcoded relative suffixes.
  String get cleanTime {
    return time.split('•').first.trim();
  }

  /// Calculates dynamic relative date text: 'Today', 'Tomorrow', 'Expired', 'In X days'.
  String get relativeDateText {
    final date = eventDateTime;
    if (date == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = date.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff < 0) return 'Expired';
    if (diff <= 7) return 'In $diff days';
    return '';
  }

  /// Formatted time string, e.g. "6:30 AM • Expired" or "6:30 AM • Today".
  String get formattedTimeString {
    final rel = relativeDateText;
    final cTime = cleanTime;
    if (cTime.isEmpty) return rel;
    if (rel.isEmpty) return cTime;
    return '$cTime • $rel';
  }
}
