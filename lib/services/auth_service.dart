import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

/// Singleton service handling all Firebase Authentication operations.
///
/// Supports email/password sign-up and sign-in, LinkedIn OIDC login (stub),
/// admin detection via custom claims with an email fallback for development,
/// and automatic Firestore user-profile creation on first login.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Dev-mode admin email – bypasses custom-claims check.
  static const String _devAdminEmail = 'Gagan@gmail.com';

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
  /// Firestore profile for the user.
  ///
  /// Returns the created [UserCredential].
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name on the Firebase Auth record
      await credential.user?.updateDisplayName(name);

      // Create a Firestore profile document for the new user
      if (credential.user != null) {
        await _createUserProfile(
          uid: credential.user!.uid,
          name: name,
          email: email,
        );
      }

      return credential;
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
        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .update({'lastSeen': FieldValue.serverTimestamp()});
      }

      return credential;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Sign-in failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // LinkedIn OIDC login (stub)
  // ---------------------------------------------------------------------------

  /// Signs in with LinkedIn using OpenID Connect.
  ///
  /// **Not yet implemented** – requires a LinkedIn Developer App and
  /// server-side token exchange.
  // TODO: Implement LinkedIn OIDC login once the LinkedIn Developer App is set up.
  //  1. Launch a web-view / custom-tab to LinkedIn's authorization endpoint.
  //  2. Exchange the authorization code for an ID token on your backend.
  //  3. Call `_auth.signInWithCredential(OAuthProvider('oidc.linkedin').credential(...))`.
  //  4. Create the Firestore profile on first login.
  Future<UserCredential?> signInWithLinkedIn() async {
    // TODO: Replace this stub with real LinkedIn OIDC flow.
    throw UnimplementedError(
      'LinkedIn OIDC login is not yet configured. '
      'Set up a LinkedIn Developer App and implement the OIDC flow.',
    );
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
      if (user.email?.toLowerCase() == _devAdminEmail.toLowerCase()) {
        return true;
      }

      return false;
    } catch (e) {
      // If claims fetch fails, fall back to email check only
      return user.email?.toLowerCase() == _devAdminEmail.toLowerCase();
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
      final doc =
          await _firestore.collection('users').doc(user.uid).get();
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
