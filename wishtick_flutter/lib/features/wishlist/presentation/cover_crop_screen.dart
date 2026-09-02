import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';

/// The shape a wishlist cover is shown in.
///
/// Covers are displayed landscape, so the crop is locked to this rather than
/// left free: a portrait crop would be letterboxed or cut again on display,
/// and neither is what the person framing it just chose.
const kCoverAspectRatio = 16 / 9;

/// Frames a picked image as a landscape cover before it is uploaded.
///
/// Pops with the cropped JPEG bytes, or null when backed out of. Cropping
/// happens here on the device rather than after upload: what the server
/// stores is exactly what was confirmed, and there is no second copy to keep.
class CoverCropScreen extends StatefulWidget {
  const CoverCropScreen({required this.image, super.key});

  final Uint8List image;

  /// Opens the cropper over the current route.
  static Future<Uint8List?> show(BuildContext context, Uint8List image) =>
      Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CoverCropScreen(image: image),
        ),
      );

  @override
  State<CoverCropScreen> createState() => _CoverCropScreenState();
}

class _CoverCropScreenState extends State<CoverCropScreen> {
  final _controller = CropController();
  bool _cropping = false;

  void _confirm() {
    if (_cropping) return;
    setState(() => _cropping = true);
    // The result arrives through onCropped below.
    _controller.crop();
  }

  void _onCropped(CropResult result) {
    if (!mounted) return;
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure():
        setState(() => _cropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not crop that image. Try another one.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Frame your cover'),
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _cropping ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Crop(
              image: widget.image,
              controller: _controller,
              aspectRatio: kCoverAspectRatio,
              // The frame stays put and the photo moves under it, which is
              // how every phone's own cropper behaves for a fixed shape.
              fixCropRect: true,
              interactive: true,
              baseColor: colors.background,
              maskColor: colors.textPrimary.withValues(alpha: 0.55),
              onCropped: _onCropped,
              progressIndicator: const CircularProgressIndicator(),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Text(
                    'Drag and pinch to frame it. This is how it will appear.',
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _cropping ? null : _confirm,
                      child: Text(_cropping ? 'Cropping…' : 'Use this'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
