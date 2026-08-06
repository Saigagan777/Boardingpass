import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Picks a photo from the gallery and immediately opens the crop screen.
///
/// Returns the cropped, adjusted image bytes (PNG) or `null` if the user
/// cancelled either step.
Future<Uint8List?> pickAndCropProfileImage(BuildContext context) async {
  final XFile? pickedFile;
  try {
    // Pick the original file untouched — no maxWidth / imageQuality re-encoding
    // here, so the highest-quality source reaches the crop screen.
    pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
  } catch (e) {
    debugPrint('Image pick failed: $e');
    return null;
  }
  if (pickedFile == null) return null;

  final Uint8List bytes;
  try {
    bytes = await pickedFile.readAsBytes();
  } catch (e) {
    debugPrint('Image read failed: $e');
    return null;
  }

  if (!context.mounted) return null;

  return recropProfileImage(context, bytes);
}

/// Opens the crop screen with an already existing image (e.g. the currently
/// saved profile photo) so the user can re-frame / re-adjust it without
/// picking a new photo. Returns the cropped PNG bytes or `null` on cancel.
Future<Uint8List?> recropProfileImage(
  BuildContext context,
  Uint8List imageBytes,
) async {
  if (!context.mounted) return null;
  return Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ProfileImageCropperScreen(imageBytes: imageBytes),
    ),
  );
}

/// Full-screen photo cropper used for profile pictures.
///
/// Supports pinch-to-zoom, drag-to-reposition, 90° rotation, live
/// brightness / contrast / saturation adjustments and selectable aspect
/// ratios (Square / 4:3 / 16:9). The visible crop is exported as PNG bytes.
class ProfileImageCropperScreen extends StatefulWidget {
  const ProfileImageCropperScreen({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<ProfileImageCropperScreen> createState() =>
      _ProfileImageCropperScreenState();
}

class _ProfileImageCropperScreenState extends State<ProfileImageCropperScreen> {
  final TransformationController _transformController =
      TransformationController();

  ui.Image? _image;
  bool _decodeFailed = false;

  int _quarterTurns = 0;
  double _brightness = 0.0; // -1 .. 1
  double _contrast = 1.0; // 0.5 .. 1.5
  double _saturation = 1.0; // 0 .. 2

  Size _cropAspect = const Size(1, 1);
  Size _viewportSize = const Size(300, 300);

  static const List<({String label, Size aspect})> _aspectPresets = [
    (label: 'Square', aspect: Size(1, 1)),
    (label: '4:3', aspect: Size(4, 3)),
    (label: '16:9', aspect: Size(16, 9)),
  ];

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  @override
  void dispose() {
    _transformController.dispose();
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decodeImage() async {
    ui.Codec? codec;
    try {
      codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _image?.dispose();
        _image = frame.image;
      });
    } catch (e) {
      debugPrint('Image decode failed: $e');
      if (mounted) setState(() => _decodeFailed = true);
    } finally {
      // Free the native decoder resources regardless of the outcome.
      codec?.dispose();
    }
  }

  void _rotate() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      // Rotate the crop frame along with the photo (16:9 <-> 9:16, 4:3 <-> 3:4)
      // so the frame follows the subject's orientation like a photo editor.
      _cropAspect = Size(_cropAspect.height, _cropAspect.width);
    });
    _transformController.value = Matrix4.identity();
  }

  void _resetAll() {
    setState(() {
      _quarterTurns = 0;
      _brightness = 0;
      _contrast = 1;
      _saturation = 1;
      _cropAspect = const Size(1, 1);
    });
    _transformController.value = Matrix4.identity();
  }

  void _selectAspect(Size aspect) {
    if (aspect == _cropAspect) return;
    setState(() {
      _cropAspect = aspect;
      // Reset zoom/pan so the new crop shape frames the image from the start.
      _transformController.value = Matrix4.identity();
    });
  }

  /// Builds a single combined 4x5 color matrix from the current
  /// brightness / contrast / saturation values (applied in that order).
  List<double> _buildAdjustmentMatrix() {
    final s = _saturation;
    final c = _contrast;
    final b = _brightness * 255.0;
    const sr = 0.2126;
    const sg = 0.7152;
    const sb = 0.0722;

    final saturation = <double>[
      sr * (1 - s) + s, sg * (1 - s), sb * (1 - s), 0, 0,
      sr * (1 - s), sg * (1 - s) + s, sb * (1 - s), 0, 0,
      sr * (1 - s), sg * (1 - s), sb * (1 - s) + s, 0, 0,
      0, 0, 0, 1, 0,
      0, 0, 0, 0, 1,
    ];
    final contrast = <double>[
      c, 0, 0, 0, 128 * (1 - c),
      0, c, 0, 0, 128 * (1 - c),
      0, 0, c, 0, 128 * (1 - c),
      0, 0, 0, 1, 0,
      0, 0, 0, 0, 1,
    ];
    final brightness = <double>[
      1, 0, 0, 0, b,
      0, 1, 0, 0, b,
      0, 0, 1, 0, b,
      0, 0, 0, 1, 0,
      0, 0, 0, 0, 1,
    ];

    final combined = _multiply5x5(_multiply5x5(brightness, contrast), saturation);
    return combined.sublist(0, 20);
  }

  static List<double> _multiply5x5(List<double> a, List<double> b) {
    final out = List<double>.filled(25, 0);
    for (var i = 0; i < 5; i++) {
      for (var j = 0; j < 5; j++) {
        var sum = 0.0;
        for (var k = 0; k < 5; k++) {
          sum += a[i * 5 + k] * b[k * 5 + j];
        }
        out[i * 5 + j] = sum;
      }
    }
    return out;
  }

  /// Renders exactly what the user sees (viewer transform + rotation +
  /// adjustments) into a high-resolution JPEG.
  ///
  /// The crop is exported at the source photo's native pixel density so the
  /// result keeps the original sharpness on retina / high-DPI screens, capped
  /// at 2048px on the longest side so the file stays compact for Firebase
  /// Storage and fast to load in the Discovery feed. Images smaller than the
  /// cap are never upscaled — the export is only ever as large as the source
  /// allows.
  Future<Uint8List?> _export() async {
    final image = _image;
    if (image == null) return null;

    final viewportLong =
        math.max(_viewportSize.width, _viewportSize.height);
    final rotatedW =
        _quarterTurns.isOdd ? image.height.toDouble() : image.width.toDouble();
    final rotatedH =
        _quarterTurns.isOdd ? image.width.toDouble() : image.height.toDouble();
    // Source pixels per viewport pixel at 1x zoom (cover-fit).
    final coverScale = math.max(
      _viewportSize.width / rotatedW,
      _viewportSize.height / rotatedH,
    );
    // How many source pixels the visible crop spans along its longest axis.
    final nativeLong = viewportLong / coverScale;
    // Cap the long side at 2048px; never upscale beyond the source's own size.
    final targetLong = math.min(nativeLong, 2048.0);
    final upscale = targetLong / viewportLong;
    final outW = (_viewportSize.width * upscale).round().clamp(1, 4096);
    final outH = (_viewportSize.height * upscale).round().clamp(1, 4096);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(upscale);
    canvas.clipRect(Offset.zero & _viewportSize);
    canvas.transform(_transformController.value.storage);

    _CropImagePainter(
      image: image,
      quarterTurns: _quarterTurns,
      colorFilter: ColorFilter.matrix(_buildAdjustmentMatrix()),
    ).paint(canvas, _viewportSize);

    final picture = recorder.endRecording();
    try {
      final outImage = await picture.toImage(outW, outH);
      final byteData =
          await outImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      outImage.dispose();
      if (byteData == null) return null;
      // Encode as a high-quality (visually lossless) JPEG — profile photos
      // don't need PNG transparency, and JPEG keeps a 2048px crop compact.
      final encoded = img.encodeJpg(
        img.Image.fromBytes(
          width: outW,
          height: outH,
          bytes: byteData.buffer,
          numChannels: 4,
          order: img.ChannelOrder.rgba,
        ),
        quality: 92,
      );
      return Uint8List.fromList(encoded);
    } finally {
      picture.dispose();
    }
  }

  Future<void> _onDone() async {
    final bytes = await _export();
    if (!mounted) return;
    Navigator.of(context).pop(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFF17140F),
      body: SafeArea(
        child: _decodeFailed
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image_outlined,
                        color: Colors.white54, size: 56),
                    const SizedBox(height: 16),
                    const Text(
                      'Could not load this image.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              )
            : _image == null
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF7A432D)),
                  )
                : Column(
                    children: [
                      _buildTopBar(),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final maxW = constraints.maxWidth - 32;
                            final maxH = constraints.maxHeight * 0.72;
                            final aw = _cropAspect.width;
                            final ah = _cropAspect.height;
                            final scale = math.min(maxW / aw, maxH / ah);
                            final cropW = aw * scale;
                            final cropH = ah * scale;
                            if (cropW != _viewportSize.width ||
                                cropH != _viewportSize.height) {
                              // Capture the actual laid-out crop size so the
                              // export matches the preview exactly.
                              _viewportSize = Size(cropW, cropH);
                            }
                            return Center(
                              child: SizedBox(
                                width: cropW,
                                height: cropH,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    InteractiveViewer(
                                      transformationController:
                                          _transformController,
                                      minScale: 1,
                                      maxScale: 5,
                                      clipBehavior: Clip.antiAlias,
                                      child: CustomPaint(
                                        painter: _CropImagePainter(
                                          image: _image!,
                                          quarterTurns: _quarterTurns,
                                          colorFilter: ColorFilter.matrix(
                                            _buildAdjustmentMatrix(),
                                          ),
                                        ),
                                      ),
                                    ),
                                    IgnorePointer(
                                      child: CustomPaint(
                                        painter: _CropMaskPainter(
                                          circular:
                                              _cropAspect.width ==
                                                  _cropAspect.height,
                                        ),
                                      ),
                                    ),

                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 20, right: 20, top: 8, bottom: 12),
                              child: Text(
                                'Pinch to zoom  •  Drag to reposition',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  color:
                                      Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                            _buildAspectSelector(),
                            const SizedBox(height: 10),
                            _buildAdjustmentPanel(colorScheme),
                            const SizedBox(height: 12),
                            _buildDoneButton(),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            tooltip: 'Cancel',
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Adjust Photo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            onPressed: _rotate,
            icon: const Icon(Icons.rotate_90_degrees_ccw_outlined,
                color: Colors.white),
            tooltip: 'Rotate',
          ),
          IconButton(
            onPressed: _resetAll,
            icon: const Icon(Icons.restart_alt_rounded, color: Colors.white),
            tooltip: 'Reset',
          ),
        ],
      ),
    );
  }

  Widget _buildAspectSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _aspectPresets.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _buildAspectChip(_aspectPresets[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildAspectChip(({String label, Size aspect}) preset) {
    final selected = preset.aspect == _cropAspect;
    return GestureDetector(
      onTap: () => _selectAspect(preset.aspect),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF7A432D)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF7A432D)
                : Colors.white.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          preset.label,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildAdjustmentPanel(ColorScheme colorScheme) {
    Widget sliderRow({
      required IconData icon,
      required String label,
      required double value,
      required double min,
      required double max,
      required String Function(double) format,
      required ValueChanged<double> onChanged,
    }) {
      return Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: colorScheme.primary,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: colorScheme.primary.withValues(alpha: 0.2),
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              format(value),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          sliderRow(
            icon: Icons.brightness_6_outlined,
            label: 'Brightness',
            value: _brightness,
            min: -1,
            max: 1,
            format: (v) => '${v >= 0 ? '+' : ''}${(v * 100).round()}',
            onChanged: (v) => setState(() => _brightness = v),
          ),
          sliderRow(
            icon: Icons.contrast_outlined,
            label: 'Contrast',
            value: _contrast,
            min: 0.5,
            max: 1.5,
            format: (v) => '${(v * 100).round()}%',
            onChanged: (v) => setState(() => _contrast = v),
          ),
          sliderRow(
            icon: Icons.invert_colors_outlined,
            label: 'Saturation',
            value: _saturation,
            min: 0,
            max: 2,
            format: (v) => '${(v * 100).round()}%',
            onChanged: (v) => setState(() => _saturation = v),
          ),
        ],
      ),
    );
  }

  Widget _buildDoneButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _onDone,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7A432D),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.check_rounded, size: 20),
          label: const Text(
            'Use Photo',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the source image rotated and color-adjusted, cover-fitted inside the
/// crop area (any aspect ratio). Shared by the preview and the export so they
/// always match.
class _CropImagePainter extends CustomPainter {
  _CropImagePainter({
    required this.image,
    required this.quarterTurns,
    this.colorFilter,
  });

  final ui.Image image;
  final int quarterTurns;
  final ColorFilter? colorFilter;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final center = size.center(Offset.zero);

    final rotatedW =
        quarterTurns.isOdd ? image.height.toDouble() : image.width.toDouble();
    final rotatedH =
        quarterTurns.isOdd ? image.width.toDouble() : image.height.toDouble();
    final coverScale =
        math.max(size.width / rotatedW, size.height / rotatedH);

    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;
    if (colorFilter != null) paint.colorFilter = colorFilter;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(quarterTurns * math.pi / 2);
    canvas.scale(coverScale);
    canvas.drawImage(
      image,
      Offset(-image.width / 2, -image.height / 2),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CropImagePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.quarterTurns != quarterTurns ||
        oldDelegate.colorFilter != colorFilter;
  }
}

/// Dark scrim with a cut-out window (circle for square crops, rounded
/// rectangle otherwise) so users can frame their subject.
class _CropMaskPainter extends CustomPainter {
  _CropMaskPainter({required this.circular});

  final bool circular;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final cutoutRect = rect.deflate(3);
    final Path cutout;
    if (circular) {
      cutout = Path()..addOval(cutoutRect);
    } else {
      cutout = Path()
        ..addRRect(RRect.fromRectAndRadius(cutoutRect, const Radius.circular(14)));
    }

    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, Paint()..color = Colors.black.withValues(alpha: 0.6));
    canvas.drawPath(
      cutout,
      Paint()
        ..color = Colors.transparent
        ..blendMode = BlendMode.clear,
    );
    canvas.restore();

    canvas.drawPath(
      cutout,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _CropMaskPainter oldDelegate) {
    return oldDelegate.circular != circular;
  }
}
