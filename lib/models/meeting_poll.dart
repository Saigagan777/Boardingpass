import 'poll_option.dart';

class MeetingPoll {
  final String id;
  final String type; // 'venue' | 'date' | 'time' | 'venue_date_time'
  final String status; // 'active' | 'closed' | 'cancelled'
  final DateTime deadline;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? closedAt;
  final bool allowMultipleVotes;
  final String? winningOption;
  final List<PollOption> options;

  const MeetingPoll({
    required this.id,
    required this.type,
    required this.status,
    required this.deadline,
    required this.createdBy,
    required this.createdAt,
    this.closedAt,
    required this.allowMultipleVotes,
    this.winningOption,
    required this.options,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'status': status,
      'deadline': deadline.toIso8601String(),
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      if (closedAt != null) 'closedAt': closedAt!.toIso8601String(),
      'allowMultipleVotes': allowMultipleVotes,
      if (winningOption != null) 'winningOption': winningOption,
      'options': options.map((opt) => opt.toMap()).toList(),
    };
  }

  factory MeetingPoll.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'];
    final List<PollOption> parsedOptions = (rawOptions is List)
        ? rawOptions.map((opt) => PollOption.fromMap(Map<String, dynamic>.from(opt))).toList()
        : [];

    return MeetingPoll(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? 'venue_date_time',
      status: map['status']?.toString() ?? 'active',
      deadline: map['deadline'] != null
          ? DateTime.tryParse(map['deadline'].toString()) ?? DateTime.now().add(const Duration(days: 1))
          : DateTime.now().add(const Duration(days: 1)),
      createdBy: map['createdBy']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      closedAt: map['closedAt'] != null ? DateTime.tryParse(map['closedAt'].toString()) : null,
      allowMultipleVotes: map['allowMultipleVotes'] == true,
      winningOption: map['winningOption']?.toString(),
      options: parsedOptions,
    );
  }
}
