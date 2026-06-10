import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  /// Creates a new meeting request from the current user to [otherUserId].
  ///
  /// Optionally accepts a [scheduledAt] time, a [location] string, and a
  /// free-form [note].  The initial status is [MeetingStatus.pending].
  ///
  /// Returns the new meeting document's ID.
  Future<String> createMeeting({
    required String otherUserId,
    DateTime? scheduledAt,
    String? location,
    String? note,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not signed in');

    try {
      final docRef = await _meetingsRef.add({
        'requesterId': uid,
        'receiverId': otherUserId,
        'participants': [uid, otherUserId],
        'status': MeetingStatus.pending.name,
        'scheduledAt': scheduledAt != null
            ? Timestamp.fromDate(scheduledAt)
            : null,
        'location': location,
        'note': note,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create meeting: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Read / Stream
  // ---------------------------------------------------------------------------

  /// Streams the current user's meetings (both requested and received),
  /// ordered by most-recently updated.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamUserMeetings() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _meetingsRef
        .where('participants', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  /// Fetches a single meeting document by [meetingId].
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

  /// Updates the status of [meetingId] to [status].
  Future<void> updateMeetingStatus({
    required String meetingId,
    required MeetingStatus status,
  }) async {
    try {
      await _meetingsRef.doc(meetingId).update({
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update meeting status: $e');
    }
  }

  /// Shorthand to confirm a pending meeting.
  Future<void> confirmMeeting(String meetingId) async {
    await updateMeetingStatus(
      meetingId: meetingId,
      status: MeetingStatus.confirmed,
    );
  }

  /// Shorthand to mark a meeting as completed.
  Future<void> completeMeeting(String meetingId) async {
    await updateMeetingStatus(
      meetingId: meetingId,
      status: MeetingStatus.completed,
    );
  }

  /// Cancels the meeting [meetingId] by setting its status to `cancelled`.
  Future<void> cancelMeeting(String meetingId) async {
    await updateMeetingStatus(
      meetingId: meetingId,
      status: MeetingStatus.cancelled,
    );
  }
}
