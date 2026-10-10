import 'dart:math';
import 'package:flutter/material.dart';

import '../models/hunting_dog.dart';

/// Home Dashboard spotlight card for "كلب الشهر" — the dog with the
/// highest calculated `dog_points` for the current month, shown with a
/// glowing interactive golden crown and aura.
class DogOfTheMonthCard extends StatefulWidget {
  final HuntingDog dog;

  const DogOfTheMonthCard({super.key, required this.dog});

  @override
  State<DogOfTheMonthCard> createState() => _DogOfTheMonthCardState();
}

class _DogOfTheMonthCardState extends State<DogOfTheMonthCard>
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glow = 0.4 + 0.4 * sin(_controller.value * pi);
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3A2C00), Color(0xFF1B1300)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: glow),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundImage: widget.dog.avatarUrl != null
                        ? NetworkImage(widget.dog.avatarUrl!)
                        : null,
                    backgroundColor: Colors.brown.shade200,
                    child: widget.dog.avatarUrl == null
                        ? const Icon(Icons.pets, size: 32)
                        : null,
                  ),
                  Positioned(
                    top: -18,
                    left: 18,
                    child: Icon(
                      Icons.emoji_events,
                      color:
                          const Color(0xFFFFD700).withValues(alpha: glow + 0.3),
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🐾 كلب الشهر · Dog of the Month',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.dog.dogName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.dog.dogPoints} pts · '
                      '${widget.dog.totalDistanceKm.toStringAsFixed(1)} km · '
                      '${widget.dog.avgSpeedKmh.toStringAsFixed(1)} km/h',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
