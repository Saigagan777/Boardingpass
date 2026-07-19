import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/event_registration.dart';
import '../services/event_registration_service.dart';

/// Luna-style ticket pass with unique QR, wallet save, and blur when invalid.
class EventPassScreen extends StatefulWidget {
  final EventRegistration registration;
  final bool showClose;

  const EventPassScreen({
    super.key,
    required this.registration,
    this.showClose = true,
  });

  @override
  State<EventPassScreen> createState() => _EventPassScreenState();
}

class _EventPassScreenState extends State<EventPassScreen> {
  late EventRegistration _reg;
  bool _savingWallet = false;

  @override
  void initState() {
    super.initState();
    _reg = widget.registration;
  }

  Future<void> _toggleWallet() async {
    setState(() => _savingWallet = true);
    try {
      if (_reg.savedToWallet) {
        await EventRegistrationService().removeFromWallet(_reg.id);
        setState(() {
          _reg = EventRegistration(
            id: _reg.id,
            eventId: _reg.eventId,
            userId: _reg.userId,
            organiserId: _reg.organiserId,
            fullName: _reg.fullName,
            email: _reg.email,
            phone: _reg.phone,
            company: _reg.company,
            role: _reg.role,
            notes: _reg.notes,
            ticketId: _reg.ticketId,
            qrPayload: _reg.qrPayload,
            status: _reg.status,
            registeredAt: _reg.registeredAt,
            checkedInAt: _reg.checkedInAt,
            expiresAt: _reg.expiresAt,
            eventTitle: _reg.eventTitle,
            eventLocation: _reg.eventLocation,
            eventTime: _reg.eventTime,
            eventMonth: _reg.eventMonth,
            eventDay: _reg.eventDay,
            eventPrice: _reg.eventPrice,
            eventImageUrl: _reg.eventImageUrl,
            eventCategory: _reg.eventCategory,
            savedToWallet: false,
          );
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Removed from wallet')),
          );
        }
      } else {
        await EventRegistrationService().saveToWallet(_reg.id);
        setState(() {
          _reg = EventRegistration(
            id: _reg.id,
            eventId: _reg.eventId,
            userId: _reg.userId,
            organiserId: _reg.organiserId,
            fullName: _reg.fullName,
            email: _reg.email,
            phone: _reg.phone,
            company: _reg.company,
            role: _reg.role,
            notes: _reg.notes,
            ticketId: _reg.ticketId,
            qrPayload: _reg.qrPayload,
            status: _reg.status,
            registeredAt: _reg.registeredAt,
            checkedInAt: _reg.checkedInAt,
            expiresAt: _reg.expiresAt,
            eventTitle: _reg.eventTitle,
            eventLocation: _reg.eventLocation,
            eventTime: _reg.eventTime,
            eventMonth: _reg.eventMonth,
            eventDay: _reg.eventDay,
            eventPrice: _reg.eventPrice,
            eventImageUrl: _reg.eventImageUrl,
            eventCategory: _reg.eventCategory,
            savedToWallet: true,
          );
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pass saved to wallet'),
              backgroundColor: Color(0xFF2E7D32),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Wallet update failed: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingWallet = false);
    }
  }

  String get _dateLabel {
    final day = _reg.eventDay;
    final month = _reg.eventMonth;
    final time = _reg.eventTime.split('•').first.trim();
    return '$day $month · $time';
  }

  String get _amountLabel {
    final p = _reg.eventPrice.trim();
    if (p.isEmpty || p.toLowerCase() == 'free') return 'Free';
    return p.startsWith('\$') || p.startsWith('₹') ? p : p;
  }

  @override
  Widget build(BuildContext context) {
    final invalid = _reg.isQrInvalid;
    final registeredFmt =
        DateFormat('d MMM yyyy · HH:mm').format(_reg.registeredAt);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F0EE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.showClose
            ? IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF3E1F11)),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: [
          IconButton(
            tooltip: _reg.savedToWallet ? 'Remove from wallet' : 'Save to wallet',
            onPressed: _savingWallet ? null : _toggleWallet,
            icon: _savingWallet
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _reg.savedToWallet
                        ? Icons.account_balance_wallet
                        : Icons.account_balance_wallet_outlined,
                    color: _reg.savedToWallet
                        ? const Color(0xFF7A432D)
                        : const Color(0xFF3E1F11),
                  ),
          ),
          IconButton(
            tooltip: 'Copy ticket ID',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _reg.ticketId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ticket ID copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, color: Color(0xFF3E1F11)),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              children: [
                _TicketCard(
                  reg: _reg,
                  invalid: invalid,
                  dateLabel: _dateLabel,
                  amountLabel: _amountLabel,
                  registeredFmt: registeredFmt,
                ),
                const SizedBox(height: 20),
                if (invalid)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFCDD2)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _reg.isCheckedIn
                              ? Icons.verified_rounded
                              : Icons.timer_off_outlined,
                          color: const Color(0xFFC62828),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _reg.isCheckedIn
                                ? 'QR used — you have been checked in at the venue.'
                                : 'This pass has expired. QR is no longer valid.',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              color: Color(0xFFC62828),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Text(
                    'Show this QR at the venue entrance. The host will scan it to let you in.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      color: Color(0xFF8C736B),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final EventRegistration reg;
  final bool invalid;
  final String dateLabel;
  final String amountLabel;
  final String registeredFmt;

  const _TicketCard({
    required this.reg,
    required this.invalid,
    required this.dateLabel,
    required this.amountLabel,
    required this.registeredFmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 380),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Top celebration section
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.celebration_rounded,
                      color: Color(0xFFE65100),
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Thank you!',
                    style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reg.eventTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3E1F11),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    invalid
                        ? 'Pass ${reg.statusLabel.toLowerCase()}'
                        : 'Your ticket has been issued successfully',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
            ),

            // Dashed tear line with side notches
            _PerforationRow(),

            // Details
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _MetaBlock(
                          label: 'TICKET ID',
                          value: reg.ticketId,
                        ),
                      ),
                      Expanded(
                        child: _MetaBlock(
                          label: 'Amount',
                          value: amountLabel,
                          alignEnd: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _MetaBlock(
                    label: 'DATE & TIME',
                    value: dateLabel,
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      reg.eventLocation,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        color: Color(0xFF8C736B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F5F3),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7A432D),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              reg.fullName.isNotEmpty
                                  ? reg.fullName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'PlusJakartaSans',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reg.fullName,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              Text(
                                reg.email,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  color: Color(0xFF9E9E9E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: invalid
                                ? const Color(0xFFFFEBEE)
                                : const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            reg.statusLabel.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: invalid
                                  ? const Color(0xFFC62828)
                                  : const Color(0xFF2E7D32),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Issued $registeredFmt',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10,
                        color: Color(0xFFB0A8A2),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            _PerforationRow(),

            // QR section
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      QrImageView(
                        data: reg.qrPayload,
                        version: QrVersions.auto,
                        size: 180,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF1A1A1A),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      if (invalid)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                            child: Container(
                              width: 180,
                              height: 180,
                              color: Colors.white.withValues(alpha: 0.55),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    reg.isCheckedIn
                                        ? Icons.check_circle_outline
                                        : Icons.lock_outline,
                                    size: 36,
                                    color: const Color(0xFF8C736B),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    reg.isCheckedIn ? 'USED' : 'EXPIRED',
                                    style: const TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      letterSpacing: 1.2,
                                      color: Color(0xFF8C736B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reg.ticketId,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      letterSpacing: 1.4,
                      color: Color(0xFFB0A8A2),
                    ),
                  ),
                ],
              ),
            ),

            // Scalloped bottom edge simulation
            CustomPaint(
              size: const Size(double.infinity, 14),
              painter: _ScallopPainter(color: const Color(0xFFF3F0EE)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaBlock extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _MetaBlock({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: Color(0xFFB0A8A2),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }
}

class _PerforationRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFFF3F0EE),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final count = (constraints.maxWidth / 8).floor();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    count,
                    (_) => Container(
                      width: 4,
                      height: 1.5,
                      color: const Color(0xFFE0D8D2),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            width: 12,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFFF3F0EE),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScallopPainter extends CustomPainter {
  final Color color;

  _ScallopPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const radius = 7.0;
    final count = (size.width / (radius * 2)).ceil();
    for (var i = 0; i < count; i++) {
      canvas.drawCircle(
        Offset(i * radius * 2 + radius, 0),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
