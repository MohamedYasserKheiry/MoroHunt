import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../providers/locale_provider.dart';

/// A clean, modern squircle flag icon for [language], drawn entirely
/// with `CustomPainter` — no emoji glyphs (which render inconsistently
/// across platforms/fonts) and no bundled image/SVG assets to manage.
///
/// Usage: `LanguageFlagIcon(language: AppLanguage.arabic, size: 40)`
class LanguageFlagIcon extends StatelessWidget {
  final AppLanguage language;
  final double size;

  /// Corner radius. Defaults to a proper "squircle" feel (~28% of
  /// size) rather than a barely-rounded square.
  final double? borderRadius;

  const LanguageFlagIcon({
    super.key,
    required this.language,
    this.size = 40,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size * 0.28;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
        ),
        child: CustomPaint(
          size: Size.square(size),
          painter: _painterFor(language),
        ),
      ),
    );
  }

  CustomPainter _painterFor(AppLanguage language) {
    switch (language) {
      case AppLanguage.arabic:
        return const _MoroccoFlagPainter();
      case AppLanguage.amazigh:
        return const _AmazighFlagPainter();
      case AppLanguage.french:
        return const _FranceFlagPainter();
      case AppLanguage.english:
        return const _UkFlagPainter();
    }
  }
}

// ---------------------------------------------------------------------
// 🇲🇦 Morocco — red field, green interlaced pentagram (Seal of Solomon
// style outline star), centered.
// ---------------------------------------------------------------------
class _MoroccoFlagPainter extends CustomPainter {
  const _MoroccoFlagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFFC1272D));

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.shortestSide * 0.32;

    // 5 outer points of the star, starting straight up.
    final points = List.generate(5, (i) {
      final angle = -math.pi / 2 + i * (2 * math.pi / 5);
      return center + Offset(math.cos(angle), math.sin(angle)) * outerRadius;
    });

    // The classic interlaced pentagram is a single stroke connecting
    // every SECOND point (a {5/2} star polygon) — that self-crossing
    // path is exactly what gives it the "woven" look when stroked
    // without a fill, matching the real flag.
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (final i in [2, 4, 1, 3, 0]) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF006233)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.055
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------
// ⵣ Amazigh — blue/green/yellow horizontal tricolor with the red
// Tifinagh "Yaz" (ⵣ) symbol centered.
// ---------------------------------------------------------------------
class _AmazighFlagPainter extends CustomPainter {
  const _AmazighFlagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Three horizontal bands: blue / green / yellow.
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.34),
        Paint()..color = const Color(0xFF1E88E5));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.34, w, h * 0.33),
        Paint()..color = const Color(0xFF4CAF50));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.67, w, h * 0.33),
        Paint()..color = const Color(0xFFFDD835));

    // The Yaz (ⵣ) symbol: a vertical stem, a horizontal crossbar, and
    // two true quarter-circle hooks curling from the crossbar's ends
    // to the stem's top/bottom — 180°-rotational symmetry, matching
    // the real Amazigh flag emblem. Both arcs share ONE circle (center
    // = crossbar midpoint, radius = r) so the geometry is internally
    // consistent — that's what keeps the curve a true, smooth arc
    // instead of a distorted/"wavy" bezier.
    final cx = w / 2;
    final cy = h / 2; // crossbar height = circle center
    final r =
        size.shortestSide * 0.24; // stem half-length AND crossbar half-length
    final top = cy - r;
    final bottom = cy + r;

    final stemPaint = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.065
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Vertical stem.
    canvas.drawLine(Offset(cx, top), Offset(cx, bottom), stemPaint);
    // Horizontal crossbar.
    canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), stemPaint);

    final circleRect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Top-right hook: true quarter-circle from the crossbar's right
    // end (angle 0°) to the stem's top (angle -90°), bulging through
    // the upper-right quadrant.
    canvas.drawArc(circleRect, 0, -math.pi / 2, false, stemPaint);

    // Bottom-left hook: mirrored quarter-circle from the crossbar's
    // left end (angle 180°) to the stem's bottom (angle 90°), bulging
    // through the lower-left quadrant.
    canvas.drawArc(circleRect, math.pi, -math.pi / 2, false, stemPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------
// 🇫🇷 France — three equal vertical stripes: blue, white, red.
// ---------------------------------------------------------------------
class _FranceFlagPainter extends CustomPainter {
  const _FranceFlagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final third = w / 3;
    canvas.drawRect(Rect.fromLTWH(0, 0, third, h),
        Paint()..color = const Color(0xFF0055A4));
    canvas.drawRect(
        Rect.fromLTWH(third, 0, third, h), Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(third * 2, 0, third, h),
        Paint()..color = const Color(0xFFEF4135));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------
// 🇬🇧 United Kingdom — Union Jack, adapted to a square canvas.
// Layered: blue field → white saltire → red saltire (offset/
// counterchanged) → white cross → red cross, in that order.
// ---------------------------------------------------------------------
class _UkFlagPainter extends CustomPainter {
  const _UkFlagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;

    canvas.save();
    canvas.clipRect(rect);

    canvas.drawRect(rect, Paint()..color = const Color(0xFF012169));

    // --- Diagonal saltires (St Andrew's + St Patrick's crosses) -----
    final diagonalWidth = size.shortestSide * 0.22;
    final whiteDiagonal = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = diagonalWidth;
    final redDiagonal = Paint()
      ..color = const Color(0xFFC8102E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = diagonalWidth * 0.42;

    // Extend lines beyond the corners so the stroke fully covers the
    // corner triangles once clipped back to the canvas rect.
    canvas.drawLine(Offset(-diagonalWidth, -diagonalWidth),
        Offset(w + diagonalWidth, h + diagonalWidth), whiteDiagonal);
    canvas.drawLine(Offset(w + diagonalWidth, -diagonalWidth),
        Offset(-diagonalWidth, h + diagonalWidth), whiteDiagonal);

    // Red saltire strokes are offset toward one side of each diagonal
    // (the real flag's "counterchanged" look) rather than dead-center.
    final offset = diagonalWidth * 0.28;
    canvas.drawLine(
      Offset(-diagonalWidth, -diagonalWidth - offset),
      Offset(w + diagonalWidth, h + diagonalWidth - offset),
      redDiagonal,
    );
    canvas.drawLine(
      Offset(-diagonalWidth, -diagonalWidth + offset),
      Offset(w + diagonalWidth, h + diagonalWidth + offset),
      redDiagonal,
    );
    canvas.drawLine(
      Offset(w + diagonalWidth, -diagonalWidth - offset),
      Offset(-diagonalWidth, h + diagonalWidth - offset),
      redDiagonal,
    );
    canvas.drawLine(
      Offset(w + diagonalWidth, -diagonalWidth + offset),
      Offset(-diagonalWidth, h + diagonalWidth + offset),
      redDiagonal,
    );

    // --- Straight cross (St George's cross + white fimbriation) -----
    final crossThickness = size.shortestSide * 0.26;
    final whiteCross = Paint()..color = Colors.white;
    final redCross = Paint()..color = const Color(0xFFC8102E);

    // White cross (background band for the red cross).
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(w / 2, h / 2), width: w, height: crossThickness),
      whiteCross,
    );
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(w / 2, h / 2), width: crossThickness, height: h),
      whiteCross,
    );

    // Red cross, narrower, centered on top.
    final redThickness = crossThickness * 0.5;
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(w / 2, h / 2), width: w, height: redThickness),
      redCross,
    );
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(w / 2, h / 2), width: redThickness, height: h),
      redCross,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
