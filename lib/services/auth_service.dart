import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import 'linkedin_oauth_config.dart';
import 'linkedin_secret.dart';

/// Singleton service handling all Firebase Authentication operations.
///
/// Supports email/password sign-up and sign-in, LinkedIn OIDC login,
/// admin detection via custom claims with an email fallback for development,
/// and automatic Firestore user-profile creation on first login.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Dev-mode admin emails – bypasses custom-claims check.
  static const List<String> _devAdminEmails = [
    'gagan123@gmail.com',
    'gagan90@gmail.com',
  ];

  // ---------------------------------------------------------------------------
  // Auth state
  // ---------------------------------------------------------------------------

  /// The currently signed-in Firebase user, or `null`.
  User? get currentUser => _auth.currentUser;

  /// A real-time stream of authentication state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Whether a user is currently signed in.
  bool get isSignedIn => _auth.currentUser != null;

  // ---------------------------------------------------------------------------
  // Email / password authentication
  // ---------------------------------------------------------------------------

  /// Creates a new account with [email] and [password], then writes an initial
  /// Firestore profile with professional details. If the account was created
  /// in the first onboarding step, reuses that signed-in user.
  ///
  /// Returns the created or existing [User].
  Future<User> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    String? headline,
    String? company,
    String? role,
    String? bio,
    String? industry,
    String? experience,
    String? homeBase,
    String? currentLocationName,
    String? travelFrequency,
    String? profileImageUrl,
    String? phone,
    String? phoneCountryCode,
    List<String> expertise = const [],
    List<String> intents = const [],
    List<String> skills = const [],
    List<String> interests = const [],
    List<Map<String, dynamic>> careerTimeline = const [],
    List<Map<String, dynamic>> educationTimeline = const [],
    String? linkedinProfileUrl,
    List<Map<String, dynamic>> expertiseWithLevel = const [],
    List<Map<String, dynamic>> interestsWithPriority = const [],
    List<String> badges = const [],
  }) async {
    try {
      final signedInUser = _auth.currentUser;
      final isSameAccount = signedInUser?.email?.toLowerCase() ==
          email.toLowerCase();
      final User user;

      if (isSameAccount) {
        user = signedInUser!;
      } else {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        user = credential.user!;
      }

      // Update display name on the Firebase Auth record
      try {
        await user.updateDisplayName(name);
      } catch (e) {
        debugPrint('Auth updateDisplayName skipped: $e');
      }

      if (profileImageUrl != null && profileImageUrl.isNotEmpty && profileImageUrl.length < 2000 && !profileImageUrl.startsWith('data:')) {
        try {
          await user.updatePhotoURL(profileImageUrl);
        } catch (e) {
          debugPrint('Auth updatePhotoURL skipped: $e');
        }
      }

      // Create a Firestore profile document for the new user
      final profile = UserProfile(
          uid: user.uid,
          name: name,
          email: email,
          phone: phone,
          phoneCountryCode: phoneCountryCode,
          headline: headline,
          company: company,
          role: role,
          bio: bio,
          industry: industry,
          experience: experience,
          homeBase: homeBase,
          currentLocationName: currentLocationName,
          travelFrequency: travelFrequency,
          profileImageUrl: profileImageUrl,
          expertise: expertise,
          intents: intents,
          skills: skills,
          interests: interests,
          careerTimeline: careerTimeline,
          educationTimeline: educationTimeline,
          linkedinProfileUrl: linkedinProfileUrl,
          createdAt: DateTime.now(),
          lastSeen: DateTime.now(),
          expertiseWithLevel: expertiseWithLevel,
          interestsWithPriority: interestsWithPriority,
          badges: badges,
          hasCompletedFeatureTour: false,
        );
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(profile.toFirestore())
          .timeout(const Duration(seconds: 8));

      return user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Sign-up failed: $e');
    }
  }

  /// Signs in an existing user with [email] and [password].
  ///
  /// Updates the `lastSeen` timestamp in Firestore on success.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Touch the user's lastSeen timestamp
      if (credential.user != null) {
        await _ensureAccessAllowed(credential.user!);
        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .update({'lastSeen': FieldValue.serverTimestamp()})
            .timeout(const Duration(seconds: 5));
      }

      return credential;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Sign-in failed: $e');
    }
  }

  /// Enforces a moderation restriction in the client session. A Firebase
  /// Admin SDK/Cloud Function is still required to disable the Auth account
  /// itself server-side; this prevents access to the app immediately.
  Future<void> _ensureAccessAllowed(User user) async {
    final profile = await _firestore.collection('users').doc(user.uid).get();
    if (profile.data()?['isLoginRestricted'] == true) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'account-restricted',
        message: 'This account has been restricted by the safety team.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // LinkedIn OIDC login
  // ---------------------------------------------------------------------------

  /// Signs in with LinkedIn using a real OAuth code-to-token exchange and fetches
  /// public profile details from LinkedIn to sign in and save to Firestore.
  Future<UserCredential?> signInWithLinkedIn(
    String code, {
    String? redirectUri,
    String? codeVerifier,
  }) async {
    final String clientId = LinkedInOAuthConfig.clientId;
    final String clientSecret = linkedinClientSecret;
    final String finalRedirectUri =
        redirectUri ?? LinkedInOAuthConfig.redirectUri;

    try {
      // 1. Exchange authorization code for access token
      final String tokenUri = kIsWeb
          ? 'https://corsproxy.io/?url=${Uri.encodeComponent('https://www.linkedin.com/oauth/v2/accessToken')}'
          : 'https://www.linkedin.com/oauth/v2/accessToken';
      final tokenRequestBody = <String, String>{
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': finalRedirectUri,
        'client_id': clientId,
        if (codeVerifier == null) 'client_secret': clientSecret,
        'code_verifier': ?codeVerifier,
      }.entries.map((entry) {
        return '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}';
      }).join('&');
      final tokenResponse = await http
          .post(
            Uri.parse(tokenUri),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: tokenRequestBody,
          )
          .timeout(const Duration(seconds: 10));

      if (tokenResponse.statusCode != 200) {
        throw Exception(
          'Failed to exchange LinkedIn token: ${tokenResponse.body}',
        );
      }

      final tokenData = jsonDecode(tokenResponse.body);
      final String accessToken = tokenData['access_token'];

      // 2. Fetch userinfo using OpenID Connect
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
      final String name =
          userInfo['name'] ??
          '${userInfo['given_name'] ?? 'User'} ${userInfo['family_name'] ?? ''}'
              .trim();
      final String picture = userInfo['picture'] ?? '';
      final String sub = userInfo['sub'] ?? ''; // LinkedIn unique user ID
      final String profileUrl = userInfo['profile'] ?? '';

      if (email.isEmpty) {
        throw Exception('No email address returned from LinkedIn');
      }

      // 3. Authenticate with Firebase using a synthetic email address derived from LinkedIn's unique sub
      // This prevents conflict with users who may have already registered using the same email address
      // with a standard password, while still letting us store their real email in Firestore.
      final String firebaseEmail = 'linkedin_$sub@boardingpass.com';
      final String securePassword = 'linkedin_user_$sub';

      UserCredential credential;
      try {
        credential = await _auth.signInWithEmailAndPassword(
          email: firebaseEmail,
          password: securePassword,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' ||
            e.code == 'invalid-credential' ||
            e.code == 'wrong-password') {
          // Create Firebase User
          credential = await _auth.createUserWithEmailAndPassword(
            email: firebaseEmail,
            password: securePassword,
          );
          await credential.user?.updateDisplayName(name);
        } else {
          rethrow;
        }
      }

      // 4. Save/Update Profile details in Firestore
      if (credential.user != null) {
        await _ensureAccessAllowed(credential.user!);
        final docRef = _firestore.collection('users').doc(credential.user!.uid);
        final snapshot = await docRef.get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 5));

        if (!snapshot.exists) {
          final profile = UserProfile(
            uid: credential.user!.uid,
            name: name,
            email: email, // Store real email in Firestore
            linkedinId: sub, // Store real LinkedIn sub
            profileImageUrl: picture.isNotEmpty ? picture : null,
            linkedinProfileUrl: profileUrl.isNotEmpty ? profileUrl : null,
            linkedinSynced: true,
            createdAt: DateTime.now(),
            lastSeen: DateTime.now(),
            hasCompletedFeatureTour: false,
          );
          await docRef
              .set(profile.toFirestore())
              .timeout(const Duration(seconds: 8));
        } else {
          // Touch profile
          await docRef
              .update({
                'lastSeen': FieldValue.serverTimestamp(),
                'name': name,
                'email': email,
                if (picture.isNotEmpty) 'profileImageUrl': picture,
                if (profileUrl.isNotEmpty) 'linkedinProfileUrl': profileUrl,
                'linkedinId': sub, // Keep linkedinId updated
                'linkedinSynced': true,
                'linkedinSyncedAt': FieldValue.serverTimestamp(),
              })
              .timeout(const Duration(seconds: 5));
        }
      }

      return credential;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('LinkedIn authentication failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Sign-out
  // ---------------------------------------------------------------------------

  /// Signs out the current user from Firebase Auth.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Sign-out failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Admin check
  // ---------------------------------------------------------------------------

  /// Returns `true` if the current user is an admin.
  ///
  /// Priority order:
  /// 1. Firebase Custom Claims (`admin == true`).
  /// 2. Email fallback for development (`Gagan@gmail.com`).
  Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // Check custom claims first
      final idTokenResult = await user.getIdTokenResult(true);
      final claims = idTokenResult.claims;
      if (claims != null && claims['admin'] == true) {
        return true;
      }

      // Dev-mode fallback: match by email (case-insensitive)
      if (user.email != null && _devAdminEmails.contains(user.email!.toLowerCase())) {
        return true;
      }

      return false;
    } catch (e) {
      // If claims fetch fails, fall back to email check only
      return user.email != null && _devAdminEmails.contains(user.email!.toLowerCase());
    }
  }

  // ---------------------------------------------------------------------------
  // Firestore profile helpers
  // ---------------------------------------------------------------------------

  /// Creates an initial [UserProfile] document in Firestore if one does not
  /// already exist for the given [uid].
  Future<void> _createUserProfile({
    required String uid,
    required String name,
    required String email,
  }) async {
    try {
      final docRef = _firestore.collection('users').doc(uid);
      final snapshot = await docRef.get(const GetOptions(source: Source.server));

      if (!snapshot.exists) {
        final profile = UserProfile(
          uid: uid,
          name: name,
          email: email,
          createdAt: DateTime.now(),
          lastSeen: DateTime.now(),
          hasCompletedFeatureTour: false,
        );
        await docRef.set(profile.toFirestore());
      }
    } catch (e) {
      throw Exception('Failed to create user profile: $e');
    }
  }

  /// Ensures a Firestore profile exists for the currently signed-in user.
  ///
  /// Call this after any OAuth sign-in flow to guarantee the profile document
  /// is present.
  Future<void> ensureUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Do not auto-create a profile with a synthetic LinkedIn email.
    // The LinkedIn authentication flow handles creating the profile with the user's real email.
    if (user.email != null &&
        user.email!.startsWith('linkedin_') &&
        user.email!.endsWith('@boardingpass.com')) {
      return;
    }

    await _createUserProfile(
      uid: user.uid,
      name: user.displayName ?? '',
      email: user.email ?? '',
    );
  }

  /// Returns the [UserProfile] for the currently signed-in user, or `null` if
  /// no profile document exists.
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return UserProfile.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch user profile: $e');
    }
  }

  /// Sends a password-reset email to the given [email].
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('Failed to send password reset email: $e');
    }
  }
}
