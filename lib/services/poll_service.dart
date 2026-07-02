import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/enums.dart';
import '../models/meeting_poll.dart';
import '../models/poll_option.dart';
import '../models/meeting_history.dart';

class PollService {
  static final PollService _instance = PollService._internal();
  factory PollService() => _instance;
  PollService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _meetingsRef => _firestore.collection('meetings');

  /// Creates a poll under meetings/{meetingId}/polls/{pollId}
  Future<void> createPoll({required String meetingId, required MeetingPoll poll}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not signed in');

    final batch = _firestore.batch();
    final meetingDoc = _meetingsRef.doc(meetingId);
    final pollDoc = meetingDoc.collection('polls').doc(poll.id);

    // Save the poll document
    batch.set(pollDoc, poll.toMap());

    // Update parent meeting status to pollOpen and set currentPollId
    batch.update(meetingDoc, {
      'currentPollId': poll.id,
      'status': MeetingStatus.pollOpen.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Save poll creation to history subcollection
    final historyDoc = meetingDoc.collection('history').doc();
    final historyItem = MeetingHistory(
      historyId: historyDoc.id,
      updatedBy: uid,
      updatedAt: DateTime.now(),
      changeType: 'poll_created',
      note: 'Preferences poll raised by organizer.',
    );
    batch.set(historyDoc, historyItem.toMap());

    await batch.commit();

    // Trigger Notification
    await _sendPollNotification(meetingId, '📊 Reschedule Poll Created', 'A poll has been raised to choose a new time/location.');
  }

  /// Casts or toggles a vote on a specific poll option using a transaction
  Future<void> vote({
    required String meetingId,
    required String pollId,
    required String optionId,
    required String userId,
    required bool voteValue, // true to add vote, false to remove
  }) async {
    final pollDocRef = _meetingsRef.doc(meetingId).collection('polls').doc(pollId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(pollDocRef);
      if (!snapshot.exists) throw Exception('Poll not found');

      final poll = MeetingPoll.fromMap(snapshot.data() as Map<String, dynamic>);
      final options = List<PollOption>.from(poll.options);

      final optionIndex = options.indexWhere((opt) => opt.optionId == optionId);
      if (optionIndex == -1) throw Exception('Option not found');

      final option = options[optionIndex];
      final voters = Map<String, bool>.from(option.voters);

      if (voteValue) {
        // Cast vote
        if (voters[userId] == true) return; // already voted

        if (!poll.allowMultipleVotes) {
          // If single vote only, clear user's vote from all other options
          for (int i = 0; i < options.length; i++) {
            if (i == optionIndex) continue;
            final otherVoters = Map<String, bool>.from(options[i].voters);
            if (otherVoters[userId] == true) {
              otherVoters.remove(userId);
              options[i] = PollOption(
                optionId: options[i].optionId,
                venueSnapshot: options[i].venueSnapshot,
                date: options[i].date,
                time: options[i].time,
                voteCount: (options[i].voteCount - 1).clamp(0, 999),
                voters: otherVoters,
              );
            }
          }
        }

        voters[userId] = true;
        options[optionIndex] = PollOption(
          optionId: option.optionId,
          venueSnapshot: option.venueSnapshot,
          date: option.date,
          time: option.time,
          voteCount: option.voteCount + 1,
          voters: voters,
        );
      } else {
        // Remove vote
        if (voters[userId] != true) return; // not voted

        voters.remove(userId);
        options[optionIndex] = PollOption(
          optionId: option.optionId,
          venueSnapshot: option.venueSnapshot,
          date: option.date,
          time: option.time,
          voteCount: (option.voteCount - 1).clamp(0, 999),
          voters: voters,
        );
      }

      transaction.update(pollDocRef, {
        'options': options.map((opt) => opt.toMap()).toList(),
      });
    });

    // Log vote event to parent meeting history
    final historyDoc = _meetingsRef.doc(meetingId).collection('history').doc();
    final historyItem = MeetingHistory(
      historyId: historyDoc.id,
      updatedBy: userId,
      updatedAt: DateTime.now(),
      changeType: 'vote_received',
      note: voteValue ? 'Participant voted in reschedule poll.' : 'Participant removed vote.',
    );
    await historyDoc.set(historyItem.toMap());
  }

  /// Finalizes the schedule using the winning option
  Future<void> finalizeWinner({
    required String meetingId,
    required String pollId,
    required String optionId,
    required String userId,
  }) async {
    final meetingDocRef = _meetingsRef.doc(meetingId);
    final pollDocRef = meetingDocRef.collection('polls').doc(pollId);

    final pollSnap = await pollDocRef.get();
    if (!pollSnap.exists) throw Exception('Poll not found');

    final poll = MeetingPoll.fromMap(pollSnap.data() as Map<String, dynamic>);
    final option = poll.options.firstWhere((opt) => opt.optionId == optionId, orElse: () => throw Exception('Option not found'));

    // Retrieve previous schedule details to archive in history
    final parentSnap = await meetingDocRef.get();
    if (!parentSnap.exists) throw Exception('Meeting not found');
    final parentData = parentSnap.data() as Map<String, dynamic>;

    final prevTime = (parentData['scheduledAt'] as Timestamp?)?.toDate();
    final prevLoc = parentData['location'] as String? ?? 'Not specified';

    // Parse options date/time
    final dateParts = option.date.split('-'); // YYYY-MM-DD
    final timeParts = option.time.split(':'); // HH:MM
    final newSchedule = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    );

    final batch = _firestore.batch();

    // Close poll
    batch.update(pollDocRef, {
      'status': 'closed',
      'winningOption': optionId,
      'closedAt': FieldValue.serverTimestamp(),
    });

    // Reset status maps (hosts remain accepted, others reset to pending)
    final participants = List<String>.from(parentData['participants'] ?? []);
    final hosts = List<String>.from(parentData['hosts'] ?? []);
    final statusMap = <String, String>{};
    for (final p in participants) {
      statusMap[p] = hosts.contains(p) ? 'accepted' : 'pending';
    }


    // Update parent meeting schedule
    batch.update(meetingDocRef, {
      'scheduledAt': Timestamp.fromDate(newSchedule),
      'location': option.venueSnapshot != null
          ? '${option.venueSnapshot!.name}, ${option.venueSnapshot!.city}'
          : prevLoc,
      'selectedVenueSnapshot': option.venueSnapshot?.toMap(),
      'selectedVenueId': option.venueSnapshot?.id,
      'selectedVenueProvider': option.venueSnapshot?.provider,
      'currentPollId': null,
      'status': MeetingStatus.rescheduled.name,
      'participantsStatus': statusMap,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Write history
    final historyDoc = meetingDocRef.collection('history').doc();
    final historyItem = MeetingHistory(
      historyId: historyDoc.id,
      scheduledAt: prevTime,
      location: prevLoc,
      updatedBy: userId,
      updatedAt: DateTime.now(),
      changeType: 'winner_selected',
      note: 'Poll resolved. Winning option finalized by host.',
    );
    batch.set(historyDoc, historyItem.toMap());

    await batch.commit();

    // Trigger Notification
    await _sendPollNotification(meetingId, '📅 Meeting Rescheduled', 'A winning option has been finalized for your meeting reschedule.');
  }

  /// Cancels the preference poll
  Future<void> cancelPoll({
    required String meetingId,
    required String pollId,
    required String userId,
  }) async {
    final meetingDocRef = _meetingsRef.doc(meetingId);
    final pollDocRef = meetingDocRef.collection('polls').doc(pollId);

    final batch = _firestore.batch();
    batch.update(pollDocRef, {
      'status': 'cancelled',
      'closedAt': FieldValue.serverTimestamp(),
    });

    batch.update(meetingDocRef, {
      'currentPollId': null,
      'status': MeetingStatus.scheduled.name, // Reverts back to scheduled
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final historyDoc = meetingDocRef.collection('history').doc();
    final historyItem = MeetingHistory(
      historyId: historyDoc.id,
      updatedBy: userId,
      updatedAt: DateTime.now(),
      changeType: 'rescheduled', // log cancel
      note: 'Reschedule poll cancelled by host.',
    );
    batch.set(historyDoc, historyItem.toMap());

    await batch.commit();
  }

  /// Streams active poll for a meeting
  Stream<DocumentSnapshot> streamActivePoll(String meetingId, String pollId) {
    return _meetingsRef.doc(meetingId).collection('polls').doc(pollId).snapshots();
  }

  /// Fetches poll history for a meeting
  Future<List<MeetingPoll>> getPollHistory(String meetingId) async {
    final snaps = await _meetingsRef.doc(meetingId).collection('polls').get();
    return snaps.docs
        .map((doc) => MeetingPoll.fromMap(doc.data()))
        .toList();
  }

  Future<void> _sendPollNotification(String meetingId, String title, String body) async {
    try {
      final doc = await _meetingsRef.doc(meetingId).get();
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      final participants = List<String>.from(data['participants'] ?? []);
      final currentUid = _auth.currentUser?.uid;

      for (final p in participants) {
        if (p == currentUid) continue; // skip self
        await _firestore.collection('notifications').add({
          'userId': p,
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
    } catch (_) {}
  }
}
