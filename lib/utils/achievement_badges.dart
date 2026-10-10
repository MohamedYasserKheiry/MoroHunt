import 'package:flutter/material.dart';

import '../models/hunt_catch.dart';
import '../models/hunter_profile.dart';
import '../providers/locale_provider.dart';

/// Points per individual animal for the quick-log flow. Boar (sanglier)
/// varies by weight tier; every other species has a flat value. Mirrors
/// the identical logic embedded in the `log_quick_catch` Postgres
/// function (see migration 0005) — kept here too so the Flutter UI can
/// preview a score before submitting.
int pointsForCatch(PreyType type, {String? weightTier}) {
  switch (type) {
    case PreyType.sanglier:
      switch (weightTier) {
        case 'heavy':
          return 120;
        case 'monster':
          return 150;
        default:
          return 100;
      }
    case PreyType.perdrix:
      return 20;
    case PreyType.lievre:
      return 25;
    case PreyType.caille:
      return 5;
    case PreyType.tourtereau:
      return 0; // not part of the quick-log / badge system
  }
}

String weightTierLabelAr(String tier) {
  switch (tier) {
    case 'heavy':
      return 'ضخم (60-90 كغ)';
    case 'monster':
      return 'وحش / ثقيل (+90 كغ)';
    default:
      return 'عادي (أقل من 60 كغ)';
  }
}

String weightTierLabel(String tier, AppLanguage language) {
  switch (language) {
    case AppLanguage.arabic:
      return weightTierLabelAr(tier);
    case AppLanguage.french:
      switch (tier) {
        case 'heavy':
          return 'Lourd (60-90 kg)';
        case 'monster':
          return 'Monstre / très lourd (+90 kg)';
        default:
          return 'Normal (moins de 60 kg)';
      }
    case AppLanguage.english:
      switch (tier) {
        case 'heavy':
          return 'Heavy (60-90 kg)';
        case 'monster':
          return 'Monster / Extra Heavy (+90 kg)';
        default:
          return 'Normal (under 60 kg)';
      }
    case AppLanguage.amazigh:
      // Best-effort, not native-speaker-reviewed — see app_strings.dart.
      switch (tier) {
        case 'heavy':
          return 'ⴰⵎⵇⵇⵔⴰⵏ (60-90 ⴽⴳ)';
        case 'monster':
          return 'ⴰⵎⵇⵇⵔⴰⵏ ⴰⵜⴰⵙ (+90 ⴽⴳ)';
        default:
          return 'ⴰⵎⴰⴳⵏⵓ (ⴷⴷⴰⵡ 60 ⴽⴳ)';
      }
  }
}

enum BadgeTier { bronze, silver, gold }

extension BadgeTierLabel on BadgeTier {
  String get labelAr {
    switch (this) {
      case BadgeTier.bronze:
        return 'برونزي';
      case BadgeTier.silver:
        return 'فضي';
      case BadgeTier.gold:
        return 'ذهبي';
    }
  }

  String get labelFr {
    switch (this) {
      case BadgeTier.bronze:
        return 'Bronze';
      case BadgeTier.silver:
        return 'Argent';
      case BadgeTier.gold:
        return 'Or';
    }
  }

  String get labelEn {
    switch (this) {
      case BadgeTier.bronze:
        return 'Bronze';
      case BadgeTier.silver:
        return 'Silver';
      case BadgeTier.gold:
        return 'Gold';
    }
  }

  /// Best-effort, not native-speaker-reviewed — see app_strings.dart.
  String get labelZgh {
    switch (this) {
      case BadgeTier.bronze:
        return 'ⵏⵏⵓⵃⴰⵙ';
      case BadgeTier.silver:
        return 'ⵏⵏⵓⵇⵕⴻⵜ';
      case BadgeTier.gold:
        return 'ⵓⵔⵖ';
    }
  }

  String label(AppLanguage language) {
    switch (language) {
      case AppLanguage.arabic:
        return labelAr;
      case AppLanguage.french:
        return labelFr;
      case AppLanguage.english:
        return labelEn;
      case AppLanguage.amazigh:
        return labelZgh;
    }
  }

  String get emoji {
    switch (this) {
      case BadgeTier.bronze:
        return '🥉';
      case BadgeTier.silver:
        return '🥈';
      case BadgeTier.gold:
        return '🥇';
    }
  }

  Color get color {
    switch (this) {
      case BadgeTier.bronze:
        return const Color(0xFFCD7F32);
      case BadgeTier.silver:
        return const Color(0xFFC0C0C0);
      case BadgeTier.gold:
        return const Color(0xFFFFD700);
    }
  }
}

/// Milestone thresholds per species — mirrors migration 0005's
/// log_quick_catch function exactly.
const Map<PreyType, ({int bronze, int silver, int gold})> _thresholds = {
  PreyType.sanglier: (bronze: 10, silver: 20, gold: 30),
  PreyType.perdrix: (bronze: 30, silver: 60, gold: 100),
  PreyType.lievre: (bronze: 20, silver: 40, gold: 60),
  PreyType.caille: (bronze: 50, silver: 100, gold: 200),
};

BadgeTier? badgeForCount(PreyType type, int count) {
  final t = _thresholds[type];
  if (t == null) return null;
  if (count >= t.gold) return BadgeTier.gold;
  if (count >= t.silver) return BadgeTier.silver;
  if (count >= t.bronze) return BadgeTier.bronze;
  return null;
}

/// Every badge a hunter currently holds across all 4 tracked species,
/// used for both the leaderboard row and the profile screen.
List<({PreyType species, BadgeTier tier})> allBadgesFor(HunterProfile profile) {
  final counts = <PreyType, int>{
    PreyType.sanglier: profile.sanglierCount,
    PreyType.perdrix: profile.perdrixCount,
    PreyType.lievre: profile.lievreCount,
    PreyType.caille: profile.cailleCount,
  };

  final badges = <({PreyType species, BadgeTier tier})>[];
  for (final entry in counts.entries) {
    final tier = badgeForCount(entry.key, entry.value);
    if (tier != null) badges.add((species: entry.key, tier: tier));
  }
  return badges;
}
