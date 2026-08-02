import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmailVerificationDialog extends StatefulWidget {
  final String email;

  const EmailVerificationDialog({super.key, required this.email});

  @override
  State<EmailVerificationDialog> createState() => _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends State<EmailVerificationDialog> {
  bool _isLoading = false;
  String? _errorMessage;

  void _checkVerification() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload(); // Refresh the user's state from Firebase
        if (user.emailVerified) {
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Email is not verified yet. Please check your inbox and click the link.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to check verification: $e';
      });
    }
  }

  void _resendEmail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification email resent!'),
              backgroundColor: Color(0xFF2E7D32),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to resend email: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Verify Your Email'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('A verification link has been sent to ${widget.email}. Please click the link to verify your account before proceeding.'),
          const SizedBox(height: 16),
          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: _isLoading ? null : _resendEmail,
          child: const Text('Resend Email'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _checkVerification,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('I have verified'),
        ),
      ],
    );
  }
}
