import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class EmailVerificationResult {
  final bool success;
  final String? errorMessage;
  final int? resendInSeconds;

  EmailVerificationResult({
    required this.success,
    this.errorMessage,
    this.resendInSeconds,
  });
}

class EmailVerificationService {
  static final EmailVerificationService _instance =
      EmailVerificationService._internal();
  factory EmailVerificationService() => _instance;
  EmailVerificationService._internal();

  // Actual Cloud Run URLs for the 2nd-gen Firebase Functions
  static const String _sendOtpUrl =
      'https://sendemailotp-f6ed7jb7sa-uc.a.run.app';
  static const String _verifyOtpUrl =
      'https://verifyemailotp-f6ed7jb7sa-uc.a.run.app';

  /// Calls a Firebase 2nd-gen callable function via raw HTTP POST.
  /// This completely avoids the dart2js Int64 deserialization bug in the
  /// Firebase Callable SDK on Flutter Web.
  Future<Map<String, dynamic>?> _callFunction(
    String url,
    Map<String, dynamic> payload,
  ) async {
    try {
      // Get the current user's ID token for authentication (if signed in).
      String? idToken;
      try {
        idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      } catch (_) {}

      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (idToken != null) 'Authorization': 'Bearer $idToken',
      };

      // Firebase callable functions expect { "data": <payload> }
      final body = jsonEncode({'data': payload});
      final response = await http
          .post(Uri.parse(url), headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      debugPrint('[HTTP] $url ${response.statusCode}: ${response.body}');

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        // Callable functions wrap the result in { "result": ... }
        return decoded['result'] as Map<String, dynamic>?;
      } else {
        final errMsg = (decoded['error'] as Map?)?.entries
                .map((e) => '${e.key}: ${e.value}')
                .join(', ') ??
            'HTTP ${response.statusCode}';
        debugPrint('[HTTP] Error: $errMsg');
        return {'ok': false, 'error': errMsg};
      }
    } catch (e) {
      debugPrint('[HTTP] Exception: $e');
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// Requests the backend to generate and send a 6-digit OTP to the provided email.
  Future<EmailVerificationResult> sendOtp(String email) async {
    final data = await _callFunction(_sendOtpUrl, {'email': email});

    if (data == null) {
      return EmailVerificationResult(
        success: false,
        errorMessage: 'No response from server. Please try again.',
      );
    }

    if (data['ok'] == true) {
      final resendRaw = data['resendInSeconds'];
      int? resendInSeconds;
      if (resendRaw is int) {
        resendInSeconds = resendRaw;
      } else if (resendRaw != null) {
        resendInSeconds = int.tryParse(resendRaw.toString());
      }
      return EmailVerificationResult(
        success: true,
        resendInSeconds: resendInSeconds,
      );
    } else {
      return EmailVerificationResult(
        success: false,
        errorMessage:
            data['error'] as String? ?? 'Failed to send verification email.',
      );
    }
  }

  /// Verifies the entered OTP with the backend.
  Future<EmailVerificationResult> verifyOtp(String email, String otp) async {
    final data = await _callFunction(
      _verifyOtpUrl,
      {'email': email, 'code': otp},
    );

    if (data == null) {
      return EmailVerificationResult(
        success: false,
        errorMessage: 'No response from server. Please try again.',
      );
    }

    if (data['ok'] == true) {
      return EmailVerificationResult(success: true);
    } else {
      return EmailVerificationResult(
        success: false,
        errorMessage: data['error'] as String? ?? 'Invalid OTP.',
      );
    }
  }
}
