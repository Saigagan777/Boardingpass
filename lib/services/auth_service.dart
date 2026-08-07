import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../features/auth/data/oauth/linkedin_oauth_manager.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../models/user_profile.dart';

/// Singleton service handling all Firebase Authentication operations.
///
/// Supports email/password sign-up and sign-in, LinkedIn OIDC login
/// (PKCE + Cloud Function custom token), admin detection via custom claims
/// with an email fallback for development, and automatic Firestore
/// user-profile creation on first login.
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
    List<String> profileImages = const [],
    String? phone,
    String? phoneCountryCode,
    String? dob,
    String? gender,
    String? occupation,
    String? profession,
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
        // The user might have been created with a temporary password during
        // the email verification step. Update it to the real password they chose.
        try {
          await user.updatePassword(password);
        } catch (e) {
          debugPrint('Could not update password (might already be correct): $e');
        }
      } else if (signedInUser != null &&
          (signedInUser.isAnonymous || (signedInUser.email?.isEmpty ?? true))) {
        // The current user is a phone-only (or anonymous) account created
        // during phone verification — attach email + password to the same
        // account instead of creating a second one.
        await signedInUser.linkWithCredential(
          EmailAuthProvider.credential(email: email, password: password),
        );
        user = signedInUser;
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
          dob: dob,
          gender: gender,
          occupation: occupation,
          profession: profession,
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
          profileImages: profileImages,
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

      // Email verification is disabled (product decision) — the verification
      // email is no longer sent. Uncomment to re-enable:
      // if (!user.emailVerified) {
      //   try {
      //     await user.sendEmailVerification();
      //   } catch (e) {
      //     debugPrint('Failed to send email verification: $e');
      //   }
      // }

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
  // LinkedIn OIDC login (PKCE + Cloud Function)
  // ---------------------------------------------------------------------------

  /// Starts the LinkedIn OAuth flow (system browser on mobile, redirect on web).
  ///
  /// On mobile, waits for the deep-link callback. On web, throws
  /// [LinkedInOAuthException] with code `web_redirect` after navigating away.
  Future<UserCredential?> signInWithLinkedInInteractive() async {
    final repo = LinkedInAuthRepository.instance;
    final authUser = await repo.signInWithLinkedIn();
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('LinkedIn sign-in completed but no Firebase user is present.');
    }
    await _ensureAccessAllowed(user);
    debugPrint(
      'LinkedIn sign-in ok uid=${authUser.uid} email=${authUser.email}',
    );
    return null; // Session already established via custom token.
  }

  /// Completes LinkedIn OAuth after a redirect / deep link containing `code`.
  Future<UserCredential?> completeLinkedInSignIn(Uri callbackUri) async {
    final repo = LinkedInAuthRepository.instance;
    await repo.completeLinkedInCallback(callbackUri);
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('LinkedIn callback completed but no Firebase user is present.');
    }
    await _ensureAccessAllowed(user);
    return null;
  }

  /// @deprecated Use [signInWithLinkedInInteractive] or [completeLinkedInSignIn].
  Future<UserCredential?> signInWithLinkedIn(
    String code, {
    String? redirectUri,
    String? codeVerifier,
  }) async {
    throw const LinkedInOAuthException(
      'LinkedIn sign-in must use the PKCE flow. Tap Continue with LinkedIn again.',
      code: 'legacy_flow_disabled',
    );
  }

  // ---------------------------------------------------------------------------
  // Phone Verification
  // ---------------------------------------------------------------------------

  /// Initiates phone number verification using Firebase.
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      forceResendingToken: forceResendingToken,
    );
  }

  // ---------------------------------------------------------------------------
  // Sign-out
  // ---------------------------------------------------------------------------

  /// Signs out the current user from Firebase Auth.
  ///
  /// Does **not** revoke the LinkedIn browser session, so the next
  /// Continue with LinkedIn can reuse LinkedIn SSO (like Google Sign-In).
  Future<void> signOut() async {
    try {
      await LinkedInAuthRepository.instance.signOut();
    } catch (e) {
      try {
        await _auth.signOut();
      } catch (_) {}
      throw Exception('Sign-out failed: $e');
    }
  }

  /// Full logout: revoke server-stored LinkedIn tokens (if any), clear local
  /// session, and best-effort open LinkedIn logout in the browser.
  Future<void> fullLogout() async {
    await LinkedInAuthRepository.instance.fullLogout();
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
      // Check custom claims first (reading from cache if offline/slow)
      final idTokenResult = await user.getIdTokenResult(false);
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
      final snapshot = await docRef.get();

      if (!snapshot.exists) {
        final profile = UserProfile(
          uid: uid,
          name: name,
          email: email,
          createdAt: DateTime.now(),
          lastSeen: DateTime.now(),
          onboardingCompleted: false,
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

/// Thrown when a LinkedIn sign-in cannot proceed because of an account conflict.
class LinkedInAccountConflictException implements Exception {
  const LinkedInAccountConflictException(this.message);

  final String message;

  @override
  String toString() => message;
}
