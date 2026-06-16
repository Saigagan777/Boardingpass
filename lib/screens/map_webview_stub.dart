import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class MapWebView extends StatelessWidget {
  final double latitude;
  final double longitude;
  const MapWebView({super.key, required this.latitude, required this.longitude});

  @override
  Widget build(BuildContext context) {
    final String viewId = 'google-map-$latitude-$longitude';
    final String src = 'https://maps.google.com/maps?q=$latitude,$longitude&t=&z=14&ie=UTF8&iwloc=&output=embed';

    ui_web.platformViewRegistry.registerViewFactory(viewId, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = src
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    });

    return HtmlElementView(viewType: viewId);
  }
}
