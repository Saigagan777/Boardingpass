import 'package:flutter/foundation.dart';

import '../data/oauth/linkedin_oauth_manager.dart';
import '../data/sources/linkedin_auth_api.dart';
import '../domain/models/auth_models.dart';
import '../domain/repositories/auth_repository.dart';

enum LinkedInAuthStatus {
  idle,
  loading,
  redirecting,
  success,
  cancelled,
  error,
}

/// Presentation-facing controller for the Continue with LinkedIn button.
class LinkedInAuthController extends ChangeNotifier {
  LinkedInAuthController({AuthRepository? repository})
      : _repository = repository ?? LinkedInAuthRepository();

  final AuthRepository _repository;

  LinkedInAuthStatus status = LinkedInAuthStatus.idle;
  String? errorMessage;
  String? errorCode;
  AuthUser? lastUser;

  bool get isLoading =>
      status == LinkedInAuthStatus.loading ||
      status == LinkedInAuthStatus.redirecting;

  Future<AuthUser?> continueWithLinkedIn() async {
    status = LinkedInAuthStatus.loading;
    errorMessage = null;
    errorCode = null;
    notifyListeners();

    try {
      final user = await _repository.signInWithLinkedIn();
      lastUser = user;
      status = LinkedInAuthStatus.success;
      notifyListeners();
      return user;
    } on LinkedInOAuthException catch (e) {
      if (e.code == 'web_redirect') {
        status = LinkedInAuthStatus.redirecting;
        notifyListeners();
        return null;
      }
      if (e.code == 'cancelled' || e.code == 'access_denied') {
        status = LinkedInAuthStatus.cancelled;
        errorMessage = e.message;
        errorCode = e.code;
        notifyListeners();
        return null;
      }
      status = LinkedInAuthStatus.error;
      errorMessage = e.message;
      errorCode = e.code;
      notifyListeners();
      return null;
    } on LinkedInAuthApiException catch (e) {
      status = LinkedInAuthStatus.error;
      errorMessage = _mapApiError(e);
      errorCode = e.code;
      notifyListeners();
      return null;
    } catch (e) {
      status = LinkedInAuthStatus.error;
      errorMessage = _friendly(e);
      errorCode = 'unknown';
      notifyListeners();
      return null;
    }
  }

  Future<AuthUser?> handleCallback(Uri uri) async {
    status = LinkedInAuthStatus.loading;
    errorMessage = null;
    errorCode = null;
    notifyListeners();

    try {
      final user = await _repository.completeLinkedInCallback(uri);
      lastUser = user;
      status = LinkedInAuthStatus.success;
      notifyListeners();
      return user;
    } on LinkedInOAuthException catch (e) {
      if (e.code == 'cancelled' || e.code == 'access_denied') {
        status = LinkedInAuthStatus.cancelled;
      } else {
        status = LinkedInAuthStatus.error;
      }
      errorMessage = e.message;
      errorCode = e.code;
      notifyListeners();
      return null;
    } on LinkedInAuthApiException catch (e) {
      status = LinkedInAuthStatus.error;
      errorMessage = _mapApiError(e);
      errorCode = e.code;
      notifyListeners();
      return null;
    } catch (e) {
      status = LinkedInAuthStatus.error;
      errorMessage = _friendly(e);
      errorCode = 'unknown';
      notifyListeners();
      return null;
    }
  }

  Future<void> retry() => continueWithLinkedIn();

  void reset() {
    status = LinkedInAuthStatus.idle;
    errorMessage = null;
    errorCode = null;
    notifyListeners();
  }

  String _mapApiError(LinkedInAuthApiException e) {
    switch (e.code) {
      case 'invalid_redirect_uri':
        return 'Sign-in is misconfigured (redirect URI). Please contact support.';
      case 'account-restricted':
        return 'This account has been restricted by the safety team.';
      case 'missing_email':
        return 'LinkedIn did not share your email. Please allow email access and try again.';
      case 'endpoint_not_found':
        return 'Auth service is unavailable. Please try again later.';
      default:
        if ((e.message).toLowerCase().contains('expired') ||
            (e.message).toLowerCase().contains('invalid_grant')) {
          return 'Sign-in code expired. Please try again.';
        }
        return e.message;
    }
  }

  String _friendly(Object e) {
    final raw = e.toString();
    if (raw.contains('SocketException') || raw.contains('Network')) {
      return 'Network error. Check your connection and try again.';
    }
    return raw.replaceFirst('Exception: ', '');
  }
}
