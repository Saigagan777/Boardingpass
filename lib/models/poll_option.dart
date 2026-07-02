import 'venue.dart';

class PollOption {
  final String optionId;
  final Venue? venueSnapshot;
  final String date; // YYYY-MM-DD
  final String time; // HH:MM
  final int voteCount;
  final Map<String, bool> voters; // userId -> voted (true)

  const PollOption({
    required this.optionId,
    this.venueSnapshot,
    required this.date,
    required this.time,
    required this.voteCount,
    required this.voters,
  });

  Map<String, dynamic> toMap() {
    return {
      'optionId': optionId,
      'venueSnapshot': venueSnapshot?.toMap(),
      'date': date,
      'time': time,
      'voteCount': voteCount,
      'voters': voters,
    };
  }

  factory PollOption.fromMap(Map<String, dynamic> map) {
    final rawSnapshot = map['venueSnapshot'];
    final Venue? venue = (rawSnapshot is Map)
        ? Venue.fromMap(Map<String, dynamic>.from(rawSnapshot))
        : null;

    final rawVoters = map['voters'];
    final Map<String, bool> votersMap = (rawVoters is Map)
        ? Map<String, bool>.from(rawVoters.map((key, val) => MapEntry(key.toString(), val == true)))
        : {};

    return PollOption(
      optionId: map['optionId']?.toString() ?? '',
      venueSnapshot: venue,
      date: map['date']?.toString() ?? '',
      time: map['time']?.toString() ?? '',
      voteCount: map['voteCount'] is num ? (map['voteCount'] as num).toInt() : 0,
      voters: votersMap,
    );
  }
}
