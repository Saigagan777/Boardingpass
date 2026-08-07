import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists short-lived PKCE / OAuth handshake material until the callback returns.
///
/// Never stores LinkedIn access tokens or the client secret.
class SecureSessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kVerifier = 'linkedin_pkce_code_verifier';
  static const _kState = 'linkedin_oauth_state';
  static const _kNonce = 'linkedin_oauth_nonce';
  static const _kRedirect = 'linkedin_oauth_redirect_uri';
  static const _kStartedAt = 'linkedin_oauth_started_at';

  Future<void> savePendingOAuth({
    required String codeVerifier,
    required String state,
    required String nonce,
    required String redirectUri,
  }) async {
    await Future.wait([
      _storage.write(key: _kVerifier, value: codeVerifier),
      _storage.write(key: _kState, value: state),
      _storage.write(key: _kNonce, value: nonce),
      _storage.write(key: _kRedirect, value: redirectUri),
      _storage.write(
        key: _kStartedAt,
        value: DateTime.now().toUtc().toIso8601String(),
      ),
    ]);
  }

  Future<PendingOAuthSession?> readPendingOAuth() async {
    final verifier = await _storage.read(key: _kVerifier);
    final state = await _storage.read(key: _kState);
    final nonce = await _storage.read(key: _kNonce);
    final redirect = await _storage.read(key: _kRedirect);
    final startedAtRaw = await _storage.read(key: _kStartedAt);

    if (verifier == null ||
        state == null ||
        nonce == null ||
        redirect == null) {
      return null;
    }

    DateTime? startedAt;
    if (startedAtRaw != null) {
      startedAt = DateTime.tryParse(startedAtRaw);
    }

    return PendingOAuthSession(
      codeVerifier: verifier,
      state: state,
      nonce: nonce,
      redirectUri: redirect,
      startedAt: startedAt,
    );
  }

  Future<void> clearPendingOAuth() async {
    await Future.wait([
      _storage.delete(key: _kVerifier),
      _storage.delete(key: _kState),
      _storage.delete(key: _kNonce),
      _storage.delete(key: _kRedirect),
      _storage.delete(key: _kStartedAt),
      // Legacy keys from the previous client-side flow.
      _storage.delete(key: 'linkedin_sync_pending_uid'),
    ]);
  }
}

class PendingOAuthSession {
  const PendingOAuthSession({
    required this.codeVerifier,
    required this.state,
    required this.nonce,
    required this.redirectUri,
    this.startedAt,
  });

  final String codeVerifier;
  final String state;
  final String nonce;
  final String redirectUri;
  final DateTime? startedAt;

  /// Authorization codes are short-lived; abandon stale handshakes.
  bool get isExpired {
    if (startedAt == null) return false;
    return DateTime.now().toUtc().difference(startedAt!) >
        const Duration(minutes: 10);
  }
}
