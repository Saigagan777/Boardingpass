import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

Future<String?> showLinkedInWebView(BuildContext context, String authUrl) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return LinkedInWebViewDialog(authUrl: authUrl);
    },
  );
}

class LinkedInWebViewDialog extends StatefulWidget {
  final String authUrl;
  const LinkedInWebViewDialog({super.key, required this.authUrl});

  @override
  State<LinkedInWebViewDialog> createState() => _LinkedInWebViewDialogState();
}

class _LinkedInWebViewDialogState extends State<LinkedInWebViewDialog> with WidgetsBindingObserver {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasTimedOut = false;
  Timer? _timeoutTimer;
  static const int timeoutDurationSeconds = 60; // 60 seconds timeout before prompt

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeController();
    _startTimer();
  }

  void _initializeController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            // Reset/keep the timeout timer alive as long as pages are successfully loading
            _startTimer();
          },
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.parse(request.url);
            // Check if it's the redirect URL (contains google.com) and has code or error params
            if ((uri.host.contains('google.com') || request.url.contains('google.com')) &&
                (uri.queryParameters.containsKey('code') || uri.queryParameters.containsKey('error'))) {
              final code = uri.queryParameters['code'];
              final error = uri.queryParameters['error'];
              Navigator.pop(context, code ?? 'error:$error');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    // Clear cookies before loading request to ensure fresh login/account-switching support
    WebViewCookieManager().clearCookies().then((_) {
      if (mounted) {
        _controller.loadRequest(Uri.parse(widget.authUrl));
      }
    }).catchError((e) {
      debugPrint('Error clearing WebView cookies: $e');
      if (mounted) {
        _controller.loadRequest(Uri.parse(widget.authUrl));
      }
    });
  }

  void _startTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: timeoutDurationSeconds), () {
      if (mounted) {
        setState(() {
          _hasTimedOut = true;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('App resumed. Reloading LinkedIn OAuth web session to prevent blank screen hang.');
      // Restart/reload the flow cleanly on resuming from background
      _controller.loadRequest(Uri.parse(widget.authUrl));
      if (mounted) {
        setState(() {
          _hasTimedOut = false;
          _isLoading = true;
        });
      }
      _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F5F5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'linkedin.com/oauth/v2/authorization',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7A432D)),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _hasTimedOut
                ? _buildTimeoutView()
                : WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeoutView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.hourglass_empty_rounded,
              color: Color(0xFF7A432D),
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              "Login didn't complete — try again",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3E1F11),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF7A432D)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      color: Color(0xFF7A432D),
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        _hasTimedOut = false;
                        _isLoading = true;
                      });
                    }
                    _controller.loadRequest(Uri.parse(widget.authUrl));
                    _startTimer();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7A432D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'PlusJakartaSans',
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
}
