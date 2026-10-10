import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/hunter_profile.dart';
import '../providers/locale_provider.dart';

/// Displays the user's rank badge with conditional styling:
/// - Bronze / Silver: flat colored badge
/// - Gold: glowing animated border
/// - Diamond: animated particle aura
class RankBadge extends ConsumerStatefulWidget {
  final HunterRank rank;
  final int points;
  final double size;

  const RankBadge({
    super.key,
    required this.rank,
    required this.points,
    this.size = 96,
  });

  @override
  ConsumerState<RankBadge> createState() => _RankBadgeState();
}

class _RankBadgeState extends ConsumerState<RankBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _baseColor {
    switch (widget.rank) {
      case HunterRank.bronze:
        return const Color(0xFFCD7F32);
      case HunterRank.silver:
        return const Color(0xFFC0C0C0);
      case HunterRank.gold:
        return const Color(0xFFFFD700);
      case HunterRank.diamond:
        return const Color(0xFF62E7F7);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: widget.rank == HunterRank.diamond
                  ? _DiamondAuraPainter(
                      progress: _controller.value, color: _baseColor)
                  : null,
              child: Container(
                width: widget.size,
                height: widget.size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _baseColor.withValues(alpha: 0.15),
                  border: Border.all(
                    color: _baseColor,
                    width: widget.rank == HunterRank.gold ? 4 : 3,
                  ),
                  boxShadow: widget.rank == HunterRank.gold
                      ? [
                          BoxShadow(
                            color: _baseColor.withValues(
                              alpha:
                                  0.5 + 0.5 * sin(_controller.value * 2 * pi),
                            ),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ]
                      : (widget.rank == HunterRank.diamond
                          ? [
                              BoxShadow(
                                color: _baseColor.withValues(alpha: 0.6),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ]
                          : null),
                ),
                child: Icon(
                  Icons.military_tech,
                  color: _baseColor,
                  size: widget.size * 0.45,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          widget.rank.label(ref.watch(localeProvider)),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          '${widget.rank.labelEn} · ${widget.points} pts',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Simple orbiting-particle aura for the Diamond rank.
class _DiamondAuraPainter extends CustomPainter {
  final double progress;
  final Color color;

  _DiamondAuraPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 + 10;
    const particleCount = 8;

    for (int i = 0; i < particleCount; i++) {
      final angle = (2 * pi / particleCount) * i + (progress * 2 * pi);
      final dx = center.dx + radius * cos(angle);
      final dy = center.dy + radius * sin(angle);
      final paint = Paint()..color = color.withValues(alpha: 0.8);
      canvas.drawCircle(Offset(dx, dy), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DiamondAuraPainter oldDelegate) => true;
}
