import 'dart:io';
import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);

    return Stack(
      children: [
        Positioned.fill(
          child: (backgroundImagePath != null &&
              backgroundImagePath!.isNotEmpty &&
              File(backgroundImagePath!).existsSync())
              ? Image.file(File(backgroundImagePath!), fit: BoxFit.cover)
              : Container(color: theme.scaffoldBackgroundColor),
        ),

        // overlay
        Positioned.fill(
          child: Container(
            color: (theme.brightness == Brightness.dark)
                ? Colors.black.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.55),
          ),
        ),

        SafeArea(child: child),
      ],
    );
  }
}
