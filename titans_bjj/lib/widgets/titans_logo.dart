import 'dart:math' as math;

import 'package:flutter/material.dart';

class TitansLogo extends StatelessWidget {
  static const AssetImage _assetImage = AssetImage('assets/logo_icon.png');

  final double? size;
  final double opacity;
  final Alignment alignment;
  final bool responsive;
  final double sizeFactor;
  final double minSize;
  final double maxSize;
  final int maxDecodePx;
  final BoxFit fit;

  const TitansLogo._({
    super.key,
    required this.size,
    required this.opacity,
    required this.alignment,
    required this.responsive,
    required this.sizeFactor,
    required this.minSize,
    required this.maxSize,
    required this.maxDecodePx,
    required this.fit,
  });

  const TitansLogo.icon({
    Key? key,
    double size = 72,
    double opacity = 1,
  }) : this._(
          key: key,
          size: size,
          opacity: opacity,
          alignment: Alignment.center,
          responsive: false,
          sizeFactor: 1,
          minSize: size,
          maxSize: size,
          maxDecodePx: 512,
          fit: BoxFit.contain,
        );

  const TitansLogo.watermark({
    Key? key,
    double opacity = 0.07,
    Alignment alignment = const Alignment(0.18, -0.08),
    double sizeFactor = 0.72,
    double minSize = 240,
    double maxSize = 620,
    int maxDecodePx = 1400,
  }) : this._(
          key: key,
          size: null,
          opacity: opacity,
          alignment: alignment,
          responsive: true,
          sizeFactor: sizeFactor,
          minSize: minSize,
          maxSize: maxSize,
          maxDecodePx: maxDecodePx,
          fit: BoxFit.contain,
        );

  @override
  Widget build(BuildContext context) {
    if (!responsive) {
      return _LogoImage(
        logicalSize: size ?? minSize,
        opacity: opacity,
        fit: fit,
        maxDecodePx: maxDecodePx,
      );
    }

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shortestSide = math.min(
            constraints.maxWidth.isFinite ? constraints.maxWidth : maxSize,
            constraints.maxHeight.isFinite ? constraints.maxHeight : maxSize,
          );
          final logicalSize = (shortestSide * sizeFactor)
              .clamp(minSize, maxSize)
              .toDouble();

          return Align(
            alignment: alignment,
            child: _LogoImage(
              logicalSize: logicalSize,
              opacity: opacity,
              fit: fit,
              maxDecodePx: maxDecodePx,
            ),
          );
        },
      ),
    );
  }
}

class _LogoImage extends StatelessWidget {
  final double logicalSize;
  final double opacity;
  final BoxFit fit;
  final int maxDecodePx;

  const _LogoImage({
    required this.logicalSize,
    required this.opacity,
    required this.fit,
    required this.maxDecodePx,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final decodePx = (logicalSize * dpr).round().clamp(1, maxDecodePx).toInt();

    return Opacity(
      opacity: opacity,
      child: SizedBox.square(
        dimension: logicalSize,
        child: Image(
          image: ResizeImage(
            TitansLogo._assetImage,
            width: decodePx,
            height: decodePx,
          ),
          fit: fit,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
