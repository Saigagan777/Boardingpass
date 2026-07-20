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

Future<LinkedInMobileOAuthResult?> startLinkedInMobileOAuth() {
  throw UnsupportedError('Native LinkedIn authentication is only available on mobile.');
}
