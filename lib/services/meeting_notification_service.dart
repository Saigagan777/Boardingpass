import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MeetingNotificationService {
  static final MeetingNotificationService _instance = MeetingNotificationService._internal();
  factory MeetingNotificationService() => _instance;
  MeetingNotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> notifyPollCreated({
    required String meetingId,
    required List<String> participantIds,
    required String hostName,
  }) async {
    await _sendBulkNotification(
      userIds: participantIds,
      title: '📊 Reschedule Poll Created',
      body: '$hostName raised a preferences poll for rescheduling.',
      meetingId: meetingId,
    );
  }

  Future<void> notifyVoteReceived({
    required String meetingId,
    required String optionId,
    required String userName,
    required List<String> hostIds,
  }) async {
    await _sendBulkNotification(
      userIds: hostIds,
      title: '🗳️ New Vote in Reschedule Poll',
      body: '$userName voted for a slot in the reschedule poll.',
      meetingId: meetingId,
    );
  }

  Future<void> notifyPollClosed({
    required String meetingId,
    required List<String> participantIds,
    required String hostName,
  }) async {
    await _sendBulkNotification(
      userIds: participantIds,
      title: '🔒 Reschedule Poll Closed',
      body: '$hostName closed the reschedule poll.',
      meetingId: meetingId,
    );
  }

  Future<void> notifyMeetingRescheduled({
    required String meetingId,
    required List<String> participantIds,
    required String hostName,
  }) async {
    await _sendBulkNotification(
      userIds: participantIds,
      title: '📅 Meeting Rescheduled',
      body: '$hostName finalized the new schedule for the meeting.',
      meetingId: meetingId,
    );
  }

  Future<void> notifyVenueChanged({
    required String meetingId,
    required List<String> participantIds,
    required String hostName,
    required String newVenueName,
  }) async {
    await _sendBulkNotification(
      userIds: participantIds,
      title: '📍 Meeting Venue Changed',
      body: '$hostName changed the meeting location to $newVenueName.',
      meetingId: meetingId,
    );
  }

  Future<void> _sendBulkNotification({
    required List<String> userIds,
    required String title,
    required String body,
    required String meetingId,
  }) async {
    final currentUid = _auth.currentUser?.uid;
    for (final userId in userIds) {
      if (userId == currentUid) continue; // Skip self

      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': 'meeting_invite',
        'isRead': false,
        'metadata': {
          'meetingId': meetingId,
        },
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }
}
