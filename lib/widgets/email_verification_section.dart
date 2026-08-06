import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/email_verification_service.dart';

enum EmailVerificationState {
  idle,
  sendingOtp,
  otpSent,
  verifyingOtp,
  verified,
}

class EmailVerificationSection extends StatefulWidget {
  final TextEditingController emailController;
  final bool initialVerified;
  final Function(bool isVerified) onVerificationChanged;
  final String? errorText;

  const EmailVerificationSection({
    super.key,
    required this.emailController,
    required this.onVerificationChanged,
    this.initialVerified = false,
    this.errorText,
  });

  @override
  State<EmailVerificationSection> createState() => _EmailVerificationSectionState();
}

class _EmailVerificationSectionState extends State<EmailVerificationSection> {
  EmailVerificationState _state = EmailVerificationState.idle;
  String? _localError;

  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();

  Timer? _countdownTimer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialVerified) {
      _state = EmailVerificationState.verified;
    }
    // Listen to email changes to reset verification state if user modifies it.
    widget.emailController.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    widget.emailController.removeListener(_onEmailChanged);
    _countdownTimer?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    // If they were verified, but then edited the email, reset to idle
    if (_state != EmailVerificationState.idle && _state != EmailVerificationState.sendingOtp) {
      setState(() {
        _state = EmailVerificationState.idle;
        _localError = null;
        _countdownTimer?.cancel();
        _secondsLeft = 0;
      });
      widget.onVerificationChanged(false);
    }
  }

  void _startTimer([int duration = 60]) {
    _countdownTimer?.cancel();
    setState(() {
      _secondsLeft = duration;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendOtp() async {
    final email = widget.emailController.text.trim();
    if (email.isEmpty || !RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      setState(() {
        _localError = 'Please enter a valid email address.';
      });
      return;
    }

    setState(() {
      _state = EmailVerificationState.sendingOtp;
      _localError = null;
    });

    final result = await EmailVerificationService().sendOtp(email);

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _state = EmailVerificationState.otpSent;
      });
      _startTimer(result.resendInSeconds ?? 60);
      _otpController.clear();
      _otpFocusNode.requestFocus();
    } else {
      setState(() {
        _state = EmailVerificationState.idle;
        _localError = result.errorMessage;
      });
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() {
        _localError = 'Please enter a 6-digit OTP.';
      });
      return;
    }

    setState(() {
      _state = EmailVerificationState.verifyingOtp;
      _localError = null;
    });

    final email = widget.emailController.text.trim();
    final result = await EmailVerificationService().verifyOtp(email, otp);

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _state = EmailVerificationState.verified;
        _countdownTimer?.cancel();
      });
      widget.onVerificationChanged(true);
    } else {
      setState(() {
        _state = EmailVerificationState.otpSent; // Revert back to sent so they can try again
        _localError = result.errorMessage;
      });
      _otpFocusNode.requestFocus();
    }
  }

  Widget _buildEmailField() {
    final isVerified = _state == EmailVerificationState.verified;
    final isReadOnly = isVerified || _state == EmailVerificationState.sendingOtp || _state == EmailVerificationState.verifyingOtp;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextFormField(
                controller: widget.emailController,
                readOnly: isReadOnly,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  color: isReadOnly ? const Color(0xFF8C736B) : const Color(0xFF3E1F11),
                ),
                decoration: InputDecoration(
                  labelText: 'Email Address *',
                  hintText: 'e.g. rohan@example.com',
                  labelStyle: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    color: Color(0xFF8C736B),
                  ),
                  filled: true,
                  fillColor: isReadOnly ? const Color(0xFFF5F2F0) : const Color(0xFFFDFBF9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD4C8C3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD4C8C3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF7A432D), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  suffixIcon: isVerified 
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 20)
                      : null,
                ),
              ),
            ),
            if (!isVerified && _state != EmailVerificationState.otpSent && _state != EmailVerificationState.verifyingOtp) ...[
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _state == EmailVerificationState.sendingOtp ? null : _sendOtp,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7A432D),
                    side: const BorderSide(color: Color(0xFF7A432D)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _state == EmailVerificationState.sendingOtp 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7A432D)))
                      : const Icon(Icons.mark_email_read_outlined, size: 16),
                  label: Text(
                    _state == EmailVerificationState.sendingOtp ? 'Sending' : 'Verify',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildOtpField() {
    if (_state != EmailVerificationState.otpSent && _state != EmailVerificationState.verifyingOtp) {
      return const SizedBox.shrink();
    }

    final isVerifying = _state == EmailVerificationState.verifyingOtp;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5D5CE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the 6-digit code sent to your email',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5C473E),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _otpController,
                    focusNode: _otpFocusNode,
                    readOnly: isVerifying,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (val) {
                      if (val.length == 6) {
                        _verifyOtp(); // Auto-submit optional
                      }
                    },
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 16,
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E1F11),
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '000000',
                      hintStyle: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 16,
                        letterSpacing: 8,
                        color: Color(0xFFD4C8C3),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFD4C8C3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF7A432D), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isVerifying || _otpController.text.length < 6 ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A432D),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFD4C8C3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: isVerifying
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text(
                            'Verify OTP',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: (_secondsLeft > 0 || isVerifying) ? null : _sendOtp,
                  child: Text(
                    _secondsLeft > 0 ? 'Resend in ${_secondsLeft}s' : 'Resend OTP',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _secondsLeft > 0 ? const Color(0xFF8C736B) : const Color(0xFF7A432D),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifiedSuccess() {
    if (_state != EmailVerificationState.verified) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.only(top: 8, left: 4),
      child: Text(
        'Email Verified Successfully',
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4CAF50),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayError = _localError ?? widget.errorText;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEmailField(),
        if (displayError != null && displayError.isNotEmpty && _state != EmailVerificationState.verified)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              displayError,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                color: Color(0xFFC62828),
              ),
            ),
          ),
        _buildVerifiedSuccess(),
        _buildOtpField(),
      ],
    );
  }
}
