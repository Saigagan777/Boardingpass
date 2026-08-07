/// Client-visible LinkedIn OAuth configuration only.
///
/// The client secret lives exclusively in Cloud Functions
/// (`LINKEDIN_CLIENT_SECRET`). Never put secrets in this file.
library;

class LinkedInOAuthConfig {
  LinkedInOAuthConfig._();

  /// Public LinkedIn application client ID (safe to ship in the app).
  static const String clientId = '86ltub3ua1c8o4';

  static const String authorizationEndpoint =
      'https://www.linkedin.com/oauth/v2/authorization';

  static const String scope = 'openid profile email';

  /// Fixed HTTPS redirect used by mobile (system browser → Hosting bridge → deep link).
  /// Must be registered exactly in the LinkedIn Developer Portal.
  static const String mobileRedirectUri =
      'https://fir-p-57bdc.web.app/oauth/linkedin/callback';

  /// Deep link the Hosting callback page opens after LinkedIn redirects.
  static const String appDeepLinkScheme = 'nexmeet';
  static const String appDeepLinkHost = 'oauth';
  static const String appDeepLinkPath = '/linkedin';

  static const String appCallbackUri = 'nexmeet://oauth/linkedin';

  /// Stable Hosting-proxied endpoints (preferred after `firebase deploy --only hosting,functions`).
  static const String exchangeCodeUrl =
      'https://fir-p-57bdc.web.app/api/linkedin/exchange';
  static const String fullLogoutUrl =
      'https://fir-p-57bdc.web.app/api/linkedin/full-logout';

  /// Direct Cloud Functions / Cloud Run fallbacks (fill after first deploy if needed).
  static const String exchangeCodeUrlAlt =
      'https://us-central1-fir-p-57bdc.cloudfunctions.net/exchangeLinkedInCode';
  static const String fullLogoutUrlAlt =
      'https://us-central1-fir-p-57bdc.cloudfunctions.net/fullLogoutLinkedIn';
}
