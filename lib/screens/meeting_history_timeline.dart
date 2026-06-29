import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meeting_history.dart';
import '../services/user_service.dart';

class MeetingHistoryTimeline extends StatelessWidget {
  final String meetingId;

  const MeetingHistoryTimeline({
    super.key,
    required this.meetingId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('meetings')
          .doc(meetingId)
          .collection('history')
          .orderBy('updatedAt', descending: true)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final historyDocs = snapshot.data!.docs;
        final historyList = historyDocs
            .map((doc) => MeetingHistory.fromMap(doc.data() as Map<String, dynamic>))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 24, color: Color(0xFFE8E2DD)),
            Row(
              children: const [
                Icon(Icons.history, size: 16, color: Color(0xFF8C736B)),
                SizedBox(width: 6),
                Text(
                  'MEETING HISTORY TIMELINE',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Color(0xFF8C736B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: historyList.length,
              itemBuilder: (context, index) {
                final item = historyList[index];
                return _buildHistoryItem(item);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistoryItem(MeetingHistory item) {
    IconData icon;
    Color color;

    switch (item.changeType) {
      case 'created':
        icon = Icons.add_circle_outline;
        color = const Color(0xFF2E7D32);
        break;
      case 'poll_created':
        icon = Icons.bar_chart;
        color = const Color(0xFF7A432D);
        break;
      case 'winner_selected':
        icon = Icons.check_circle_outline;
        color = const Color(0xFF2E7D32);
        break;
      case 'rescheduled':
        icon = Icons.edit_calendar;
        color = const Color(0xFFEF6C00);
        break;
      case 'vote_received':
        icon = Icons.how_to_vote;
        color = const Color(0xFFE5A475);
        break;
      case 'completed':
        icon = Icons.done_all;
        color = Colors.blueGrey;
        break;
      default:
        icon = Icons.info_outline;
        color = const Color(0xFF8C736B);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Icon(icon, size: 16, color: color),
              Container(
                width: 1.5,
                height: 24,
                color: const Color(0xFFE8E2DD),
              ),
            ],
          ),
          const SizedBox(width: 10),

          // Event Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FutureBuilder<String>(
                      future: UserService()
                          .getUserProfile(item.updatedBy)
                          .then((p) => p?.name ?? 'Someone'),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? 'Loading...',
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3E1F11),
                          ),
                        );
                      },
                    ),
                    Text(
                      _formatDate(item.updatedAt),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10,
                        color: Color(0xFF8C736B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.note,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    color: Color(0xFF5C473E),
                  ),
                ),
                if (item.venueSnapshot != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE8E2DD)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '📍 Venue: ${item.venueSnapshot!.name}',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10,
                        color: Color(0xFF7A432D),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
