import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/competitive_rank.dart';
import '../providers/locale_provider.dart';

/// Renders a [CompetitiveRank] badge. Only Gold (exclusively 1st place)
/// gets the glowing animated border — every other tier is a flat,
/// clearly distinct badge so the hierarchy reads at a glance.
class CompetitiveRankBadge extends ConsumerStatefulWidget {
  final CompetitiveRank rank;
  final double size;
  final bool showLabel;

  const CompetitiveRankBadge({
    super.key,
    required this.rank,
    this.size = 64,
    this.showLabel = true,
  });

  @override
  ConsumerState<CompetitiveRankBadge> createState() =>
      _CompetitiveRankBadgeState();
}

class _CompetitiveRankBadgeState extends ConsumerState<CompetitiveRankBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGold = widget.rank == CompetitiveRank.gold;

    final badge = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glow = isGold ? 0.4 + 0.4 * sin(_controller.value * pi) : 0.0;
        return Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.rank.color.withValues(alpha: 0.15),
            border: Border.all(
              color: widget.rank.color,
              width: isGold ? 4 : 2.5,
            ),
            boxShadow: isGold
                ? [
                    BoxShadow(
                      color: widget.rank.color.withValues(alpha: glow),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            widget.rank.icon,
            color: widget.rank.color,
            size: widget.size * 0.45,
          ),
        );
      },
    );

    if (!widget.showLabel) return badge;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(height: 6),
        Text(
          widget.rank.label(ref.watch(localeProvider)),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
