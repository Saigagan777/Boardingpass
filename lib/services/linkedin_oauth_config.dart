import 'package:flutter/foundation.dart';
import 'linkedin_secret.dart';

class LinkedInOAuthConfig {
  static const String clientId = linkedinClientId;
  static const String state = 'boardingpass_linkedin_oauth_state';
  static const String mobileRedirectUri = 'https://www.google.com';

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
}
