/// Deprecated: use [LinkedInAuthRepository] / Continue with LinkedIn instead.
///
/// Kept so conditional exports compile. Mobile OAuth now uses the system browser
/// + HTTPS Hosting callback + `nexmeet://` deep link (see features/auth).
library;

class LinkedInMobileOAuthResult {
  const LinkedInMobileOAuthResult({
    required this.code,
    required this.redirectUri,
    required this.codeVerifier,
  });

  final String code;
  final String redirectUri;
  final String codeVerifier;
}

class LinkedInMobileOAuthException implements Exception {
  const LinkedInMobileOAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

@Deprecated('Use LinkedInAuthRepository.signInWithLinkedIn()')
Future<LinkedInMobileOAuthResult?> startLinkedInMobileOAuth() async {
  throw UnsupportedError(
    'Legacy loopback LinkedIn OAuth was replaced by PKCE + Hosting deep links. '
    'Use LinkedInAuthRepository.instance.signInWithLinkedIn().',
  );
}
