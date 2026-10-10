import 'package:flutter/material.dart';

/// Single source of truth for MoroHunt's logo asset — every screen
/// that shows the logo (Auth screen, and any future AppBar/header/
/// profile placement) should use this widget rather than referencing
/// the asset path directly, so swapping the logo image later is a
/// one-file change.
///
/// The source PNG (`assets/images/app_logo.png`) has a genuine
/// transparent background (RGBA, alpha channel actually used, not just
/// present-but-opaque) — safe to place on any background, dark or
/// light, with no backing panel needed.
class AppLogo extends StatelessWidget {
  final double size;
  final BoxFit fit;

  const AppLogo({super.key, this.size = 44, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/app_logo.png',
      width: size,
      height: size,
      fit: fit,
    );
  }
}
