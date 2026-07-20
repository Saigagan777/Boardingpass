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
    final String src = 'https://www.google.com/maps/embed/v1/place?key=AIzaSyAXjzGoUZVyISPLug4ZeovvBPr6vAJSxWw&q=${widget.latitude},${widget.longitude}';
    
    final String htmlString = '''
      <!DOCTYPE html>
      <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <style>
            html, body {
              margin: 0;
              padding: 0;
              width: 100%;
              height: 100%;
              overflow: hidden;
              background-color: #faf7f5;
            }
            iframe {
              width: 100%;
              height: 100%;
              border: none;
            }
          </style>
        </head>
        <body>
          <iframe
            src="$src"
            allowfullscreen>
          </iframe>
        </body>
      </html>
    ''';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(htmlString);
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
