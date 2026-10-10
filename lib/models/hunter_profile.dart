import '../providers/locale_provider.dart';

/// Represents a row from `public.profiles`.
class HunterProfile {
  final String id;
  final String username;
  final String? avatarUrl;
  final String? gender; // 'male' or 'female'
  final String? city;
  final DateTime? birthdate;
  final int rankPoints;
  final int perdrixCount;
  final int lievreCount;
  final int sanglierCount;
  final int cailleCount;
  final int tourtereauCount;
  final DateTime createdAt;

  const HunterProfile({
    required this.id,
    required this.username,
    required this.rankPoints,
    required this.perdrixCount,
    required this.lievreCount,
    required this.sanglierCount,
    required this.cailleCount,
    required this.tourtereauCount,
    required this.createdAt,
    this.avatarUrl,
    this.gender,
    this.city,
    this.birthdate,
  });

  factory HunterProfile.fromMap(Map<String, dynamic> map) {
    return HunterProfile(
      id: map['id'] as String,
      username: map['username'] as String,
      avatarUrl: map['avatar_url'] as String?,
      gender: map['gender'] as String?,
      city: map['city'] as String?,
      birthdate: map['birthdate'] != null
          ? DateTime.tryParse(map['birthdate'] as String)
          : null,
      rankPoints: (map['rank_points'] as num?)?.toInt() ?? 0,
      perdrixCount: (map['perdrix_count'] as num?)?.toInt() ?? 0,
      lievreCount: (map['lievre_count'] as num?)?.toInt() ?? 0,
      sanglierCount: (map['sanglier_count'] as num?)?.toInt() ?? 0,
      cailleCount: (map['caille_count'] as num?)?.toInt() ?? 0,
      tourtereauCount: (map['tourtereau_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Rank tier derived from [rankPoints].
  HunterRank get rank => HunterRank.fromPoints(rankPoints);

  /// Computed fresh from [birthdate] and the current system clock every
  /// time this is read — never stored — so it stays correct
  /// automatically as time passes, with no update job needed.
  int? get age {
    final bd = birthdate;
    if (bd == null) return null;
    final now = DateTime.now();
    var age = now.year - bd.year;
    if (now.month < bd.month || (now.month == bd.month && now.day < bd.day)) {
      age--;
    }
    return age;
  }

  String get genderLabelAr {
    switch (gender) {
      case 'male':
        return 'ذكر';
      case 'female':
        return 'أنثى';
      default:
        return '—';
    }
  }

  String genderLabel(AppLanguage language) {
    switch (language) {
      case AppLanguage.arabic:
        return genderLabelAr;
      case AppLanguage.french:
        switch (gender) {
          case 'male':
            return 'Homme';
          case 'female':
            return 'Femme';
          default:
            return '—';
        }
      case AppLanguage.english:
        switch (gender) {
          case 'male':
            return 'Male';
          case 'female':
            return 'Female';
          default:
            return '—';
        }
      case AppLanguage.amazigh:
        // Best-effort, not native-speaker-reviewed — see app_strings.dart.
        switch (gender) {
          case 'male':
            return 'ⴰⵔⴳⴰⵣ';
          case 'female':
            return 'ⵜⴰⵎⵖⴰⵔⵜ';
          default:
            return '—';
        }
    }
  }
}

enum HunterRank {
  bronze, // 0 - 500
  silver, // 501 - 2000
  gold, // 2001 - 5000
  diamond; // 5000+

  static HunterRank fromPoints(int points) {
    if (points > 5000) return HunterRank.diamond;
    if (points > 2000) return HunterRank.gold;
    if (points > 500) return HunterRank.silver;
    return HunterRank.bronze;
  }

  String get labelAr {
    switch (this) {
      case HunterRank.bronze:
        return 'مبتدئ';
      case HunterRank.silver:
        return 'نشط';
      case HunterRank.gold:
        return 'محترف';
      case HunterRank.diamond:
        return 'كبير القناصين';
    }
  }

  String get labelEn {
    switch (this) {
      case HunterRank.bronze:
        return 'Bronze';
      case HunterRank.silver:
        return 'Silver';
      case HunterRank.gold:
        return 'Gold';
      case HunterRank.diamond:
        return 'Diamond';
    }
  }

  String get labelFr {
    switch (this) {
      case HunterRank.bronze:
        return 'Débutant';
      case HunterRank.silver:
        return 'Actif';
      case HunterRank.gold:
        return 'Professionnel';
      case HunterRank.diamond:
        return 'Maître Chasseur';
    }
  }

  /// Best-effort, not native-speaker-reviewed — see app_strings.dart.
  String get labelZgh {
    switch (this) {
      case HunterRank.bronze:
        return 'ⴰⵎⴰⵣⵡⴰⵔⵓ';
      case HunterRank.silver:
        return 'ⵓⵔⵎⵉⴷ';
      case HunterRank.gold:
        return 'ⴰⵎⴰⵀⵉⵔ';
      case HunterRank.diamond:
        return 'ⴰⵎⵖⴰⵔ ⵏ ⵉⵎⵚⵢⴰⴷⵏ';
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
}
