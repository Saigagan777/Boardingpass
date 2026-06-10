import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';

/// Singleton service for Firestore `users` collection operations.
///
/// Provides CRUD helpers for user profiles, location updates,
/// FCM token management, geohash-based proximity queries, and
/// expertise/intent search.
class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Reference to the `users` collection.
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  /// Creates a new user profile document in Firestore.
  ///
  /// Typically called once during sign-up; see also [AuthService].
  Future<void> createUserProfile(UserProfile profile) async {
    try {
      await _usersRef.doc(profile.uid).set(profile.toFirestore());
    } catch (e) {
      throw Exception('Failed to create user profile: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Fetches the [UserProfile] for the given [userId], or `null` if not found.
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final doc = await _usersRef.doc(userId).get();
      if (doc.exists) {
        return UserProfile.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }

  /// Returns a real-time stream of profile changes for [userId].
  Stream<UserProfile?> streamUserProfile(String userId) {
    return _usersRef.doc(userId).snapshots().map((doc) {
      if (doc.exists) {
        return UserProfile.fromFirestore(doc);
      }
      return null;
    });
  }

  /// Convenience – streams the *current* signed-in user's profile.
  Stream<UserProfile?> streamCurrentUserProfile() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return streamUserProfile(uid);
  }

  // ---------------------------------------------------------------------------
  // Update – general profile fields
  // ---------------------------------------------------------------------------

  /// Updates editable profile fields for the given [userId].
  ///
  /// Only non-null parameters are written; pass `null` to leave a field
  /// unchanged.
  Future<void> updateUserProfile({
    required String userId,
    String? name,
    String? bio,
    String? headline,
    String? company,
    String? role,
    List<String>? expertise,
    List<String>? intents,
    bool? isDiscoverable,
  }) async {
    try {
      final updates = <String, dynamic>{
        'lastSeen': FieldValue.serverTimestamp(),
      };

      if (name != null) updates['name'] = name;
      if (bio != null) updates['bio'] = bio;
      if (headline != null) updates['headline'] = headline;
      if (company != null) updates['company'] = company;
      if (role != null) updates['role'] = role;
      if (expertise != null) updates['expertise'] = expertise;
      if (intents != null) updates['intents'] = intents;
      if (isDiscoverable != null) updates['isDiscoverable'] = isDiscoverable;

      await _usersRef.doc(userId).update(updates);
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Update – location
  // ---------------------------------------------------------------------------

  /// Updates the user's current [location] and its [geohash] in Firestore.
  Future<void> updateUserLocation({
    required String userId,
    required GeoPoint location,
    required String geohash,
  }) async {
    try {
      await _usersRef.doc(userId).update({
        'location': location,
        'geohash': geohash,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update user location: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Update – FCM token
  // ---------------------------------------------------------------------------

  /// Stores the FCM push-notification [token] for the given [userId].
  Future<void> updateFcmToken({
    required String userId,
    required String token,
  }) async {
    try {
      await _usersRef.doc(userId).update({'fcmToken': token});
    } catch (e) {
      throw Exception('Failed to update FCM token: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Proximity – nearby users
  // ---------------------------------------------------------------------------

  /// Returns users whose geohash starts with [geohashPrefix].
  ///
  /// Uses Firestore string range queries to approximate geospatial proximity.
  /// A longer prefix yields a tighter radius.  For best results, use 4-6
  /// character prefixes.
  ///
  /// The current user is excluded from results.
  Future<List<UserProfile>> getNearbyUsers({
    required String geohashPrefix,
    int limit = 50,
  }) async {
    try {
      final currentUid = _auth.currentUser?.uid;

      final querySnapshot = await _usersRef
          .where('isDiscoverable', isEqualTo: true)
          .where('geohash', isGreaterThanOrEqualTo: geohashPrefix)
          .where('geohash', isLessThan: '$geohashPrefix\uf8ff')
          .limit(limit)
          .get();

      return querySnapshot.docs
          .where((doc) => doc.id != currentUid)
          .map((doc) => UserProfile.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get nearby users: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Search – expertise / intents
  // ---------------------------------------------------------------------------

  /// Searches for users whose [expertise] list contains [query].
  Future<List<UserProfile>> searchByExpertise(String query) async {
    try {
      final querySnapshot = await _usersRef
          .where('expertise', arrayContains: query.toLowerCase())
          .where('isDiscoverable', isEqualTo: true)
          .limit(30)
          .get();

      return querySnapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to search users by expertise: $e');
    }
  }

  /// Searches for users whose [intents] list contains [query].
  Future<List<UserProfile>> searchByIntents(String query) async {
    try {
      final querySnapshot = await _usersRef
          .where('intents', arrayContains: query.toLowerCase())
          .where('isDiscoverable', isEqualTo: true)
          .limit(30)
          .get();

      return querySnapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to search users by intents: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------

  /// Updates the `lastSeen` timestamp for [userId] to the server time.
  Future<void> touchLastSeen(String userId) async {
    try {
      await _usersRef.doc(userId).update({
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Non-critical; swallow silently in production.
      throw Exception('Failed to update lastSeen: $e');
    }
  }
}
