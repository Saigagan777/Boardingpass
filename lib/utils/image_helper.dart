import 'dart:convert';
import 'package:flutter/material.dart';

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
      image: NetworkImage(url),
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
