import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';

import 'linkedin_oauth_config.dart';

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

/// Runs LinkedIn's mobile PKCE flow in the system browser / LinkedIn app.
///
/// LinkedIn sends the callback to a short-lived localhost server on the same
/// phone. This avoids relying on an unrelated web page (previously Google) to
/// carry the authorization code back after the user switches applications.
Future<LinkedInMobileOAuthResult?> startLinkedInMobileOAuth() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final redirectUri = 'http://127.0.0.1:${server.port}/linkedin/callback';
  final state = _randomUrlSafeValue(32);
  final codeVerifier = _randomUrlSafeValue(64);
  final codeChallenge = base64Url
      .encode(sha256.convert(utf8.encode(codeVerifier)).bytes)
      .replaceAll('=', '');
  final result = Completer<LinkedInMobileOAuthResult?>();

  late final StreamSubscription<HttpRequest> subscription;
  subscription = server.listen(
    (request) async {
      final uri = request.uri;
      if (uri.path != '/linkedin/callback') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final returnedState = uri.queryParameters['state'];
      final error = uri.queryParameters['error'];
      final code = uri.queryParameters['code'];
      final isValid = returnedState == state;

      request.response.headers.contentType = ContentType.html;
      request.response.write(
        '<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">'
        '<title>NexMeet</title></head><body style="font-family:-apple-system,Roboto,sans-serif;padding:32px;text-align:center">'
        '<h2>${isValid && error == null ? 'You are signed in' : 'Sign-in was not completed'}</h2>'
        '<p>You can return to NexMeet now.</p></body></html>',
      );
      await request.response.close();

      if (result.isCompleted) return;
      if (!isValid) {
        result.completeError(
          const LinkedInMobileOAuthException('The LinkedIn sign-in response could not be verified. Please try again.'),
        );
      } else if (error != null) {
        result.completeError(
          LinkedInMobileOAuthException('LinkedIn login failed: $error'),
        );
      } else if (code == null || code.isEmpty) {
        result.completeError(
          const LinkedInMobileOAuthException('LinkedIn did not return an authorization code. Please try again.'),
        );
      } else {
        result.complete(
          LinkedInMobileOAuthResult(
            code: code,
            redirectUri: redirectUri,
            codeVerifier: codeVerifier,
          ),
        );
      }
    },
    onError: (Object error) {
      if (!result.isCompleted) {
        result.completeError(
          LinkedInMobileOAuthException('Could not receive the LinkedIn sign-in response: $error'),
        );
      }
    },
  );

  try {
    final authUri = LinkedInOAuthConfig.nativeAuthorizationUri(
      redirectUri: redirectUri,
      state: state,
      codeChallenge: codeChallenge,
    );
    final opened = await launchUrl(authUri, mode: LaunchMode.externalApplication);
    if (!opened) {
      throw const LinkedInMobileOAuthException('Could not open LinkedIn sign-in.');
    }

    return await result.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () => throw const LinkedInMobileOAuthException(
        'LinkedIn sign-in timed out. Please try again and return to NexMeet after approving the request.',
      ),
    );
  } finally {
    await subscription.cancel();
    await server.close(force: true);
  }
}

String _randomUrlSafeValue(int byteCount) {
  final random = Random.secure();
  final bytes = List<int>.generate(byteCount, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}
