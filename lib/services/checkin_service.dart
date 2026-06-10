import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/checkin.dart';

/// Singleton service for the Firestore `checkins` collection.
///
/// Supports creating / deleting check-ins, streaming a user's check-in
/// history, querying active nearby check-ins via geohash prefix, and
/// deactivating a check-in on checkout.
class CheckinService {
  static final CheckinService _instance = CheckinService._internal();
  factory CheckinService() => _instance;
  CheckinService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Reference to the `checkins` collection.
  CollectionReference<Map<String, dynamic>> get _checkinsRef =>
      _firestore.collection('checkins');

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  /// Creates a new check-in document in Firestore and optionally updates the
  /// user's `currentCheckin` field.
  ///
  /// [location] and [geohash] are used for proximity queries against other
  /// active check-ins.
  Future<String> createCheckin({
    required Checkin checkin,
    required GeoPoint location,
    required String geohash,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not signed in');

    try {
      final docRef = await _checkinsRef.add({
        'userId': uid,
        'type': checkin.type.name,
        'name': checkin.name,
        'location': checkin.location,
        'link': checkin.link,
        'checkinDate': checkin.checkinDate,
        'checkinTime': checkin.checkinTime,
        'checkoutDate': checkin.checkoutDate,
        'checkoutTime': checkin.checkoutTime,
        'geoPoint': location,
        'geohash': geohash,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update user's currentCheckin pointer
      await _firestore.collection('users').doc(uid).update({
        'currentCheckin': docRef.id,
      });

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create check-in: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Read / Stream
  // ---------------------------------------------------------------------------

  /// Streams all check-ins belonging to the current user, newest first.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamUserCheckins() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _checkinsRef
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Returns a single check-in document by [checkinId].
  Future<DocumentSnapshot<Map<String, dynamic>>> getCheckin(
      String checkinId) async {
    try {
      return await _checkinsRef.doc(checkinId).get();
    } catch (e) {
      throw Exception('Failed to get check-in: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Nearby / active check-ins
  // ---------------------------------------------------------------------------

  /// Fetches active check-ins near a location using [geohashPrefix].
  ///
  /// Excludes the current user's own check-ins.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      getActiveCheckinsNearby({
    required String geohashPrefix,
    int limit = 50,
  }) async {
    final uid = _auth.currentUser?.uid;

    try {
      final querySnapshot = await _checkinsRef
          .where('isActive', isEqualTo: true)
          .where('geohash', isGreaterThanOrEqualTo: geohashPrefix)
          .where('geohash', isLessThan: '$geohashPrefix\uf8ff')
          .limit(limit)
          .get();

      return querySnapshot.docs
          .where((doc) => doc.data()['userId'] != uid)
          .toList();
    } catch (e) {
      throw Exception('Failed to get nearby check-ins: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Update – checkout
  // ---------------------------------------------------------------------------

  /// Marks the check-in [checkinId] as inactive and clears the user's
  /// `currentCheckin` pointer.
  Future<void> markCheckinInactive(String checkinId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not signed in');

    try {
      final batch = _firestore.batch();

      batch.update(_checkinsRef.doc(checkinId), {
        'isActive': false,
      });

      batch.update(_firestore.collection('users').doc(uid), {
        'currentCheckin': null,
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to mark check-in as inactive: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  /// Permanently deletes the check-in [checkinId] and clears the user's
  /// `currentCheckin` pointer if it matches.
  Future<void> deleteCheckin(String checkinId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not signed in');

    try {
      await _checkinsRef.doc(checkinId).delete();

      // Clear the pointer only if it still references this check-in
      final userDoc =
          await _firestore.collection('users').doc(uid).get();
      if (userDoc.data()?['currentCheckin'] == checkinId) {
        await _firestore.collection('users').doc(uid).update({
          'currentCheckin': null,
        });
      }
    } catch (e) {
      throw Exception('Failed to delete check-in: $e');
    }
  }
}
