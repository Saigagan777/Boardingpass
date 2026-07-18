import 'package:flutter/foundation.dart';
import 'linkedin_secret.dart';

class LinkedInOAuthConfig {
  static const String clientId = linkedinClientId;
  static const String state = 'boardingpass_linkedin_oauth_state';
  // This fallback is retained for the in-app WebView flow. Native mobile
  // sign-in uses a temporary loopback callback instead (see
  // linkedin_mobile_auth_io.dart), so the code is returned to the app even
  // when the user switches to the LinkedIn app.
  static const String mobileRedirectUri = 'https://www.google.com';
  static const String nativeAuthorizationEndpoint =
      'https://www.linkedin.com/oauth/native-pkce/authorization';

  static String get redirectUri {
    if (!kIsWeb) {
      return mobileRedirectUri;
    }

    final baseUri = Uri.base;
    if (baseUri.hasScheme && baseUri.hasAuthority) {
      return '${baseUri.scheme}://${baseUri.authority}';
    }

    return 'http://localhost:5000';
  }

  static String authorizationUrl({required String redirectUri}) {
    return 'https://www.linkedin.com/oauth/v2/authorization?'
        'response_type=code'
        '&client_id=$clientId'
        '&redirect_uri=${Uri.encodeComponent(redirectUri)}'
        '&state=$state'
        '&scope=openid%20profile%20email';
  }

  static Uri nativeAuthorizationUri({
    required String redirectUri,
    required String state,
    required String codeChallenge,
  }) {
    return Uri.parse(nativeAuthorizationEndpoint).replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'state': state,
        'scope': 'openid profile email',
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'enable_extended_login': 'true',
      },
    );
  }
}
