import 'dart:ui';

import 'package:flutter/material.dart';

import 'trackit_diamond_logo.dart';
import 'trackit_wordmark.dart';

/// Splash logo sequence — loading ring, logo settle, then TrackIT wordmark reveal.
class TrackitSplashLogoAnimation extends StatelessWidget {
  const TrackitSplashLogoAnimation({
    super.key,
    required this.logoSize,
    required this.wordmarkSize,
    required this.logoAppear,
    required this.logoShift,
    required this.wordmarkSlide,
    required this.ringOpacity,
    required this.ringRotationTurns,
  });

  final double logoSize;
  final double wordmarkSize;
  final double logoAppear;
  final double logoShift;
  final double wordmarkSlide;
  final double ringOpacity;
  final double ringRotationTurns;

  static const _wordmarkGap = 14.0;

  @override
  Widget build(BuildContext context) {
    final shiftEase = logoShift.clamp(0.0, 1.0);
    final wordEase = wordmarkSlide.clamp(0.0, 1.0);

    // Logo drifts left after loading, then recenters as the wordmark joins.
    final soloShift = lerpDouble(0, logoSize * 0.12, shiftEase)!;
    final diamondShiftX = -soloShift * (1 - wordEase);
    final logoScale = lerpDouble(0.965, 1.0, shiftEase)!;

    // Wordmark slides out from behind the diamond with a soft fade + scale.
    final wordmarkRevealX = lerpDouble(logoSize * 0.18, 0, wordEase)!;
    final wordmarkRevealY = lerpDouble(8, 0, wordEase)!;
    final wordmarkOpacity = wordEase;
    final wordmarkScale = lerpDouble(0.92, 1.0, wordEase)!;

    // Loader ring is larger than the logo but must not widen the row — keeps the mark centered.
    final loaderSize = logoSize * 1.46;
    final appearEase = Curves.easeOutCubic.transform(logoAppear.clamp(0.0, 1.0));

    return RepaintBoundary(
      child: Opacity(
        opacity: appearEase,
        child: Transform.scale(
          scale: lerpDouble(0.94, 1.0, appearEase)!,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Transform.translate(
                offset: Offset(diamondShiftX, 0),
                child: Transform.scale(
                  scale: logoScale,
                  child: SizedBox(
                    width: logoSize,
                    height: logoSize,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        if (ringOpacity > 0.01)
                          TrackitLogoRingLoader(
                            loaderSize: loaderSize,
                            logoSize: logoSize,
                            rotationTurns: ringRotationTurns,
                            opacity: ringOpacity,
                          ),
                        TrackitDiamondLogo(size: logoSize),
                      ],
                    ),
                  ),
                ),
              ),
              if (wordEase > 0.001)
                Padding(
                  padding: EdgeInsets.only(left: _wordmarkGap * wordEase),
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: wordEase,
                      child: Opacity(
                        opacity: wordmarkOpacity,
                        child: Transform.translate(
                          offset: Offset(wordmarkRevealX, wordmarkRevealY),
                          child: Transform.scale(
                            scale: wordmarkScale,
                            alignment: Alignment.centerLeft,
                            child: TrackitWordmark(fontSize: wordmarkSize),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
