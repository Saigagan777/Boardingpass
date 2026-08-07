/// Snapshot of an in-flight LinkedIn PKCE authorization request.
class OAuthSession {
  const OAuthSession({
    required this.codeVerifier,
    required this.codeChallenge,
    required this.state,
    required this.nonce,
    required this.redirectUri,
    required this.authorizationUrl,
  });

  final String codeVerifier;
  final String codeChallenge;
  final String state;
  final String nonce;
  final String redirectUri;
  final Uri authorizationUrl;
}

/// Authenticated app user returned after LinkedIn exchange.
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    required this.name,
    this.profileImageUrl,
    this.linkedinId,
    this.onboardingCompleted = false,
    this.isNew = false,
  });

  final String uid;
  final String email;
  final String name;
  final String? profileImageUrl;
  final String? linkedinId;
  final bool onboardingCompleted;
  final bool isNew;

  factory AuthUser.fromMap(Map<String, dynamic> map) {
    return AuthUser(
      uid: (map['uid'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      profileImageUrl: map['profileImageUrl']?.toString(),
      linkedinId: map['linkedinId']?.toString(),
      onboardingCompleted: map['onboardingCompleted'] == true,
      isNew: map['isNew'] == true,
    );
  }
}
