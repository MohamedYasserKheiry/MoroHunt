import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/hunt_catch.dart';
import '../models/hunter_profile.dart';
import '../providers/locale_provider.dart';

/// Displays the "عداد الطرائد" — a grid of the 5 tracked Moroccan species
/// with each hunter's lifetime catch count.
class PreyCounter extends ConsumerWidget {
  final HunterProfile profile;

  const PreyCounter({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(localeProvider);
    final counts = {
      PreyType.perdrix: profile.perdrixCount,
      PreyType.lievre: profile.lievreCount,
      PreyType.sanglier: profile.sanglierCount,
      PreyType.caille: profile.cailleCount,
      PreyType.tourtereau: profile.tourtereauCount,
    };

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: counts.entries.map((e) {
        return _PreyTile(prey: e.key, count: e.value, language: language);
      }).toList(),
    );
  }
}

class _PreyTile extends StatelessWidget {
  final PreyType prey;
  final int count;
  final AppLanguage language;

  const _PreyTile({
    required this.prey,
    required this.count,
    required this.language,
  });

  IconData get _icon {
    switch (prey) {
      case PreyType.perdrix:
        return Icons.egg_alt_outlined;
      case PreyType.lievre:
        return Icons.cruelty_free_outlined;
      case PreyType.sanglier:
        return Icons.pets;
      case PreyType.caille:
        return Icons.flutter_dash;
      case PreyType.tourtereau:
        return Icons.air;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_icon, size: 28),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 2),
          Text(
            prey.label(language),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
