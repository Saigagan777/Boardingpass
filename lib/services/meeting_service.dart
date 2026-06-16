import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_service.dart';

/// Possible states of a meeting.
enum MeetingStatus { pending, confirmed, completed, cancelled }

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
        'status': 'pending',
        'scheduledAt': scheduledAt != null
            ? Timestamp.fromDate(scheduledAt)
            : null,
        'location': location,
        'note': note,
        'suggestedAgenda': agenda,
        'cancellationReasons': {},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

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

      await docRef.update({
        'scheduledAt': Timestamp.fromDate(newTime),
        'participantsStatus': currentStatusMap,
        'status': 'rescheduled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

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
}
