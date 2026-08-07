import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Downsizes [bytes] (JPEG/PNG) so a base64 data URI of it stays well under
/// Firestore's ~1MB document limit. This is only used as a safety net when
/// Firebase Storage is unavailable — the full-resolution image goes to Storage
/// in the normal path, and a small fallback must never silently break the
/// profile save. Images already at or below [maxLongSide] are untouched.
Uint8List downscaleForFirestore(Uint8List bytes, {int maxLongSide = 1024}) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final longest = math.max(decoded.width, decoded.height);
    if (longest <= maxLongSide) return bytes;
    final scale = maxLongSide / longest;
    final resized = img.copyResize(
      decoded,
      width: (decoded.width * scale).round(),
      height: (decoded.height * scale).round(),
    );
    return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
  } catch (e) {
    return bytes;
  }
}

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

/// Renders a circular network avatar with high-quality filtering, so photos
/// stay sharp when scaled to display size. Uses the disk-backed cache so
/// full-resolution photos load instantly on repeat views.
Widget buildNetworkAvatar({
  required String url,
  required double radius,
  Widget? fallback,
}) {
  final diameter = radius * 2;
  return CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFFE8E2DD),
    child: url.isEmpty
        ? (fallback ?? const Icon(Icons.person))
        : ClipOval(
            child: kIsWeb
                ? Image.network(
                    url,
                    width: diameter,
                    height: diameter,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) =>
                        fallback ?? const Icon(Icons.person),
                  )
                : CachedNetworkImage(
                    imageUrl: wrapCorsUrl(url),
                    width: diameter,
                    height: diameter,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    fadeInDuration: Duration.zero,
                    placeholder: (context, url) =>
                        fallback ?? const SizedBox.shrink(),
                    errorWidget: (context, url, error) =>
                        fallback ?? const Icon(Icons.person),
                  ),
          ),
  );
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
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) =>
            fallback ?? const Icon(Icons.person),
      );
    } catch (e) {
      return fallback ?? const Icon(Icons.person);
    }
  }

  if (url.isNotEmpty) {
    if (kIsWeb) {
      return Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) =>
            fallback ?? const Icon(Icons.person),
      );
    }
    return CachedNetworkImage(
      imageUrl: wrapCorsUrl(url),
      width: width,
      height: height,
      fit: fit,
      // High quality filtering keeps scaled photos crisp instead of blurry.
      // (CachedNetworkImage's default is FilterQuality.low, so it is forced.)
      filterQuality: FilterQuality.high,
      fadeInDuration: Duration.zero,
      placeholder: (context, url) => fallback ?? const SizedBox.shrink(),
      errorWidget: (context, url, error) =>
          fallback ?? const Icon(Icons.person),
    );
  }

  return fallback ?? const Icon(Icons.person);
}
