import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/auth_models.dart';
import 'linkedin_oauth_config.dart';

/// Generates PKCE material and LinkedIn authorize URLs.
///
/// Does **not** open the browser or call the backend — that lives in the
/// repository / platform launchers so this class stays pure and testable.
class LinkedInOAuthManager {
  LinkedInOAuthManager();

  /// Creates a new OAuth session with code_verifier, S256 challenge, state, nonce.
  OAuthSession createSession({required String redirectUri}) {
    final codeVerifier = _randomUrlSafe(64);
    final codeChallenge = _s256Challenge(codeVerifier);
    final state = _randomUrlSafe(32);
    final nonce = _randomUrlSafe(32);

    final authorizationUrl = Uri.parse(LinkedInOAuthConfig.authorizationEndpoint)
        .replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': LinkedInOAuthConfig.clientId,
        'redirect_uri': redirectUri,
        'state': state,
        'scope': LinkedInOAuthConfig.scope,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'nonce': nonce,
        // Intentionally omit prompt=login so LinkedIn can reuse an existing session.
      },
    );

    return OAuthSession(
      codeVerifier: codeVerifier,
      codeChallenge: codeChallenge,
      state: state,
      nonce: nonce,
      redirectUri: redirectUri,
      authorizationUrl: authorizationUrl,
    );
  }

  /// Redirect URI for the current platform.
  String resolveRedirectUri() {
    if (kIsWeb) {
      final base = Uri.base;
      if (base.hasScheme && base.hasAuthority) {
        // Origin only — LinkedIn redirects to the SPA with ?code=&state=
        return '${base.scheme}://${base.authority}';
      }
      return 'http://localhost:5000';
    }
    return LinkedInOAuthConfig.mobileRedirectUri;
  }

  /// Validates callback [state] against the pending session.
  void assertValidCallback({
    required String? returnedState,
    required String expectedState,
  }) {
    if (returnedState == null || returnedState.isEmpty) {
      throw const LinkedInOAuthException(
        'Missing OAuth state. Please try signing in again.',
        code: 'missing_state',
      );
    }
    if (returnedState != expectedState) {
      throw const LinkedInOAuthException(
        'Sign-in could not be verified (CSRF state mismatch). Please try again.',
        code: 'state_mismatch',
      );
    }
  }

  static String _randomUrlSafe(int byteCount) {
    final random = Random.secure();
    final bytes = List<int>.generate(byteCount, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static String _s256Challenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}

class LinkedInOAuthException implements Exception {
  const LinkedInOAuthException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
