import 'package:flutter/material.dart';

/// TrackIT wordmark image — official brand logo with swoosh arrow.
class TrackitWordmark extends StatelessWidget {
  const TrackitWordmark({super.key, this.fontSize = 34});

  /// Scales logo height; width follows the asset aspect ratio.
  final double fontSize;

  static const _assetPath = 'assets/images/trackit-wordmark.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _assetPath,
      height: fontSize * 1.38,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
    );
  }
}
