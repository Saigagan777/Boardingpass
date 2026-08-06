import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart';

/// Master switch for phone-number OTP verification.
///
/// Set to `true` once Firebase phone auth (reCAPTCHA Enterprise / SMS region)
/// is fully provisioned in the Firebase console. While `false`, OTP
/// verification is skipped entirely — phone numbers are still saved, but no
/// SMS is sent and no OTP dialog appears.
const bool kPhoneVerificationEnabled = true;

/// Strips everything but digits so phone numbers can be compared safely
/// regardless of formatting (`+91 98765 43210` == `+919876543210`).
String _normalizePhone(String phone) {
  return phone.replaceAll(RegExp(r'[^0-9]'), '');
}

/// Compact "Verify" / "Verified ✓" button shown next to a phone number field
/// (signup Step 1 and the Edit Profile sheet).
///
/// Shows a green "Verified" badge once the number has been confirmed via OTP,
/// otherwise a brand-colored "Verify" button that launches the OTP flow.
class PhoneVerifyButton extends StatelessWidget {
  final bool verified;
  final bool isLoading;
  final VoidCallback? onPressed;

  const PhoneVerifyButton({
    super.key,
    required this.verified,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (verified) {
      return Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4CAF50)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 18),
            SizedBox(width: 6),
            Text(
              'Verified',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF7A432D),
          side: const BorderSide(color: Color(0xFF7A432D)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.verified_user_outlined, size: 16),
        label: const Text(
          'Verify',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Shows the required OTP dialog for [fullPhone] unless that number is already
/// linked to the current Firebase user.
///
/// Returns `true` when the phone number is verified (or was already verified),
/// `false` when the user dismissed the dialog without verifying.
Future<bool> ensurePhoneVerified(BuildContext context, String fullPhone) async {
  // OTP verification is on hold until Firebase phone auth is provisioned.
  // Skipping here lets both call sites (profile completion + edit profile)
  // proceed and save the phone number without the OTP dialog.
  if (!kPhoneVerificationEnabled) return true;
  final user = FirebaseAuth.instance.currentUser;
  if (user?.phoneNumber != null &&
      _normalizePhone(user!.phoneNumber!) == _normalizePhone(fullPhone)) {
    return true;
  }
  if (!context.mounted) return false;
  final verified = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PhoneVerificationDialog(
      phoneNumber: fullPhone,
      required: true,
    ),
  );
  return verified == true;
}

/// Shows an OTP entry dialog and links the verified phone number to the
/// current Firebase user via [AuthService.verifyPhoneNumber].
///
/// Pops with `true` when the phone number is verified, `false` when skipped
/// (only possible when [required] is false).
class PhoneVerificationDialog extends StatefulWidget {
  final String phoneNumber;
  final bool required;

  const PhoneVerificationDialog({
    super.key,
    required this.phoneNumber,
    this.required = false,
  });

  @override
  State<PhoneVerificationDialog> createState() => _PhoneVerificationDialogState();
}

class _PhoneVerificationDialogState extends State<PhoneVerificationDialog> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  String? _verificationId;
  int? _resendToken;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startVerification();
  }

  Future<void> _startVerification({int? resendToken}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check phone number uniqueness across all users first
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final isTaken = await UserService().isPhoneTaken(widget.phoneNumber, excludeUid: currentUid);
      if (isTaken) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'This phone number is already registered with another account.';
        });
        return;
      }

      await AuthService().verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        forceResendingToken: resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution (e.g. Android reading SMS automatically)
          await _verifyCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _errorMessage = _friendlyVerificationError(e);
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _verificationId = verificationId;
            _resendToken = resendToken;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
            });
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _verifyCredential(PhoneAuthCredential credential) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (user.phoneNumber == null) {
          // First phone number — link it to the account.
          await user.linkWithCredential(credential);
        } else {
          // The user already has a phone number linked (e.g. editing to a new
          // number). Linking again fails with 'provider-already-linked', so
          // replace the existing number instead.
          await user.updatePhoneNumber(credential);
        }
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        // Fallback: sign in with credential if there's no user (edge case)
        await FirebaseAuth.instance.signInWithCredential(credential);
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        // The phone is already linked to an account - treat the OTP as valid
        // and let the caller continue.
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else if (e.code == 'provider-already-linked') {
        // Safety net: the user already has the phone provider linked with an
        // older number — replace it with the newly verified one.
        try {
          await FirebaseAuth.instance.currentUser
              ?.updatePhoneNumber(credential);
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        } on FirebaseAuthException catch (e2) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _errorMessage = _friendlyUpdateError(e2);
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = e.message ?? 'Verification failed';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  /// Friendly message when replacing an existing phone number hits Firebase's
  /// re-authentication requirement (sensitive account changes need a recent
  /// sign-in).
  String _friendlyUpdateError(FirebaseAuthException e) {
    if (e.code == 'requires-recent-login') {
      return 'For security, Firebase requires a recent sign-in to change your '
          'phone number. Please sign out and sign back in, then try again.';
    }
    return e.message ?? 'Verification failed';
  }

  /// Turns cryptic Firebase SMS-send failures into a clear, actionable message.
  ///
  /// "SMS unable to be sent until this region enabled by the app developer"
  /// and "invalid application verifier / reCAPTCHA token" failures mean
  /// Firebase's phone-auth setup is incomplete in the Firebase console, not
  /// that the app code is wrong. The reCAPTCHA wording is the web SDK's
  /// `invalid-app-credential` message, so it is shown when testing in a
  /// browser; the Android path is covered by the SMS-blocked branch.
  String _friendlyVerificationError(FirebaseAuthException e) {
    final msg = e.message ?? '';
    final lower = msg.toLowerCase();
    final isRecaptchaFailure =
        lower.contains('recaptcha') || lower.contains('invalid application verifier');
    if (isRecaptchaFailure && kIsWeb) {
      return 'Phone verification failed — Firebase rejected the reCAPTCHA '
          'check.\n\n'
          'New Firebase projects require reCAPTCHA Enterprise for phone '
          'sign-in on the web. In the Firebase console:\n'
          '• Authentication → Sign-in method → Phone → tap “Set up” next to '
          'reCAPTCHA Enterprise, create a site key and attach it to this web '
          'app.\n'
          '• Authentication → Settings → Authorized domains: add your site\'s '
          'URL and http://localhost.\n\n'
          'Then tap Resend OTP.';
    }
    final isAppIdentifierFailure =
        lower.contains('app identifier') ||
        lower.contains('play integrity') ||
        lower.contains('safetynet') ||
        lower.contains('device verification');
    final smsBlocked =
        msg.contains('region enabled') ||
        msg.contains('SMS unable') ||
        e.code == 'invalid-app-credential' ||
        e.code == 'internal-error';
    if (isAppIdentifierFailure || smsBlocked) {
      return 'SMS could not be sent. Firebase phone auth is not fully configured for this build.\n\n'
          'To fix this, please verify the following:\n'
          '1. Add your SHA-1 and SHA-256 fingerprints to your Firebase Console under Project Settings → Your apps → Android app.\n'
          '2. Make sure the Play Integrity API is enabled in your Google Cloud Console for this project.\n'
          '3. Make sure the Phone sign-in method is enabled under Authentication → Sign-in method in Firebase Console.\n'
          '4. If testing on a simulator or device without Play Store, use a Firebase App Check debug token or temporary test phone numbers in the Firebase Console (Authentication → Sign-in method → Phone → Phone numbers for testing).';
    }
    return e.message ?? 'Verification failed';
  }

  void _submitOTP() async {
    final code = _otpController.text.trim();
    if (code.isEmpty || _verificationId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: code,
    );

    await _verifyCredential(credential);
  }

  void _resendOTP() {
    if (_isLoading) return;
    _otpController.clear();
    _startVerification(resendToken: _resendToken);
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.phonelink_lock_rounded, color: Color(0xFF7A432D)),
          const SizedBox(width: 10),
          const Text(
            'Verify Phone Number',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Color(0xFF3E1F11),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'We sent a 6-digit OTP to ${widget.phoneNumber}. Enter it below to verify your number.',
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              color: Color(0xFF5C473E),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
              color: Color(0xFF3E1F11),
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••••',
              hintStyle: TextStyle(
                fontFamily: 'PlusJakartaSans',
                letterSpacing: 8,
                color: const Color(0xFF3E1F11).withValues(alpha: 0.2),
              ),
              filled: true,
              fillColor: const Color(0xFFF9F8F6),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF7A432D), width: 1.5),
              ),
            ),
            onSubmitted: (_) => _submitOTP(),
            onChanged: (value) {
              // Auto-submit once the 6-digit OTP is fully entered.
              if (value.trim().length == 6 && !_isLoading) {
                _submitOTP();
              }
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                color: Color(0xFFC62828),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : _resendOTP,
              child: const Text(
                'Resend OTP',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7A432D),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (!widget.required)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Skip / Cancel',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                color: Color(0xFF8C736B),
              ),
            ),
          ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7A432D),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _isLoading ? null : _submitOTP,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  'Verify',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }
}
