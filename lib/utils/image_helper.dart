import 'dart:convert';
import 'package:flutter/material.dart';

Widget buildProfileImage(String url, {double? width, double? height, BoxFit fit = BoxFit.cover, Widget? fallback}) {
  if (url.startsWith('data:image') && url.contains('base64,')) {
    try {
      final base64Str = url.split('base64,').last;
      final bytes = base64Decode(base64Str);
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => fallback ?? const Icon(Icons.person),
      );
    } catch (e) {
      return fallback ?? const Icon(Icons.person);
    }
  }
  
  if (url.isNotEmpty) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => fallback ?? const Icon(Icons.person),
    );
  }

  return fallback ?? const Icon(Icons.person);
}
