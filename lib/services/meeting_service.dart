import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chat_service.dart';
import '../models/enums.dart';
import '../models/venue.dart';
import '../models/meeting_history.dart';

/// Singleton service for the Firestore `meetings` collection.
///
/// Handles creating meetings between two users, streaming a user's meetings,
/// and updating meeting status through its lifecycle.
class MeetingService {
  static final MeetingService _instance = MeetingService._internal();
  factory MeetingService() => _instance;
  MeetingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Reference to the `meetings` collection.
  CollectionReference<Map<String, dynamic>> get _meetingsRef =>
      _firestore.collection('meetings');

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  /// Creates a new meeting request from the current user.
  ///
  /// Can be scheduled with multiple [participants]. The organizer is automatically
  /// set as host and marked as accepted. Smart agenda topics are generated.
  Future<String> createMeeting({
    required List<String> attendeeIds,
    DateTime? scheduledAt,
    String? location,
    String? note,
    int? reminderMinutes,
    String? chatId,
    String? meetingCity,
    String? meetingPurpose,
    String? meetingType,
    Map<String, dynamic>? selectedVenueSnapshot,
    String? selectedVenueId,
    String? selectedVenueProvider,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not signed in');

    try {
      final allParticipants = {uid, ...attendeeIds}.toList();
      final participantsStatus = <String, String>{};
      
      for (final p in allParticipants) {
        participantsStatus[p] = (p == uid) ? 'accepted' : 'pending';
      }

      // Generate suggested agenda based on profiles
      final List<String> agenda = await _generateSmartAgenda(allParticipants);

      final docRef = await _meetingsRef.add({
        'requesterId': uid, // Organizer
        'receiverId': attendeeIds.isNotEmpty ? attendeeIds.first : '', // Backwards compatibility
        'hosts': [uid],
        'participants': allParticipants,
        'participantsStatus': participantsStatus,
        'status': MeetingStatus.pending.name,
        'scheduledAt': scheduledAt != null
            ? Timestamp.fromDate(scheduledAt)
            : null,
        'location': location,
        'note': note,
        'reminderMinutes': reminderMinutes,
        'suggestedAgenda': agenda,
        'cancellationReasons': {},
        'chatId': chatId,
        'meetingCity': meetingCity ?? 'Vijayawada',
        'meetingPurpose': meetingPurpose ?? MeetingPurpose.custom.name,
        'meetingType': meetingType ?? 'in_person',
        'selectedVenueSnapshot': selectedVenueSnapshot,
        'selectedVenueId': selectedVenueId,
        'selectedVenueProvider': selectedVenueProvider,
        'currentPollId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log creation in history
      final historyDoc = docRef.collection('history').doc();
      final historyItem = MeetingHistory(
        historyId: historyDoc.id,
        scheduledAt: scheduledAt,
        location: location,
        venueSnapshot: selectedVenueSnapshot != null ? Venue.fromMap(selectedVenueSnapshot) : null,
        updatedBy: uid,
        updatedAt: DateTime.now(),
        changeType: 'created',
        note: 'Meeting created by organizer.',
      );
      await historyDoc.set(historyItem.toMap());

      // Send notifications to all invited participants
      final organizerName = _auth.currentUser?.displayName ?? 'Organizer';
      for (final p in attendeeIds) {
        await _firestore.collection('notifications').add({
          'userId': p,
          'title': '📅 New Meeting Invite',
          'body': '$organizerName invited you to a meeting at ${location ?? "Lounge"}.',
          'type': 'meeting_invite',
          'isRead': false,
          'metadata': {
            'meetingId': docRef.id,
            'organizerId': uid,
          },
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create meeting: $e');
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd MMM yyyy \'at\' HH:mm').format(dateTime);
  }

  /// Rules-based helper to generate a realistic agenda based on participants' profiles.
  Future<List<String>> _generateSmartAgenda(List<String> userIds) async {
    final agenda = <String>[];
    try {
      final List<Map<String, String>> roles = [];
      for (final uid in userIds) {
        final doc = await _firestore.collection('users').doc(uid).get();
        if (doc.exists) {
          final data = doc.data() ?? {};
          final role = (data['role'] as String? ?? '').toLowerCase();
          final company = (data['company'] as String? ?? '').toLowerCase();
          roles.add({'role': role, 'company': company});
        }
      }

      final hasTech = roles.any((r) => r['role']!.contains('dev') || r['role']!.contains('engine') || r['role']!.contains('tech') || r['role']!.contains('softw'));
      final hasFounder = roles.any((r) => r['role']!.contains('found') || r['role']!.contains('ceo') || r['role']!.contains('start'));
      final hasProduct = roles.any((r) => r['role']!.contains('prod') || r['role']!.contains('design') || r['role']!.contains('ux'));
      final hasPartnership = roles.any((r) => r['role']!.contains('partner') || r['role']!.contains('growth') || r['role']!.contains('market') || r['role']!.contains('biz') || r['role']!.contains('sale'));

      agenda.add('1. Intros & Networking: Shared goals and travel details');
      
      if (hasTech && hasFounder) {
        agenda.add('2. Tech Stack & Startup Vision: Scalability hurdles & architecture');
      } else if (hasTech) {
        agenda.add('2. Technical Deep-Dive: Cloud services, APIs, and stack choice');
      } else if (hasFounder) {
        agenda.add('2. Founder Sync: Startup business model, funding, and team growth');
      } else {
        agenda.add('2. Professional Backgrounds: Synergies between industries');
      }

      if (hasProduct || hasPartnership) {
        agenda.add('3. Collaboration Blueprint: Product roadmap, growth hacks, or partnership opportunities');
      } else {
        agenda.add('3. Next Action Items: Stay in touch, mutual LinkedIn follow-ups');
      }
    } catch (_) {
      // Fallback agenda if profile retrieval fails
      agenda.addAll([
        '1. Intros & Background: Connecting on current goals',
        '2. Discussion: Industry insights and business opportunities',
        '3. Next Steps: Staying connected and mutual support',
      ]);
    }
    return agenda;
  }

  // ---------------------------------------------------------------------------
  // Read / Stream
  // ---------------------------------------------------------------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> streamUserMeetings() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _meetingsRef
        .where('participants', arrayContains: uid)
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getMeeting(
      String meetingId) async {
    try {
      return await _meetingsRef.doc(meetingId).get();
    } catch (e) {
      throw Exception('Failed to get meeting: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Status updates
  // ---------------------------------------------------------------------------

  /// Updates the status of an attendee for [meetingId].
  ///
  /// If an attendee cancels, records the reason and notifies the hosts.
  /// If all attendees accept, transitions overall meeting status to `confirmed`.
  Future<void> updateParticipantStatus({
    required String meetingId,
    required String userId,
    required String status, // 'accepted', 'tentative', 'cancelled'
    String? reason,
    String? note,
  }) async {
    try {
      final docRef = _meetingsRef.doc(meetingId);
      final doc = await docRef.get();
      if (!doc.exists) throw Exception('Meeting not found');

      final data = doc.data() ?? {};
      final hosts = List<String>.from(data['hosts'] ?? []);
      final currentStatusMap = Map<String, dynamic>.from(data['participantsStatus'] ?? {});

      // Update local status map
      currentStatusMap[userId] = status;

      final updates = <String, dynamic>{
        'participantsStatus': currentStatusMap,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final userName = _auth.currentUser?.displayName ?? 'User';

      if (status == 'cancelled') {
        // Record cancellation details
        final reasonsMap = Map<String, dynamic>.from(data['cancellationReasons'] ?? {});
        reasonsMap[userId] = {
          'reason': reason ?? 'Other',
          'note': note ?? '',
          'timestamp': Timestamp.now(),
        };
        updates['cancellationReasons'] = reasonsMap;

        // If it's a 1-to-1 meeting, cancel the entire meeting
        final participants = List<String>.from(data['participants'] ?? []);
        if (participants.length <= 2) {
          updates['status'] = 'cancelled';
        }

        // Notify organizer/hosts of the cancellation
        for (final host in hosts) {
          if (host == userId) continue;
          await _firestore.collection('notifications').add({
            'userId': host,
            'title': '❌ Meeting Invitation Cancelled',
            'body': '$userName cancelled their attendance: ${reason ?? "Scheduling Conflict"}.',
            'type': 'meeting_cancel',
            'isRead': false,
            'metadata': {
              'meetingId': meetingId,
              'cancelledBy': userId,
              'reason': reason,
              'note': note,
            },
            'timestamp': FieldValue.serverTimestamp(),
          });
        }

        // Send a status update in the chat
        final otherId = participants.firstWhere((p) => p != userId, orElse: () => '');
        if (otherId.isNotEmpty && participants.length <= 2) {
          final chatId = await ChatService().getOrCreateChat(userId1: userId, userId2: otherId);
          await ChatService().sendTextMessage(
            chatId: chatId,
            text: '❌ Meeting Cancelled by $userName: ${reason ?? "Scheduling Conflict"}. ${note ?? ""}',
          );
        }
      } else if (status == 'accepted') {
        // Check if all non-host participants have accepted to mark the meeting as confirmed
        bool allAccepted = true;
        for (final entry in currentStatusMap.entries) {
          if (!hosts.contains(entry.key) && entry.value != 'accepted') {
            allAccepted = false;
            break;
          }
        }
        if (allAccepted) {
          updates['status'] = 'confirmed';
        }

        // Notify hosts of acceptance
        for (final host in hosts) {
          if (host == userId) continue;
          await _firestore.collection('notifications').add({
            'userId': host,
            'title': '✅ Meeting Invitation Accepted',
            'body': '$userName accepted your meeting request.',
            'type': 'meeting_accept',
            'isRead': false,
            'metadata': {
              'meetingId': meetingId,
              'acceptedBy': userId,
            },
            'timestamp': FieldValue.serverTimestamp(),
          });
        }

        // Send a status update in the chat
        final participants = List<String>.from(data['participants'] ?? []);
        final otherId = participants.firstWhere((p) => p != userId, orElse: () => '');
        if (otherId.isNotEmpty && participants.length <= 2) {
          final chatId = await ChatService().getOrCreateChat(userId1: userId, userId2: otherId);
          await ChatService().sendTextMessage(
            chatId: chatId,
            text: '✅ Meeting Accepted by $userName. Let\'s meet!',
          );
        }
      } else if (status == 'tentative') {
        // Notify hosts of tentative attendance
        for (final host in hosts) {
          if (host == userId) continue;
          await _firestore.collection('notifications').add({
            'userId': host,
            'title': '🤔 Meeting Status: Tentative',
            'body': '$userName marked your meeting request as Tentative.',
            'type': 'meeting_accept',
            'isRead': false,
            'metadata': {
              'meetingId': meetingId,
              'status': 'tentative',
            },
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }

      await docRef.update(updates);
    } catch (e) {
      throw Exception('Failed to update participant status: $e');
    }
  }

  /// Reschedules a meeting. Only hosts are permitted to call this.
  Future<void> rescheduleMeeting({
    required String meetingId,
    required DateTime newTime,
    required String userId,
    Map<String, dynamic>? newVenueSnapshot,
  }) async {
    try {
      final docRef = _meetingsRef.doc(meetingId);
      final doc = await docRef.get();
      if (!doc.exists) throw Exception('Meeting not found');

      final data = doc.data() ?? {};
      final hosts = List<String>.from(data['hosts'] ?? []);

      // Verify permission
      if (!hosts.contains(userId)) {
        throw Exception('Permission denied: Only meeting hosts can reschedule.');
      }

      final participants = List<String>.from(data['participants'] ?? []);
      final currentStatusMap = Map<String, dynamic>.from(data['participantsStatus'] ?? {});

      // Reset statuses: hosts remain accepted, others reset to pending
      for (final p in participants) {
        currentStatusMap[p] = hosts.contains(p) ? 'accepted' : 'pending';
      }

      final prevTime = (data['scheduledAt'] as Timestamp?)?.toDate();
      final prevLoc = data['location'] as String? ?? 'Not specified';
      final prevVenueRaw = data['selectedVenueSnapshot'] as Map<String, dynamic>?;
      final prevVenue = prevVenueRaw != null ? Venue.fromMap(prevVenueRaw) : null;

      final updatedLocation = newVenueSnapshot != null
          ? "${newVenueSnapshot['name']}, ${newVenueSnapshot['city']}"
          : prevLoc;

      // Update parent meeting schedule
      await docRef.update({
        'scheduledAt': Timestamp.fromDate(newTime),
        'location': updatedLocation,
        'selectedVenueSnapshot': newVenueSnapshot,
        'selectedVenueId': newVenueSnapshot?['id'],
        'selectedVenueProvider': newVenueSnapshot?['provider'],
        'participantsStatus': currentStatusMap,
        'status': MeetingStatus.rescheduled.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Write reschedule history
      final historyDoc = docRef.collection('history').doc();
      final historyItem = MeetingHistory(
        historyId: historyDoc.id,
        scheduledAt: prevTime,
        location: prevLoc,
        venueSnapshot: prevVenue,
        updatedBy: userId,
        updatedAt: DateTime.now(),
        changeType: 'rescheduled',
        note: 'Meeting rescheduled directly by host.',
      );
      await historyDoc.set(historyItem.toMap());

      // Send rescheduling notifications
      final hostName = _auth.currentUser?.displayName ?? 'Host';
      for (final p in participants) {
        if (p == userId) continue;
        await _firestore.collection('notifications').add({
          'userId': p,
          'title': '📅 Meeting Rescheduled',
          'body': '$hostName rescheduled the meeting. Please verify the new time.',
          'type': 'meeting_invite',
          'isRead': false,
          'metadata': {
            'meetingId': meetingId,
            'rescheduledBy': userId,
          },
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw Exception('Failed to reschedule meeting: $e');
    }
  }

  /// Toggle a participant's co-host role. Only hosts can toggle.
  Future<void> toggleCoHost({
    required String meetingId,
    required String userId,
    required bool makeCoHost,
    required String currentUserId,
  }) async {
    try {
      final docRef = _meetingsRef.doc(meetingId);
      final doc = await docRef.get();
      if (!doc.exists) throw Exception('Meeting not found');

      final data = doc.data() ?? {};
      final hosts = List<String>.from(data['hosts'] ?? []);

      // Verify permission
      if (!hosts.contains(currentUserId)) {
        throw Exception('Permission denied: Only meeting hosts can manage roles.');
      }

      if (makeCoHost) {
        await docRef.update({
          'hosts': FieldValue.arrayUnion([userId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Cannot remove the organizer/requester as host
        final requesterId = data['requesterId'] as String;
        if (userId == requesterId) {
          throw Exception('Cannot remove the organizer from co-host role.');
        }
        await docRef.update({
          'hosts': FieldValue.arrayRemove([userId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw Exception('Failed to toggle co-host role: $e');
    }
  }

  /// Shorthand to complete a meeting.
  Future<void> completeMeeting(String meetingId) async {
    try {
      await _meetingsRef.doc(meetingId).update({
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to complete meeting: $e');
    }
  }

  /// Shorthand to mark a meeting as expired/noshow.
  Future<void> updateOverallStatus({
    required String meetingId,
    required String status, // 'completed', 'expired', 'noshow'
  }) async {
    try {
      await _meetingsRef.doc(meetingId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update overall status: $e');
    }
  }

  /// Checks if [userId] has any confirmed meetings overlapping with the proposed [time].
  /// Assumes each meeting blocks a 1-hour window.
  Future<bool> hasMeetingConflict(String userId, DateTime time) async {
    try {
      final querySnapshot = await _meetingsRef
          .where('participants', arrayContains: userId)
          .get();

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        if (status != 'confirmed') {
          continue;
        }

        final scheduledTimestamp = data['scheduledAt'] as Timestamp?;
        if (scheduledTimestamp != null) {
          final scheduledAt = scheduledTimestamp.toDate();
          final diff = time.difference(scheduledAt).inMinutes.abs();
          if (diff < 60) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error checking meeting conflict: $e');
      return false;
    }
  }

  /// Proposes a new meeting time using a Firestore transaction.
  ///
  /// Creates a proposal entry with a unique ID, supersedes any previous active
  /// proposal by the same user, and notifies the host(s).
  Future<String> proposeOtherTime({
    required String meetingId,
    required DateTime proposedTime,
    String? note,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not signed in');

    final proposalId = '${uid}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final docRef = _meetingsRef.doc(meetingId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('Meeting not found');

        final data = snapshot.data()!;
        final proposals = List<Map<String, dynamic>>.from(data['proposals'] ?? []);

        // Supersede any previous active proposal from the same user
        for (int i = 0; i < proposals.length; i++) {
          if (proposals[i]['proposedBy'] == uid && proposals[i]['status'] == 'active') {
            proposals[i]['status'] = 'superseded';
            proposals[i]['updatedAt'] = Timestamp.now();
          }
        }

        // Add new proposal
        proposals.add({
          'proposalId': proposalId,
          'proposedBy': uid,
          'proposedTime': Timestamp.fromDate(proposedTime),
          'note': note ?? '',
          'status': 'active', // active | accepted | declined | superseded
          'responses': <String, String>{}, // participantId -> 'accepted'|'declined'
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });

        transaction.update(docRef, {
          'proposals': proposals,
          'participantsStatus.$uid': 'proposed_other_time',
          'status': 'RESCHEDULE_REQUESTED',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // Notify the host(s) outside the transaction
      final meetingDoc = await _meetingsRef.doc(meetingId).get();
      if (meetingDoc.exists) {
        final hosts = List<String>.from(meetingDoc.data()?['hosts'] ?? []);
        final userName = _auth.currentUser?.displayName ?? 'Participant';
        for (final hostId in hosts) {
          await _firestore.collection('notifications').add({
            'userId': hostId,
            'title': '🔄 New Time Proposed',
            'body': '$userName proposed a different time for your meeting.',
            'type': 'meeting_time_proposal',
            'isRead': false,
            'metadata': {
              'meetingId': meetingId,
              'proposalId': proposalId,
              'proposedBy': uid,
            },
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }

      return proposalId;
    } catch (e) {
      throw Exception('Failed to propose new time: $e');
    }
  }

  /// Accepts a specific proposal using a Firestore transaction.
  ///
  /// Implements **Host Decides** rule: if the current user is a host,
  /// accepting a proposal immediately updates the meeting's scheduled time
  /// and resets all participant statuses.
  Future<void> acceptProposal({
    required String meetingId,
    required String proposalId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not signed in');

    try {
      final docRef = _meetingsRef.doc(meetingId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('Meeting not found');

        final data = snapshot.data()!;
        final proposals = List<Map<String, dynamic>>.from(data['proposals'] ?? []);
        final hosts = List<String>.from(data['hosts'] ?? []);
        final participants = List<String>.from(data['participants'] ?? []);
        final isHost = hosts.contains(uid);

        // Find the proposal
        final proposalIndex = proposals.indexWhere((p) => p['proposalId'] == proposalId);
        if (proposalIndex == -1) throw Exception('Proposal not found');
        final proposal = proposals[proposalIndex];

        if (proposal['status'] != 'active') {
          throw Exception('Proposal is no longer active');
        }

        if (isHost) {
          // Host Decides: accepting = reschedule the meeting
          final proposedTime = proposal['proposedTime'] as Timestamp;
          final previousTimestamp = data['scheduledAt'] as Timestamp?;

          // Mark proposal as accepted
          proposals[proposalIndex]['status'] = 'accepted';
          proposals[proposalIndex]['updatedAt'] = Timestamp.now();

          // Supersede all other active proposals
          for (int i = 0; i < proposals.length; i++) {
            if (i != proposalIndex && proposals[i]['status'] == 'active') {
              proposals[i]['status'] = 'superseded';
              proposals[i]['updatedAt'] = Timestamp.now();
            }
          }

          // Reset participant statuses
          final statusMap = Map<String, dynamic>.from(data['participantsStatus'] ?? {});
          for (final p in participants) {
            statusMap[p] = hosts.contains(p) ? 'accepted' : 'pending';
          }

          final rescheduleHistory = List<Map<String, dynamic>>.from(data['rescheduleHistory'] ?? []);
          rescheduleHistory.add({
            'oldDateTime': previousTimestamp,
            'newDateTime': proposedTime,
            'requestedBy': proposal['proposedBy'],
            'approvedBy': uid,
            'timestamp': Timestamp.now(),
          });

          transaction.update(docRef, {
            'scheduledAt': proposedTime,
            'proposals': proposals,
            'participantsStatus': statusMap,
            'status': 'RESCHEDULE_APPROVED',
            'rescheduleHistory': rescheduleHistory,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Non-host: record response on the proposal
          final responses = Map<String, dynamic>.from(proposal['responses'] ?? {});
          responses[uid] = 'accepted';
          proposals[proposalIndex]['responses'] = responses;
          proposals[proposalIndex]['updatedAt'] = Timestamp.now();

          transaction.update(docRef, {
            'proposals': proposals,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // Notify relevant parties
      final meetingDoc = await _meetingsRef.doc(meetingId).get();
      if (meetingDoc.exists) {
        final data = meetingDoc.data()!;
        final hosts = List<String>.from(data['hosts'] ?? []);
        final userName = _auth.currentUser?.displayName ?? 'User';
        final isHost = hosts.contains(uid);

        if (isHost) {
          // Notify all non-host participants about the reschedule under the new scheme
          final participants = List<String>.from(data['participants'] ?? []);

          // Find the accepted proposal details
          final proposals = List<Map<String, dynamic>>.from(data['proposals'] ?? []);
          final proposalIndex = proposals.indexWhere((p) => p['proposalId'] == proposalId);
          final proposal = proposalIndex != -1 ? proposals[proposalIndex] : null;
          final requestedBy = proposal != null ? proposal['proposedBy'] : '';

          // Format previous and new date-times
          final historyList = List<Map<String, dynamic>>.from(data['rescheduleHistory'] ?? []);
          Timestamp? previousTimestamp;
          Timestamp? newTimestamp;
          if (historyList.isNotEmpty) {
            final lastHist = historyList.last;
            previousTimestamp = lastHist['oldDateTime'] as Timestamp?;
            newTimestamp = lastHist['newDateTime'] as Timestamp?;
          } else {
            newTimestamp = data['scheduledAt'] as Timestamp?;
          }

          final previousDateTime = previousTimestamp?.toDate();
          final newDateTime = newTimestamp?.toDate();
          final previousDateTimeStr = previousDateTime != null ? _formatDateTime(previousDateTime) : 'N/A';
          final updatedDateTimeStr = newDateTime != null ? _formatDateTime(newDateTime) : 'N/A';

          final location = data['location'] as String? ?? 'Lounge';
          final meetingTitle = data['title'] ?? data['note'] ?? 'Meeting at $location';

          // Fetch host name
          final userDoc = await _firestore.collection('users').doc(uid).get();
          final hostName = userDoc.data()?['name'] ?? _auth.currentUser?.displayName ?? 'Host';

          for (final p in participants) {
            if (p == uid) continue;
            await _firestore.collection('notifications').add({
              'userId': p,
              'title': '📅 Meeting Rescheduled',
              'body': 'Meeting rescheduled from $previousDateTimeStr to $updatedDateTimeStr. Approved by: $hostName.',
              'type': 'MEETING_RESCHEDULE_APPROVED',
              'isRead': false,
              'metadata': {
                'meetingId': meetingId,
                'meetingTitle': meetingTitle,
                'previousDateTime': previousDateTimeStr,
                'updatedDateTime': updatedDateTimeStr,
                'rescheduleRequestedBy': requestedBy,
                'approvedBy': uid,
              },
              'timestamp': FieldValue.serverTimestamp(),
            });
          }

          // Construct and send system message
          final systemText = 'Meeting Rescheduled\n\n'
              'Previous: $previousDateTimeStr\n'
              'Updated: $updatedDateTimeStr\n'
              'Approved by: $hostName';

          String? resolvedChatId = data['chatId'] as String?;
          if (resolvedChatId == null || resolvedChatId.isEmpty) {
            final otherId = participants.firstWhere((p) => p != uid, orElse: () => '');
            if (otherId.isNotEmpty) {
              resolvedChatId = await ChatService().getOrCreateChat(userId1: uid, userId2: otherId);
            }
          }

          if (resolvedChatId != null && resolvedChatId.isNotEmpty) {
            await ChatService().sendSystemMessage(
              chatId: resolvedChatId,
              text: systemText,
            );
            final cardText = "📅 Meeting Request: Let's meet at $location on $updatedDateTimeStr [meetingId:$meetingId]";
            await ChatService().sendTextMessage(
              chatId: resolvedChatId,
              text: cardText,
            );
          }
        } else {
          // Notify hosts that a participant accepted the proposal
          for (final hostId in hosts) {
            await _firestore.collection('notifications').add({
              'userId': hostId,
              'title': '✅ Proposal Response',
              'body': '$userName accepted the proposed time.',
              'type': 'meeting_time_proposal',
              'isRead': false,
              'metadata': {'meetingId': meetingId, 'proposalId': proposalId},
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to accept proposal: $e');
    }
  }

  /// Declines a specific proposal using a Firestore transaction.
  Future<void> declineProposal({
    required String meetingId,
    required String proposalId,
    String? reason,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not signed in');

    try {
      final docRef = _meetingsRef.doc(meetingId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('Meeting not found');

        final data = snapshot.data()!;
        final proposals = List<Map<String, dynamic>>.from(data['proposals'] ?? []);
        final hosts = List<String>.from(data['hosts'] ?? []);
        final isHost = hosts.contains(uid);

        final proposalIndex = proposals.indexWhere((p) => p['proposalId'] == proposalId);
        if (proposalIndex == -1) throw Exception('Proposal not found');

        if (proposals[proposalIndex]['status'] != 'active') {
          throw Exception('Proposal is no longer active');
        }

        final Map<String, dynamic> updates = {
          'proposals': proposals,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (isHost) {
          // Host declining = kill the proposal
          proposals[proposalIndex]['status'] = 'declined';
          proposals[proposalIndex]['declinedBy'] = uid;
          proposals[proposalIndex]['declineReason'] = reason ?? '';
          proposals[proposalIndex]['updatedAt'] = Timestamp.now();
          updates['status'] = 'RESCHEDULE_REJECTED';
        } else {
          // Non-host: record decline response
          final responses = Map<String, dynamic>.from(proposals[proposalIndex]['responses'] ?? {});
          responses[uid] = 'declined';
          proposals[proposalIndex]['responses'] = responses;
          proposals[proposalIndex]['updatedAt'] = Timestamp.now();
        }

        transaction.update(docRef, updates);
      });

      // Notify the proposer
      final meetingDoc = await _meetingsRef.doc(meetingId).get();
      if (meetingDoc.exists) {
        final data = meetingDoc.data()!;
        final proposals = List<Map<String, dynamic>>.from(data['proposals'] ?? []);
        final proposal = proposals.firstWhere((p) => p['proposalId'] == proposalId, orElse: () => {});
        final proposedBy = proposal['proposedBy'] as String?;
        if (proposedBy != null && proposedBy != uid) {
          final userName = _auth.currentUser?.displayName ?? 'User';
          await _firestore.collection('notifications').add({
            'userId': proposedBy,
            'title': '❌ Proposal Declined',
            'body': '$userName declined your proposed time.${reason != null ? ' Reason: $reason' : ''}',
            'type': 'meeting_time_proposal',
            'isRead': false,
            'metadata': {'meetingId': meetingId, 'proposalId': proposalId},
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      throw Exception('Failed to decline proposal: $e');
    }
  }

  /// Returns only active proposals for a meeting.
  Future<List<Map<String, dynamic>>> getActiveProposals(String meetingId) async {
    try {
      final doc = await _meetingsRef.doc(meetingId).get();
      if (!doc.exists) return [];
      final data = doc.data()!;
      final proposals = List<Map<String, dynamic>>.from(data['proposals'] ?? []);
      return proposals.where((p) => p['status'] == 'active').toList();
    } catch (e) {
      debugPrint('Error fetching active proposals: $e');
      return [];
    }
  }
}
