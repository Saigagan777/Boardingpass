import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../oauth/linkedin_oauth_config.dart';

class LinkedInAuthApiException implements Exception {
  const LinkedInAuthApiException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class LinkedInAuthApiResult {
  const LinkedInAuthApiResult({
    required this.customToken,
    required this.user,
  });

  final String customToken;
  final Map<String, dynamic> user;
}

/// Thin HTTP client for LinkedIn auth Cloud Functions.
///
/// Uses raw HTTP (same pattern as email OTP) to avoid dart2js Int64 issues
/// with the Callable SDK on Flutter Web.
class LinkedInAuthApi {
  LinkedInAuthApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<LinkedInAuthApiResult> exchangeCode({
    required String code,
    required String codeVerifier,
    required String redirectUri,
    String? nonce,
  }) async {
    final data = await _post(
      LinkedInOAuthConfig.exchangeCodeUrl,
      altUrl: LinkedInOAuthConfig.exchangeCodeUrlAlt,
      payload: {
        'code': code,
        'code_verifier': codeVerifier,
        'redirect_uri': redirectUri,
        if (nonce != null && nonce.isNotEmpty) 'nonce': nonce,
      },
      authenticated: false,
    );

    if (data['ok'] != true) {
      throw LinkedInAuthApiException(
        (data['error'] as String?) ?? 'LinkedIn authentication failed',
        code: data['code'] as String?,
      );
    }

    final customToken = data['customToken'] as String?;
    if (customToken == null || customToken.isEmpty) {
      throw const LinkedInAuthApiException(
        'Backend did not return a session token.',
        code: 'missing_custom_token',
      );
    }

    return LinkedInAuthApiResult(
      customToken: customToken,
      user: Map<String, dynamic>.from(data['user'] as Map? ?? {}),
    );
  }

  /// Revokes server-stored LinkedIn tokens. Does not clear LinkedIn's browser session.
  Future<void> fullLogoutLinkedIn() async {
    final data = await _post(
      LinkedInOAuthConfig.fullLogoutUrl,
      altUrl: LinkedInOAuthConfig.fullLogoutUrlAlt,
      payload: const {},
      authenticated: true,
    );
    if (data['ok'] != true) {
      throw LinkedInAuthApiException(
        (data['error'] as String?) ?? 'Full logout failed',
        code: data['code'] as String?,
      );
    }
  }

  Future<Map<String, dynamic>> _post(
    String url, {
    required Map<String, dynamic> payload,
    String altUrl = '',
    required bool authenticated,
  }) async {
    final urls = <String>[
      url,
      if (altUrl.trim().isNotEmpty) altUrl.trim(),
    ];

    Object? lastError;
    for (final candidate in urls) {
      try {
        return await _postOnce(
          candidate,
          payload: payload,
          authenticated: authenticated,
        );
      } catch (e) {
        lastError = e;
        debugPrint('[LinkedInAuthApi] $candidate failed: $e');
      }
    }
    throw lastError ??
        const LinkedInAuthApiException('Unable to reach auth backend');
  }

  Future<Map<String, dynamic>> _postOnce(
    String url, {
    required Map<String, dynamic> payload,
    required bool authenticated,
  }) async {
    String? idToken;
    if (authenticated) {
      idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) {
        throw const LinkedInAuthApiException(
          'You must be signed in to perform this action.',
          code: 'unauthenticated',
        );
      }
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (idToken != null) 'Authorization': 'Bearer $idToken',
    };

    final response = await _client
        .post(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode({'data': payload}),
        )
        .timeout(const Duration(seconds: 45));

    debugPrint(
      '[LinkedInAuthApi] $url ${response.statusCode}: ${response.body}',
    );

    if (response.statusCode == 404) {
      throw LinkedInAuthApiException(
        'Auth endpoint not found. Deploy Cloud Functions and update URLs.',
        code: 'endpoint_not_found',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const LinkedInAuthApiException('Unexpected backend response');
    }

    final result = decoded['result'];
    if (result is Map<String, dynamic>) return result;
    if (decoded.containsKey('ok')) return decoded;

    if (response.statusCode >= 400) {
      throw LinkedInAuthApiException(
        'HTTP ${response.statusCode}',
        code: 'http_error',
      );
    }

    return decoded;
  }
}
