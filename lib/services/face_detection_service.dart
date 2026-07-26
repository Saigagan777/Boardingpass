import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectionService {
  /// Validates if the provided image bytes contain at least one face.
  ///
  /// Since ML Kit Face Detection is not supported on Flutter Web natively,
  /// this method returns `true` on Web platforms.
  /// If any initialization or native error occurs, it catches the exception,
  /// prints it, and falls back to returning `true` to ensure the app doesn't break.
  static Future<bool> isValidProfilePicture(Uint8List imageBytes) async {
    if (kIsWeb) {
      // Fallback for Web platform where ML Kit face detection is not supported natively.
      return true;
    }

    try {
      // Write image bytes to a temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(imageBytes);

      final inputImage = InputImage.fromFilePath(tempFile.path);
      final faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
        ),
      );

      final List<Face> faces = await faceDetector.processImage(inputImage);
      await faceDetector.close();

      // Clean up the temporary file asynchronously
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (cleanupError) {
        debugPrint('Failed to delete temporary profile picture file: $cleanupError');
      }

      return faces.isNotEmpty;
    } catch (e) {
      // Catch native config/missing binary errors gracefully (e.g. in test envs)
      debugPrint('Face detection validation encountered an error: $e');
      return true;
    }
  }
}
