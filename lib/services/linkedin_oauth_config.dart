import 'package:flutter/foundation.dart';

import '../features/auth/data/oauth/linkedin_oauth_config.dart' as feature;
import '../features/auth/data/oauth/linkedin_oauth_manager.dart';

/// Compatibility façade over [feature.LinkedInOAuthConfig].
///
/// New code should import the feature config / [LinkedInOAuthManager] directly.
class LinkedInOAuthConfig {
  static const String clientId = feature.LinkedInOAuthConfig.clientId;
  static const String mobileRedirectUri =
      feature.LinkedInOAuthConfig.mobileRedirectUri;
  static const String nativeAuthorizationEndpoint =
      feature.LinkedInOAuthConfig.authorizationEndpoint;

  @Deprecated('Use PKCE random state from LinkedInOAuthManager')
  static const String state = 'boardingpass_linkedin_oauth_state';

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
    final session =
        LinkedInOAuthManager().createSession(redirectUri: redirectUri);
    return session.authorizationUrl.toString();
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
        'scope': feature.LinkedInOAuthConfig.scope,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
      },
    );
  }
}
