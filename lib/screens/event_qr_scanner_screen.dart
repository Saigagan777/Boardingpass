import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/event.dart';
import '../services/event_registration_service.dart';

/// Host-only QR scanner for venue entry check-in.
class EventQrScannerScreen extends StatefulWidget {
  final Event event;

  const EventQrScannerScreen({super.key, required this.event});

  @override
  State<EventQrScannerScreen> createState() => _EventQrScannerScreenState();
}

class _EventQrScannerScreenState extends State<EventQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _handling = false;
  String? _lastMessage;
  bool? _lastSuccess;
  int _checkedInCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() => _handling = true);

    final result = await EventRegistrationService().checkInFromQr(
      rawPayload: raw,
      expectedEventId: widget.event.id,
    );

    if (!mounted) return;

    setState(() {
      _handling = false;
      _lastMessage = result.message;
      _lastSuccess = result.success;
      if (result.success) _checkedInCount++;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor:
            result.success ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
        duration: const Duration(seconds: 2),
      ),
    );

    // Brief cooldown so the same QR is not re-processed instantly.
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _handling = false);
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Scan tickets · ${widget.event.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          if (!isWeb)
            IconButton(
              icon: const Icon(Icons.flash_on),
              onPressed: () => _controller.toggleTorch(),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: isWeb
                ? _WebFallback(
                    onManualSubmit: (code) async {
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => _handling = true);
                      final result =
                          await EventRegistrationService().checkInFromQr(
                        rawPayload: code,
                        expectedEventId: widget.event.id,
                      );
                      if (!mounted) return;
                      setState(() {
                        _handling = false;
                        _lastMessage = result.message;
                        _lastSuccess = result.success;
                        if (result.success) _checkedInCount++;
                      });
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(result.message),
                          backgroundColor: result.success
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFC62828),
                        ),
                      );
                    },
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _controller,
                        onDetect: _onDetect,
                      ),
                      // Viewfinder overlay
                      IgnorePointer(
                        child: Center(
                          child: Container(
                            width: 260,
                            height: 260,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white70,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                      if (_handling)
                        Container(
                          color: Colors.black45,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            color: const Color(0xFF1A1A1A),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Checked in this session: $_checkedInCount',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Point the camera at the attendee’s pass QR. Only valid, unused tickets for this event will be accepted.',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                if (_lastMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (_lastSuccess == true)
                          ? const Color(0xFF1B5E20)
                          : const Color(0xFFB71C1C),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _lastMessage!,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WebFallback extends StatefulWidget {
  final Future<void> Function(String code) onManualSubmit;

  const _WebFallback({required this.onManualSubmit});

  @override
  State<_WebFallback> createState() => _WebFallbackState();
}

class _WebFallbackState extends State<_WebFallback> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF121212),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_scanner, size: 64, color: Colors.white54),
          const SizedBox(height: 16),
          const Text(
            'Camera scanning is best on mobile.\nPaste a ticket QR payload below to check in.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _ctrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'NEXMEET|regId|ticketId|eventId',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7A432D),
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: () {
              if (_ctrl.text.trim().isEmpty) return;
              widget.onManualSubmit(_ctrl.text.trim());
            },
            child: const Text(
              'Check in',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
