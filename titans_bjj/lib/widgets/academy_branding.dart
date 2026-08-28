import 'package:flutter/material.dart';

import '../model/academy_models.dart';
import 'titans_logo.dart';

class AcademyBrandingAssets {
  static const String titansLogo = 'assets/logo_icon.png';

  static String? logoAssetPath(String assetKey) {
    return _knownAssetPath(assetKey);
  }

  static String? loginBackgroundAssetPath(String assetKey) {
    return _knownAssetPath(assetKey);
  }

  static String? _knownAssetPath(String assetKey) {
    switch (assetKey.trim().toLowerCase()) {
      case 'titans':
      case 'titans_logo':
      case 'titans-logo':
      case 'logo_icon':
      case 'logo-icon':
      case 'assets/logo_icon.png':
        return titansLogo;
    }
    return null;
  }
}

Color? academyBrandColor(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;

  final hex = text.startsWith('#') ? text.substring(1) : text;
  if (hex.length != 6 && hex.length != 8) return null;

  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return null;

  return Color(hex.length == 6 ? 0xFF000000 | parsed : parsed);
}

bool isHttpsBrandingUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null && uri.scheme == 'https' && uri.hasAuthority;
}

class AcademyBrandLogo extends StatelessWidget {
  final AcademyBranding branding;
  final double size;
  final double fallbackSize;
  final double opacity;

  const AcademyBrandLogo({
    super.key,
    required this.branding,
    this.size = 72,
    double? fallbackSize,
    this.opacity = 1,
  }) : fallbackSize = fallbackSize ?? size;

  @override
  Widget build(BuildContext context) {
    final logoUrl = branding.logoUrl;
    final assetPath = AcademyBrandingAssets.logoAssetPath(
      branding.logoAssetKey,
    );

    if (isHttpsBrandingUrl(logoUrl)) {
      return Opacity(
        opacity: opacity,
        child: Image.network(
          logoUrl,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder:
              (_, __, ___) =>
                  TitansLogo.icon(size: fallbackSize, opacity: opacity),
        ),
      );
    }

    if (assetPath != null) {
      return Opacity(
        opacity: opacity,
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder:
              (_, __, ___) =>
                  TitansLogo.icon(size: fallbackSize, opacity: opacity),
        ),
      );
    }

    return TitansLogo.icon(size: fallbackSize, opacity: opacity);
  }
}

class AcademyLoginBackground extends StatelessWidget {
  final AcademyBranding branding;
  final Widget fallback;

  const AcademyLoginBackground({
    super.key,
    required this.branding,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundUrl = branding.loginBackgroundUrl;
    final assetPath = AcademyBrandingAssets.loginBackgroundAssetPath(
      branding.loginBackgroundAssetKey,
    );

    if (isHttpsBrandingUrl(backgroundUrl)) {
      return _BrandingBackgroundImage(image: NetworkImage(backgroundUrl));
    }

    if (assetPath != null) {
      return _BrandingBackgroundImage(image: AssetImage(assetPath));
    }

    return fallback;
  }
}

class _BrandingBackgroundImage extends StatelessWidget {
  final ImageProvider image;

  const _BrandingBackgroundImage({required this.image});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: image,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder:
              (_, __, ___) =>
                  DecoratedBox(decoration: BoxDecoration(color: cs.surface)),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.18),
                cs.surface.withValues(alpha: 0.82),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
