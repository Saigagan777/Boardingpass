import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MapWebView extends StatefulWidget {
  final double latitude;
  final double longitude;
  const MapWebView({super.key, required this.latitude, required this.longitude});

  @override
  State<MapWebView> createState() => _MapWebViewState();
}

class _MapWebViewState extends State<MapWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final String src = 'https://maps.google.com/maps?q=${widget.latitude},${widget.longitude}&t=&z=14&ie=UTF8&iwloc=&output=embed';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(src));
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
