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
    final String src = 'https://www.google.com/maps/embed/v1/place?key=AIzaSyArjlbJ8ESHujeB_mBlyjEHC1IZoN99Y0I&q=${widget.latitude},${widget.longitude}';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(src));
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
