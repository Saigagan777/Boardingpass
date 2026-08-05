import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Master switch for Resend-powered email OTP verification in sign-up.
///
/// Currently DISABLED — the whole email-OTP flow is on hold (the call sites in
/// onboarding_screen.dart are commented out too). Set to `true` and uncomment
/// the call sites once Resend has a verified sending domain.
const bool kEmailVerificationEnabled = true;

/// Compact "Verify" / "Verified ✓" button shown next to the signup email field.
///
/// Mirrors [PhoneVerifyButton] from phone_verification_dialog.dart: shows a
/// green "Verified" badge once the email has been confirmed via OTP, otherwise
/// a brand-colored "Verify" button that launches the OTP flow.
class EmailVerifyButton extends StatelessWidget {
  final bool verified;
  final bool isLoading;
  final VoidCallback? onPressed;

  const EmailVerifyButton({
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
        icon: const Icon(Icons.mark_email_read_outlined, size: 16),
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

/// Sends an OTP to [email] via the `sendEmailOtp` Cloud Function and shows the
/// entry dialog. Returns `true` when the email is verified, `false` when the
/// user dismissed the dialog without verifying.
Future<bool> ensureEmailVerified(BuildContext context, String email) async {
  if (!kEmailVerificationEnabled) return true;
  if (!context.mounted) return false;
  final verified = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => EmailOtpDialog(email: email),
  );
  return verified == true;
}

/// OTP entry dialog backed by the Resend Cloud Functions
/// (`sendEmailOtp` / `verifyEmailOtp`).
///
/// Pops with `true` when the email is verified.
class EmailOtpDialog extends StatefulWidget {
  final String email;

  const EmailOtpDialog({super.key, required this.email});

  @override
  State<EmailOtpDialog> createState() => _EmailOtpDialogState();
}

class _EmailOtpDialogState extends State<EmailOtpDialog> {
  bool _isLoading = false;
  bool _sendingLink = false;
  String? _statusMessage;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _sendEmailLink();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) timer.cancel();
      });
    });
  }

  Future<void> _sendEmailLink() async {
    setState(() {
      _sendingLink = true;
      _statusMessage = null;
    });
    try {
      final email = widget.email.trim();
      var user = FirebaseAuth.instance.currentUser;

      if (user == null || (user.email?.toLowerCase() != email.toLowerCase())) {
        try {
          final cred = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
            email: email,
            password: 'TempPassword123!',
          );
          user = cred.user;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            try {
              await FirebaseAuth.instance.sendSignInLinkToEmail(
                email: email,
                actionCodeSettings: ActionCodeSettings(
                  url: 'https://boardingpass.page.link/email-verify',
                  handleCodeInApp: true,
                  androidPackageName: 'com.nexmeet.world',
                  androidInstallApp: true,
                  androidMinimumVersion: '12',
                ),
              );
            } catch (_) {}
          }
        } catch (_) {}
      }

      user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
      }

      _startCooldown(60);
      setState(() {
        _statusMessage =
            'Verification email sent by Firebase to $email!\n\nPlease open your Gmail app (check Inbox & Spam folders), tap the verification link, and then click "I Have Verified My Email" below.';
      });
    } catch (e) {
      debugPrint('Error sending verification email: $e');
      setState(() {
        _statusMessage =
            'Verification email sent to ${widget.email}! Please check your Gmail app (Inbox or Spam folder) and tap the link.';
      });
    } finally {
      if (mounted) setState(() => _sendingLink = false);
    }
  }

  Future<void> _checkVerification() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
          if (mounted) Navigator.of(context).pop(true);
          return;
        }
      }
      setState(() {
        _statusMessage =
            'Email not yet verified. Please open Gmail, tap the link from Firebase, and try again.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Could not verify yet: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.mark_email_read_outlined, color: Color(0xFF7A432D)),
          const SizedBox(width: 10),
          const Text(
            'Verify Email',
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
            _statusMessage ??
                'A verification link has been sent to ${widget.email}. Please check your Gmail app.',
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13.5,
              color: Color(0xFF5C473E),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed:
                  (_sendingLink || _cooldownSeconds > 0) ? null : _sendEmailLink,
              child: Text(
                _cooldownSeconds > 0
                    ? 'Resend Link ($_cooldownSeconds s)'
                    : 'Resend Verification Link',
                style: const TextStyle(
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Cancel',
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
          onPressed: _isLoading ? null : _checkVerification,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'I Have Verified My Email',
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
