import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/achievement_badges.dart';

/// A hand-drawn vector medal — no emoji, no external asset files. Each
/// tier gets its own metallic radial gradient (bronze/silver/gold),
/// a ribbon tail beneath the disc, and a 5-point star emblem in the
/// center, all rendered via [CustomPainter] so it stays perfectly crisp
/// at any size and matches the app's dark theme.
class AchievementMedalIcon extends StatelessWidget {
  final BadgeTier tier;
  final double size;

  const AchievementMedalIcon({super.key, required this.tier, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.25, // extra height for the ribbon tail below the disc
      child: CustomPaint(
        painter: _MedalPainter(tier: tier),
      ),
    );
  }
}

class _MedalPainter extends CustomPainter {
  final BadgeTier tier;
  const _MedalPainter({required this.tier});

  ({Color light, Color mid, Color dark}) get _palette {
    switch (tier) {
      case BadgeTier.bronze:
        return (
          light: const Color(0xFFE3A26B),
          mid: const Color(0xFFCD7F32),
          dark: const Color(0xFF7A4A1E),
        );
      case BadgeTier.silver:
        return (
          light: const Color(0xFFF3F3F3),
          mid: const Color(0xFFC0C0C0),
          dark: const Color(0xFF7C7C7C),
        );
      case BadgeTier.gold:
        return (
          light: const Color(0xFFFFF3B0),
          mid: const Color(0xFFFFD700),
          dark: const Color(0xFFB8860B),
        );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final palette = _palette;
    final discRadius = size.width / 2;
    final discCenter = Offset(size.width / 2, discRadius);

    // Ribbon tails (two trapezoids behind the disc, forming a V-notch).
    final ribbonPaint = Paint()..color = palette.dark.withValues(alpha: 0.85);
    final ribbonWidth = size.width * 0.34;
    final ribbonTop = discRadius * 0.9;
    final ribbonBottom = size.height;

    void drawRibbon(double dx, double tilt) {
      final path = Path()
        ..moveTo(discCenter.dx + dx - ribbonWidth / 2, ribbonTop)
        ..lineTo(discCenter.dx + dx + ribbonWidth / 2, ribbonTop)
        ..lineTo(discCenter.dx + dx + ribbonWidth / 2 + tilt, ribbonBottom)
        ..lineTo(discCenter.dx + dx - ribbonWidth / 4,
            ribbonBottom - size.height * 0.08)
        ..close();
      canvas.drawPath(path, ribbonPaint);
    }

    drawRibbon(-size.width * 0.14, -4);
    drawRibbon(size.width * 0.14, 4);

    // Medal disc — radial gradient for a metallic, lit-from-top-left look.
    final discPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 0.9,
        colors: [palette.light, palette.mid, palette.dark],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: discCenter, radius: discRadius));
    canvas.drawCircle(discCenter, discRadius, discPaint);

    // Outer ring for definition.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..color = palette.dark;
    canvas.drawCircle(
        discCenter, discRadius - ringPaint.strokeWidth / 2, ringPaint);

    // Inner recessed ring (subtle depth cue).
    final innerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.03
      ..color = palette.light.withValues(alpha: 0.7);
    canvas.drawCircle(discCenter, discRadius * 0.72, innerRingPaint);

    // 5-point star emblem in the center.
    final starPaint = Paint()..color = palette.dark.withValues(alpha: 0.9);
    final starPath =
        _starPath(discCenter, discRadius * 0.42, discRadius * 0.19);
    canvas.drawPath(starPath, starPaint);
  }

  Path _starPath(Offset center, double outerRadius, double innerRadius) {
    const points = 5;
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final isOuter = i.isEven;
      final radius = isOuter ? outerRadius : innerRadius;
      final angle = (i * math.pi / points) - math.pi / 2;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _MedalPainter oldDelegate) =>
      oldDelegate.tier != tier;
}
