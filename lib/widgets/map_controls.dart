import 'package:flutter/material.dart';

/// Shared floating circular button used for map layer/style toggles
/// across both the main hunting map (Tab 1) and the group-hunt live
/// tracking map (Tab 3), so both screens look and behave identically.
class LayerControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  const LayerControlButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2E7D32);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? green : const Color(0xFF1C1F1A),
        shape: const CircleBorder(),
        elevation: active ? 6 : 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color: active ? Colors.white : Colors.white70,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared floating circular +/- zoom button.
class ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const ZoomButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1C1F1A),
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
