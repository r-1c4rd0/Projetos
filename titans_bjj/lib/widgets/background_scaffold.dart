import 'dart:io';

import 'package:flutter/material.dart';

import '../core/titans_theme.dart';

class BackgroundScaffold extends StatelessWidget {
  final Widget child;
  final String? backgroundImagePath;

  const BackgroundScaffold({
    super.key,
    required this.child,
    this.backgroundImagePath,
  });

  @override
  Widget build(BuildContext context) {
    final tc = titansColors(context);
    final hasImage = backgroundImagePath != null &&
        backgroundImagePath!.isNotEmpty &&
        File(backgroundImagePath!).existsSync();

    return Stack(
      children: [
        Positioned.fill(
          child: hasImage
              ? Image.file(File(backgroundImagePath!), fit: BoxFit.cover)
              : Container(color: tc.background),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tc.overlay.withValues(alpha: hasImage ? 0.82 : 0.18),
              gradient: RadialGradient(
                center: const Alignment(-0.85, -0.9),
                radius: 1.15,
                colors: [
                  tc.accent.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        SafeArea(child: child),
      ],
    );
  }
}
