import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

String wrapCorsUrl(String url) {
  if (url.isEmpty) return url;

  // Clean out any legacy corsproxy.io or other broken proxy prefixes stored in DB or memory
  String cleanUrl = url;
  if (cleanUrl.contains('corsproxy.io/?url=')) {
    final parts = cleanUrl.split('corsproxy.io/?url=');
    if (parts.length > 1) {
      cleanUrl = Uri.decodeComponent(parts.last);
    }
  }

  if (kIsWeb && cleanUrl.contains('firebasestorage.googleapis.com')) {
    return 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(cleanUrl)}';
  }
  return cleanUrl;
}

Widget buildProfileImage(
  String url, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget? fallback,
}) {
  if (url.startsWith('data:image') && url.contains('base64,')) {
    try {
      final base64Str = url.split('base64,').last;
      final bytes = base64Decode(base64Str);
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) =>
            fallback ?? const Icon(Icons.person),
      );
    } catch (e) {
      return fallback ?? const Icon(Icons.person);
    }
  }

  if (url.isNotEmpty) {
    return Image(
      image: NetworkImage(wrapCorsUrl(url)),
      width: width,
      height: height,
      fit: fit,
      // gaplessPlayback prevents the image flicker/blink between rebuilds
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) =>
          fallback ?? const Icon(Icons.person),
      loadingBuilder: (context, child, loadingProgress) {
        // Once loaded, show the image immediately without blinking
        if (loadingProgress == null) return child;
        // Show fallback (or a transparent box) while loading - NOT a spinner
        return fallback ?? const SizedBox.shrink();
      },
    );
  }

  return fallback ?? const Icon(Icons.person);
}
