import 'package:flutter/material.dart';

import '../providers/locale_provider.dart';

/// Position-based competitive rank shown on the leaderboard and on the
/// user's own profile. Distinct from raw `rank_points` — this reflects
/// where someone currently sits in the standings:
///
/// - الذهبي (Gold)   → exclusively the #1 spot, glowing gold badge
/// - الماسي (Diamond) → 2nd and 3rd place
/// - الورقة الرابحة (Ace) → 4th through 10th place
/// - الفولاذي (Steel) → everyone else
enum CompetitiveRank {
  steel,
  ace,
  diamond,
  gold;

  /// [position] is 1-indexed (1 = first place).
  static CompetitiveRank fromPosition(int position) {
    if (position == 1) return CompetitiveRank.gold;
    if (position == 2 || position == 3) return CompetitiveRank.diamond;
    if (position >= 4 && position <= 10) return CompetitiveRank.ace;
    return CompetitiveRank.steel;
  }

  String get labelAr {
    switch (this) {
      case CompetitiveRank.gold:
        return 'الذهبي';
      case CompetitiveRank.diamond:
        return 'الماسي';
      case CompetitiveRank.ace:
        return 'الورقة الرابحة';
      case CompetitiveRank.steel:
        return 'الفولاذي';
    }
  }

  String get labelFr {
    switch (this) {
      case CompetitiveRank.gold:
        return 'Or';
      case CompetitiveRank.diamond:
        return 'Diamant';
      case CompetitiveRank.ace:
        return 'As';
      case CompetitiveRank.steel:
        return 'Acier';
    }
  }

  String get labelEn {
    switch (this) {
      case CompetitiveRank.gold:
        return 'Gold';
      case CompetitiveRank.diamond:
        return 'Diamond';
      case CompetitiveRank.ace:
        return 'Ace';
      case CompetitiveRank.steel:
        return 'Steel';
    }
  }

  /// Best-effort, not native-speaker-reviewed — see app_strings.dart.
  String get labelZgh {
    switch (this) {
      case CompetitiveRank.gold:
        return 'ⵓⵔⵖ';
      case CompetitiveRank.diamond:
        return 'ⴰⴷⵎⴰⵎ';
      case CompetitiveRank.ace:
        return 'ⴰⵎⵣⵡⴰⵔⵓ';
      case CompetitiveRank.steel:
        return 'ⵓⵣⵣⴰⵍ';
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

  Color get color {
    switch (this) {
      case CompetitiveRank.gold:
        return const Color(0xFFFFD700);
      case CompetitiveRank.diamond:
        return const Color(0xFF62E7F7);
      case CompetitiveRank.ace:
        return const Color(0xFFB48CE0);
      case CompetitiveRank.steel:
        return const Color(0xFF9AA5B1);
    }
  }

  IconData get icon {
    switch (this) {
      case CompetitiveRank.gold:
        return Icons.emoji_events;
      case CompetitiveRank.diamond:
        return Icons.diamond;
      case CompetitiveRank.ace:
        return Icons.style;
      case CompetitiveRank.steel:
        return Icons.shield;
    }
  }
}
