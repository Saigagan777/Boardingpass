import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Singleton service for the Firestore `events` collection.
///
/// Handles creating events, streaming event lists, toggling join/unjoin,
/// querying attendees, and deleting events.
class EventService {
  static final EventService _instance = EventService._internal();
  factory EventService() => _instance;
  EventService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Reference to the `events` collection.
  CollectionReference<Map<String, dynamic>> get _eventsRef =>
      _firestore.collection('events');

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  /// Creates a new event document and returns its ID.
  ///
  /// The organiser is automatically set to the current user.
  Future<String> createEvent({
    required String title,
    required String location,
    required String time,
    required String month,
    required String day,
    String? illustrationPath,
    String category = 'Meetups',
    String price = 'Free',
    String? mapUrl,
    double? latitude,
    double? longitude,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not signed in');

    try {
      final docRef = await _eventsRef.add({
        'title': title,
        'location': location,
        'time': time,
        'month': month,
        'day': day,
        'illustrationPath': illustrationPath ?? '',
        'category': category,
        'price': price,
        if (mapUrl != null && mapUrl.isNotEmpty) 'mapUrl': mapUrl,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'organiserId': uid,
        'attendees': <String>[],
        'attendeeCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create event: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Read / Stream
  // ---------------------------------------------------------------------------

  /// Streams all events, newest first.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamAllEvents() {
    return _eventsRef
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Streams events organised by [userId].
  Stream<QuerySnapshot<Map<String, dynamic>>> streamEventsByUser(
      String userId) {
    return _eventsRef
        .where('organiserId', isEqualTo: userId)
        .snapshots();
  }

  /// Fetches a single event document by [eventId].
  Future<DocumentSnapshot<Map<String, dynamic>>> getEvent(
      String eventId) async {
    try {
      return await _eventsRef.doc(eventId).get();
    } catch (e) {
      throw Exception('Failed to get event: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Join / Unjoin
  // ---------------------------------------------------------------------------

  /// Toggles the current user's attendance for [eventId].
  ///
  /// Returns `true` if the user is now joined, `false` if unjoined.
  Future<bool> toggleJoinEvent(String eventId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not signed in');

    try {
      final docRef = _eventsRef.doc(eventId);

      return _firestore.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('Event not found');

        final attendees =
            List<String>.from(snapshot.data()?['attendees'] ?? []);
        final bool isJoining = !attendees.contains(uid);

        if (isJoining) {
          attendees.add(uid);
        } else {
          attendees.remove(uid);
        }

        transaction.update(docRef, {
          'attendees': attendees,
          'attendeeCount': attendees.length,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return isJoining;
      });
    } catch (e) {
      throw Exception('Failed to toggle event join: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Attendees
  // ---------------------------------------------------------------------------

  /// Returns the list of user IDs who have joined [eventId].
  Future<List<String>> getEventAttendees(String eventId) async {
    try {
      final doc = await _eventsRef.doc(eventId).get();
      if (!doc.exists) return [];
      return List<String>.from(doc.data()?['attendees'] ?? []);
    } catch (e) {
      throw Exception('Failed to get event attendees: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  /// Deletes the event [eventId].
  ///
  /// Only the organiser or an admin should call this (enforce in the UI layer
  /// or with Firestore Security Rules).
  Future<void> deleteEvent(String eventId) async {
    try {
      await _eventsRef.doc(eventId).delete();
    } catch (e) {
      throw Exception('Failed to delete event: $e');
    }
  }
}
