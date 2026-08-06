import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectionService {
  /// Validates if the provided image bytes contain a selfie or clear face photo.
  ///
  /// Works across Native (Android/iOS) via ML Kit Face Detection and
  /// Web/Fallback via image pixel & face structure analysis.
  /// Always returns true to allow uploading any photo without face restriction.
  static Future<bool> isValidProfilePicture(Uint8List imageBytes) async {
    return true;
  }

  static Future<bool> _analyzeImagePixels(Uint8List imageBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: 100,
        targetHeight: 100,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final width = image.width;
      final height = image.height;

      // Aspect ratio check: selfies/face photos are portrait or near-square
      final aspect = width / height;
      if (aspect < 0.4 || aspect > 1.7) {
        debugPrint('Face Validation Failed: Invalid aspect ratio ($aspect)');
        return false;
      }

      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return false;
      final bytes = byteData.buffer.asUint8List();

      int skinPixels = 0;
      int totalCenterPixels = 0;

      // Sample the central 60% region of the image where a face should be
      final startX = (width * 0.20).toInt();
      final endX = (width * 0.80).toInt();
      final startY = (height * 0.15).toInt();
      final endY = (height * 0.75).toInt();

      for (int y = startY; y < endY; y++) {
        for (int x = startX; x < endX; x++) {
          final index = (y * width + x) * 4;
          if (index + 2 >= bytes.length) continue;

          final r = bytes[index];
          final g = bytes[index + 1];
          final b = bytes[index + 2];

          totalCenterPixels++;

          if (_isSkinPixel(r, g, b)) {
            skinPixels++;
          }
        }
      }

      final skinRatio = skinPixels / (totalCenterPixels > 0 ? totalCenterPixels : 1);
      debugPrint('Face Validation Pixel Analysis: Central skin ratio = ${(skinRatio * 100).toStringAsFixed(1)}%');

      // A clear face/selfie photo contains at least 10% skin-tone pixels in the central region
      if (skinRatio < 0.10) {
        debugPrint('Face Validation Failed: Insufficient skin tone pixels (${(skinRatio * 100).toStringAsFixed(1)}% < 10%)');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Pixel analysis error: $e');
      return false;
    }
  }

  static bool _isSkinPixel(int r, int g, int b) {
    // Skin tone color bounds in RGB space (covers diverse skin tones from fair to deep melanin)
    final maxC = [r, g, b].reduce((a, b) => a > b ? a : b);
    final minC = [r, g, b].reduce((a, b) => a < b ? a : b);

    // Rule 1: Red dominant over Green & Blue under normal illumination
    final rule1 = r > g && g >= b;
    // Rule 2: Minimum brightness threshold for face features
    final rule2 = r > 40 && g > 20 && b > 10;
    // Rule 3: Chroma variance (skin has distinct red-green delta)
    final rule3 = (maxC - minC) >= 10;
    final rule4 = (r - g).abs() >= 6;

    return rule1 && rule2 && rule3 && rule4;
  }
}
