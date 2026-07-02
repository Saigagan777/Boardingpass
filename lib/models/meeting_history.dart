import 'venue.dart';

class MeetingHistory {
  final String historyId;
  final DateTime? scheduledAt;
  final String? location;
  final Venue? venueSnapshot;
  final String updatedBy;
  final DateTime updatedAt;
  final String changeType; // 'created' | 'rescheduled' | 'poll_created' | 'vote_received' | 'winner_selected' | 'venue_changed' | 'completed'
  final String note;

  const MeetingHistory({
    required this.historyId,
    this.scheduledAt,
    this.location,
    this.venueSnapshot,
    required this.updatedBy,
    required this.updatedAt,
    required this.changeType,
    required this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'historyId': historyId,
      if (scheduledAt != null) 'scheduledAt': scheduledAt!.toIso8601String(),
      if (location != null) 'location': location,
      if (venueSnapshot != null) 'venueSnapshot': venueSnapshot!.toMap(),
      'updatedBy': updatedBy,
      'updatedAt': updatedAt.toIso8601String(),
      'changeType': changeType,
      'note': note,
    };
  }

  factory MeetingHistory.fromMap(Map<String, dynamic> map) {
    final rawSnapshot = map['venueSnapshot'];
    final Venue? venue = (rawSnapshot is Map)
        ? Venue.fromMap(Map<String, dynamic>.from(rawSnapshot))
        : null;

    return MeetingHistory(
      historyId: map['historyId']?.toString() ?? '',
      scheduledAt: map['scheduledAt'] != null ? DateTime.tryParse(map['scheduledAt'].toString()) : null,
      location: map['location']?.toString(),
      venueSnapshot: venue,
      updatedBy: map['updatedBy']?.toString() ?? '',
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      changeType: map['changeType']?.toString() ?? 'rescheduled',
      note: map['note']?.toString() ?? '',
    );
  }
}
