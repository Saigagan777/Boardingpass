import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';
import 'linkedin_oauth_config.dart';
import 'linkedin_secret.dart';

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
    String? industry,
    String? experience,
    String? homeBase,
    String? currentLocationName,
    String? travelFrequency,
    String? cardImageUrl,
    String? profileImageUrl,
    List<String>? cardImages,
    List<CustomCard>? customCards,
    int? connectionsCount,
    int? eventsJoinedCount,
    int? eventsHostedCount,
    List<String>? expertise,
    List<String>? intents,
    bool? isDiscoverable,
    String? coverImageUrl,
    String? linkedinProfileUrl,
    int? connectionCount,
    int? followerCount,
    List<String>? skills,
    List<String>? interests,
    List<String>? followedTopics,
    List<String>? professionalInterests,
    List<Map<String, dynamic>>? careerTimeline,
    List<Map<String, dynamic>>? educationTimeline,
    Map<String, dynamic>? notificationSettings,
    List<Map<String, dynamic>>? expertiseWithLevel,
    List<Map<String, dynamic>>? interestsWithPriority,
    List<String>? badges,
    int? completedMentoringSessions,
    int? successfulCollaborations,
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
      if (industry != null) updates['industry'] = industry;
      if (experience != null) updates['experience'] = experience;
      if (homeBase != null) updates['homeBase'] = homeBase;
      if (currentLocationName != null) updates['currentLocationName'] = currentLocationName;
      if (travelFrequency != null) updates['travelFrequency'] = travelFrequency;
      if (cardImageUrl != null) updates['cardImageUrl'] = cardImageUrl;
      if (profileImageUrl != null) updates['profileImageUrl'] = profileImageUrl;
      if (cardImages != null) updates['cardImages'] = cardImages;
      if (customCards != null) {
        updates['customCards'] = customCards.map((c) => c.toMap()).toList();
      }
      if (connectionsCount != null) updates['connectionsCount'] = connectionsCount;
      if (eventsJoinedCount != null) updates['eventsJoinedCount'] = eventsJoinedCount;
      if (eventsHostedCount != null) updates['eventsHostedCount'] = eventsHostedCount;
      if (expertise != null) updates['expertise'] = expertise;
      if (intents != null) updates['intents'] = intents;
      if (isDiscoverable != null) updates['isDiscoverable'] = isDiscoverable;
      
      // New LinkedIn and Notification Fields
      if (coverImageUrl != null) updates['coverImageUrl'] = coverImageUrl;
      if (linkedinProfileUrl != null) updates['linkedinProfileUrl'] = linkedinProfileUrl;
      if (connectionCount != null) updates['connectionCount'] = connectionCount;
      if (followerCount != null) updates['followerCount'] = followerCount;
      if (skills != null) updates['skills'] = skills;
      if (interests != null) updates['interests'] = interests;
      if (followedTopics != null) updates['followedTopics'] = followedTopics;
      if (professionalInterests != null) updates['professionalInterests'] = professionalInterests;
      if (careerTimeline != null) updates['careerTimeline'] = careerTimeline;
      if (educationTimeline != null) updates['educationTimeline'] = educationTimeline;
      if (notificationSettings != null) updates['notificationSettings'] = notificationSettings;
      if (expertiseWithLevel != null) updates['expertiseWithLevel'] = expertiseWithLevel;
      if (interestsWithPriority != null) updates['interestsWithPriority'] = interestsWithPriority;
      if (badges != null) updates['badges'] = badges;
      if (completedMentoringSessions != null) updates['completedMentoringSessions'] = completedMentoringSessions;
      if (successfulCollaborations != null) updates['successfulCollaborations'] = successfulCollaborations;

      await _usersRef
          .doc(userId)
          .set(updates, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
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

  /// Exchanges a LinkedIn authorization code for an access token, fetches
  /// real profile data from LinkedIn's OpenID Connect endpoint, and updates
  /// the user's Firestore document with ONLY the data LinkedIn actually provides.
  Future<void> syncLinkedInProfile(String userId, String authCode, {String? redirectUri}) async {
    try {
      final String clientId = LinkedInOAuthConfig.clientId;
      final String clientSecret = linkedinClientSecret;
      final String finalRedirectUri = redirectUri ?? LinkedInOAuthConfig.redirectUri;

      // 1. Exchange authorization code for access token
      final String tokenUri = kIsWeb
          ? 'https://corsproxy.io/?url=${Uri.encodeComponent('https://www.linkedin.com/oauth/v2/accessToken')}'
          : 'https://www.linkedin.com/oauth/v2/accessToken';

      final tokenResponse = await http
          .post(
            Uri.parse(tokenUri),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: 'grant_type=authorization_code'
                '&code=${Uri.encodeComponent(authCode)}'
                '&redirect_uri=${Uri.encodeComponent(finalRedirectUri)}'
                '&client_id=${Uri.encodeComponent(clientId)}'
                '&client_secret=${Uri.encodeComponent(clientSecret)}',
          )
          .timeout(const Duration(seconds: 10));

      if (tokenResponse.statusCode != 200) {
        throw Exception(
          'Failed to exchange LinkedIn token: ${tokenResponse.body}',
        );
      }

      final tokenData = jsonDecode(tokenResponse.body);
      final String accessToken = tokenData['access_token'];

      // 2. Fetch real user info from LinkedIn OpenID Connect endpoint
      final String userInfoUri = kIsWeb
          ? 'https://corsproxy.io/?url=${Uri.encodeComponent('https://api.linkedin.com/v2/userinfo')}'
          : 'https://api.linkedin.com/v2/userinfo';

      final userInfoResponse = await http
          .get(
            Uri.parse(userInfoUri),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(const Duration(seconds: 10));

      if (userInfoResponse.statusCode != 200) {
        throw Exception(
          'Failed to fetch LinkedIn user info: ${userInfoResponse.body}',
        );
      }

      final userInfo = jsonDecode(userInfoResponse.body);
      final String email = userInfo['email'] ?? '';
      final String name = userInfo['name'] ??
          '${userInfo['given_name'] ?? ''} ${userInfo['family_name'] ?? ''}'.trim();
      final String picture = userInfo['picture'] ?? '';
      final String sub = userInfo['sub'] ?? '';
      final String profileUrl = userInfo['profile'] ?? '';

      // 3. Build update map with ONLY real LinkedIn data
      final updates = <String, dynamic>{
        'linkedinSynced': true,
        'linkedinSyncedAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      };

      if (name.isNotEmpty) updates['name'] = name;
      if (email.isNotEmpty) updates['email'] = email;
      if (picture.isNotEmpty) updates['profileImageUrl'] = picture;
      if (profileUrl.isNotEmpty) updates['linkedinProfileUrl'] = profileUrl;
      if (sub.isNotEmpty) {
        updates['linkedinId'] = sub;
      }

      // 4. Update Firestore profile with real data
      await _usersRef.doc(userId).update(updates);

      debugPrint('LinkedIn profile synced successfully for user $userId');
    } catch (e) {
      throw Exception('Failed to sync LinkedIn profile: $e');
    }
  }

  /// Legacy compatibility wrapper — redirects to the profile screen
  /// to trigger the real OAuth flow.
  @Deprecated('Use syncLinkedInProfile with a real auth code instead')
  Future<void> enrichUserProfileWithLinkedIn(String userId) async {
    throw UnimplementedError(
      'Mock LinkedIn enrichment has been removed. '
      'Use syncLinkedInProfile() with a real LinkedIn authorization code.',
    );
  }
}
