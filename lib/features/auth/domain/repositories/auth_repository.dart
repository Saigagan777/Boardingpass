import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/oauth/linkedin_oauth_config.dart';
import '../../data/oauth/linkedin_oauth_manager.dart';
import '../../data/sources/linkedin_auth_api.dart';
import '../../data/sources/secure_session_store.dart';
import '../models/auth_models.dart';

/// High-level LinkedIn sign-in / logout orchestration.
abstract class AuthRepository {
  Future<AuthUser> signInWithLinkedIn();
  Future<AuthUser> completeLinkedInCallback(Uri callbackUri);
  Future<void> signOut();
  Future<void> fullLogout();
  Future<bool> hasPendingLinkedInOAuth();
}

class LinkedInAuthRepository implements AuthRepository {
  /// Shared instance so the deep-link handler completes the same PKCE wait
  /// started by the Continue with LinkedIn button.
  static final LinkedInAuthRepository instance = LinkedInAuthRepository._();

  factory LinkedInAuthRepository({
    LinkedInOAuthManager? oauthManager,
    SecureSessionStore? sessionStore,
    LinkedInAuthApi? api,
    FirebaseAuth? firebaseAuth,
  }) {
    if (oauthManager != null ||
        sessionStore != null ||
        api != null ||
        firebaseAuth != null) {
      return LinkedInAuthRepository._(
        oauthManager: oauthManager,
        sessionStore: sessionStore,
        api: api,
        firebaseAuth: firebaseAuth,
      );
    }
    return instance;
  }

  LinkedInAuthRepository._({
    LinkedInOAuthManager? oauthManager,
    SecureSessionStore? sessionStore,
    LinkedInAuthApi? api,
    FirebaseAuth? firebaseAuth,
  })  : _oauth = oauthManager ?? LinkedInOAuthManager(),
        _store = sessionStore ?? SecureSessionStore(),
        _api = api ?? LinkedInAuthApi(),
        _auth = firebaseAuth ?? FirebaseAuth.instance;

  final LinkedInOAuthManager _oauth;
  final SecureSessionStore _store;
  final LinkedInAuthApi _api;
  final FirebaseAuth _auth;

  Completer<AuthUser>? _mobileWaiter;
  Timer? _mobileTimeout;

  /// Starts LinkedIn OAuth.
  ///
  /// - **Web:** redirects the current tab to LinkedIn; completion happens when
  ///   the app reloads with `?code=` and [completeLinkedInCallback] / main.dart runs.
  /// - **Mobile:** opens the system browser (cookie jar shared with LinkedIn app /
  ///   Chrome) and waits for the `nexmeet://oauth/linkedin` deep link.
  @override
  Future<AuthUser> signInWithLinkedIn() async {
    await _store.clearPendingOAuth();
    _cancelMobileWaiter(error: null);

    final redirectUri = _oauth.resolveRedirectUri();
    final session = _oauth.createSession(redirectUri: redirectUri);

    await _store.savePendingOAuth(
      codeVerifier: session.codeVerifier,
      state: session.state,
      nonce: session.nonce,
      redirectUri: session.redirectUri,
    );

    if (kIsWeb) {
      final opened = await launchUrl(
        session.authorizationUrl,
        webOnlyWindowName: '_self',
      );
      if (!opened) {
        await _store.clearPendingOAuth();
        throw const LinkedInOAuthException(
          'Could not open LinkedIn sign-in.',
          code: 'launch_failed',
        );
      }
      // Page navigates away; caller should treat this as "in progress".
      throw const LinkedInOAuthException(
        'Redirecting to LinkedIn…',
        code: 'web_redirect',
      );
    }

    final opened = await launchUrl(
      session.authorizationUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      await _store.clearPendingOAuth();
      throw const LinkedInOAuthException(
        'Could not open LinkedIn sign-in.',
        code: 'launch_failed',
      );
    }

    final completer = Completer<AuthUser>();
    _mobileWaiter = completer;
    _mobileTimeout?.cancel();
    _mobileTimeout = Timer(const Duration(minutes: 3), () {
      if (!completer.isCompleted) {
        completer.completeError(
          const LinkedInOAuthException(
            'LinkedIn sign-in timed out. Please try again.',
            code: 'timeout',
          ),
        );
      }
      _mobileWaiter = null;
    });

    try {
      return await completer.future;
    } catch (e) {
      await _store.clearPendingOAuth();
      rethrow;
    } finally {
      _mobileTimeout?.cancel();
      _mobileTimeout = null;
      if (identical(_mobileWaiter, completer)) {
        _mobileWaiter = null;
      }
    }
  }

  /// Called when a deep link or web redirect returns from LinkedIn.
  @override
  Future<AuthUser> completeLinkedInCallback(Uri callbackUri) async {
    final pending = await _store.readPendingOAuth();
    if (pending == null) {
      throw const LinkedInOAuthException(
        'No pending LinkedIn sign-in. Please try again.',
        code: 'no_pending_session',
      );
    }
    if (pending.isExpired) {
      await _store.clearPendingOAuth();
      throw const LinkedInOAuthException(
        'Sign-in expired. Please try again.',
        code: 'session_expired',
      );
    }

    final error = callbackUri.queryParameters['error'];
    if (error != null && error.isNotEmpty) {
      await _store.clearPendingOAuth();
      final description =
          callbackUri.queryParameters['error_description'] ?? error;
      final code = error == 'access_denied' ? 'access_denied' : 'linkedin_error';
      final message = error == 'access_denied'
          ? 'LinkedIn permission was denied. You can try again when ready.'
          : 'LinkedIn login failed: $description';
      final ex = LinkedInOAuthException(message, code: code);
      _completeMobileWaiterError(ex);
      throw ex;
    }

    final returnedState = callbackUri.queryParameters['state'];
    try {
      _oauth.assertValidCallback(
        returnedState: returnedState,
        expectedState: pending.state,
      );
    } catch (e) {
      await _store.clearPendingOAuth();
      _completeMobileWaiterError(e);
      rethrow;
    }

    final code = callbackUri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      await _store.clearPendingOAuth();
      final ex = const LinkedInOAuthException(
        'LinkedIn did not return an authorization code.',
        code: 'missing_code',
      );
      _completeMobileWaiterError(ex);
      throw ex;
    }

    try {
      final apiResult = await _api.exchangeCode(
        code: code,
        codeVerifier: pending.codeVerifier,
        redirectUri: pending.redirectUri,
        nonce: pending.nonce,
      );

      // One-time code — clear PKCE material before signing in.
      await _store.clearPendingOAuth();

      final credential =
          await _auth.signInWithCustomToken(apiResult.customToken);
      final user = credential.user;
      if (user == null) {
        throw const LinkedInOAuthException(
          'Firebase sign-in failed after LinkedIn verification.',
          code: 'firebase_sign_in_failed',
        );
      }

      final authUser = AuthUser.fromMap({
        ...apiResult.user,
        'uid': user.uid,
      });

      if (_mobileWaiter != null && !(_mobileWaiter!.isCompleted)) {
        _mobileWaiter!.complete(authUser);
      }
      return authUser;
    } catch (e) {
      await _store.clearPendingOAuth();
      _completeMobileWaiterError(e);
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _store.clearPendingOAuth();
    await _auth.signOut();
  }

  /// Revokes LinkedIn tokens stored on the server (if any), then clears the
  /// local Firebase session. Does **not** sign the user out of LinkedIn in the
  /// system browser; open LinkedIn's logout page for a true full SSO reset.
  @override
  Future<void> fullLogout() async {
    try {
      await _api.fullLogoutLinkedIn();
    } catch (e) {
      debugPrint('fullLogoutLinkedIn: $e');
    }
    await _store.clearPendingOAuth();
    await _auth.signOut();

    // Best-effort: open LinkedIn logout so the next Continue with LinkedIn
    // requires credentials. Optional and may be blocked by the OS.
    try {
      final logoutUri = Uri.parse('https://www.linkedin.com/m/logout');
      await launchUrl(logoutUri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Future<bool> hasPendingLinkedInOAuth() async {
    final pending = await _store.readPendingOAuth();
    return pending != null && !pending.isExpired;
  }

  /// Whether [uri] is a LinkedIn OAuth callback the app should handle.
  static bool isLinkedInCallback(Uri uri) {
    final q = uri.queryParameters;
    final hasOAuthParams = q.containsKey('code') || q.containsKey('error');
    if (!hasOAuthParams) return false;

    if (uri.scheme == LinkedInOAuthConfig.appDeepLinkScheme &&
        uri.host == LinkedInOAuthConfig.appDeepLinkHost) {
      return true;
    }

    // HTTPS Hosting bridge claimed via App Links / Universal Links.
    if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.path.contains('/oauth/linkedin/callback')) {
      return true;
    }

    // Web SPA: LinkedIn redirects to origin with ?code=&state=
    if (kIsWeb && (q.containsKey('state') || q.containsKey('linkedin_oauth'))) {
      return true;
    }

    return false;
  }

  void _completeMobileWaiterError(Object error) {
    final waiter = _mobileWaiter;
    if (waiter != null && !waiter.isCompleted) {
      waiter.completeError(error);
    }
  }

  void _cancelMobileWaiter({Object? error}) {
    final waiter = _mobileWaiter;
    if (waiter != null && !waiter.isCompleted) {
      waiter.completeError(
        error ??
            const LinkedInOAuthException(
              'Sign-in cancelled.',
              code: 'cancelled',
            ),
      );
    }
    _mobileWaiter = null;
    _mobileTimeout?.cancel();
    _mobileTimeout = null;
  }
}
