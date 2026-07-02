import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meeting_poll.dart';
import '../services/poll_service.dart';
import '../services/user_service.dart';
import 'venue_details_sheet.dart';

class PollWidget extends StatelessWidget {
  final String meetingId;
  final String pollId;
  final bool isHost;

  const PollWidget({
    super.key,
    required this.meetingId,
    required this.pollId,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: PollService().streamActivePoll(meetingId, pollId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7A432D)),
              ),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final pollData = snapshot.data!.data() as Map<String, dynamic>;
        final poll = MeetingPoll.fromMap(pollData);

        if (poll.status != 'active') {
          return const SizedBox.shrink(); // Poll has resolved or been cancelled
        }

        // Calculate total votes across all options to show percentages
        final totalVotes = poll.options.fold<int>(0, (total, opt) => total + opt.voteCount);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5A475), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bar_chart, color: Color(0xFF7A432D), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        isHost ? 'Collaborative Reschedule Poll' : 'Vote on Preferences',
                        style: const TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                    ],
                  ),
                  if (isHost)
                    TextButton(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () => PollService().cancelPoll(
                        meetingId: meetingId,
                        pollId: pollId,
                        userId: currentUserId,
                      ),
                      child: const Text(
                        'Cancel Poll',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          color: Color(0xFFC62828),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Options list
              ...poll.options.map((option) {
                final hasVoted = option.voters[currentUserId] == true;
                final dateStr = option.date;
                final timeStr = option.time;

                // Percent bar calculation
                final percent = totalVotes > 0 ? (option.voteCount / totalVotes) : 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasVoted ? const Color(0xFF7A432D) : const Color(0xFFE8E2DD),
                      width: hasVoted ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header details row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '📅 $dateStr at $timeStr',
                                    style: const TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF3E1F11),
                                    ),
                                  ),
                                  if (option.venueSnapshot != null) ...[
                                    const SizedBox(height: 4),
                                    InkWell(
                                      onTap: () {
                                        VenueDetailsSheet.show(
                                          context,
                                          venue: option.venueSnapshot!,
                                          showConfirmButton: false,
                                        );
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.location_on, color: Color(0xFF7A432D), size: 14),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              option.venueSnapshot!.name,
                                              style: const TextStyle(
                                                fontFamily: 'PlusJakartaSans',
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF7A432D),
                                                decoration: TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Action buttons (Vote or Host finalize)
                            Row(
                              children: [
                                // Vote button
                                IconButton(
                                  icon: Icon(
                                    hasVoted ? Icons.check_box : Icons.check_box_outline_blank,
                                    color: hasVoted ? const Color(0xFF7A432D) : const Color(0xFF8C736B),
                                  ),
                                  onPressed: () => PollService().vote(
                                    meetingId: meetingId,
                                    pollId: pollId,
                                    optionId: option.optionId,
                                    userId: currentUserId,
                                    voteValue: !hasVoted,
                                  ),
                                ),

                                // Host Select Winner button
                                if (isHost)
                                  IconButton(
                                    icon: const Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
                                    tooltip: 'Lock in this option',
                                    onPressed: () => _confirmFinalize(
                                      context,
                                      optionId: option.optionId,
                                      optionDesc: '$dateStr at $timeStr',
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Vote progress bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent,
                            backgroundColor: const Color(0xFFFAF7F5),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE5A475)),
                            minHeight: 6,
                          ),
                        ),
                      ),

                      // Voters initials row
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildVoterAvatars(option.voters.keys.toList()),
                            Text(
                              '${option.voteCount} ${option.voteCount == 1 ? 'vote' : 'votes'}',
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8C736B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _confirmFinalize(
    BuildContext context, {
    required String optionId,
    required String optionDesc,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Schedule', style: TextStyle(fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to finalize the reschedule to $optionDesc? This will lock in the meeting time and notify other participants.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8C736B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A432D)),
            onPressed: () async {
              Navigator.pop(ctx);
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                await PollService().finalizeWinner(
                  meetingId: meetingId,
                  pollId: pollId,
                  optionId: optionId,
                  userId: uid,
                );
              }
            },
            child: const Text('Finalize', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildVoterAvatars(List<String> voterUids) {
    if (voterUids.isEmpty) {
      return const SizedBox(height: 16);
    }

    return SizedBox(
      height: 20,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: voterUids.length.clamp(0, 5),
        itemBuilder: (context, index) {
          final uid = voterUids[index];
          return FutureBuilder<String>(
            future: UserService().getUserProfile(uid).then((p) => p?.name.substring(0, 1).toUpperCase() ?? '?'),
            builder: (context, snapshot) {
              final initial = snapshot.data ?? '';
              return Container(
                margin: const EdgeInsets.only(right: 4),
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE5A475),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
