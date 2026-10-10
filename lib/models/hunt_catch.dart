import '../providers/locale_provider.dart';
import '../utils/ewkb_parser.dart';

enum PreyType { perdrix, lievre, sanglier, caille, tourtereau }

extension PreyTypeLabel on PreyType {
  String get dbValue => name;

  String get labelAr {
    switch (this) {
      case PreyType.perdrix:
        return 'الحجل البربري';
      case PreyType.lievre:
        return 'الأرنب البري';
      case PreyType.sanglier:
        return 'الخنزير البري';
      case PreyType.caille:
        return 'طائر السمان';
      case PreyType.tourtereau:
        return 'اليمام البري';
    }
  }

  String get labelFr {
    switch (this) {
      case PreyType.perdrix:
        return 'La Perdrix';
      case PreyType.lievre:
        return 'Le Lièvre';
      case PreyType.sanglier:
        return 'Le Sanglier';
      case PreyType.caille:
        return 'La Caille';
      case PreyType.tourtereau:
        return 'Le Tourtereau';
    }
  }

  String get labelEn {
    switch (this) {
      case PreyType.perdrix:
        return 'Partridge';
      case PreyType.lievre:
        return 'Hare';
      case PreyType.sanglier:
        return 'Wild Boar';
      case PreyType.caille:
        return 'Quail';
      case PreyType.tourtereau:
        return 'Turtledove';
    }
  }

  /// Best-effort, not native-speaker-reviewed — see app_strings.dart.
  String get labelZgh {
    switch (this) {
      case PreyType.perdrix:
        return 'ⴰⵊⴻⴷⴽⵉⵜ';
      case PreyType.lievre:
        return 'ⴰⵡⵜⵓⵍ';
      case PreyType.sanglier:
        return 'ⵉⵍⴼ';
      case PreyType.caille:
        return 'ⴰⵙⵉⵎⵎⴻⵕ';
      case PreyType.tourtereau:
        return 'ⵜⵉⵜⵔⵜ';
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

  static PreyType fromDb(String value) =>
      PreyType.values.firstWhere((p) => p.dbValue == value);
}

/// Represents a row from `public.catches` (خريطة الذكريات entries).
/// [imageUrl] is nullable — quick-logged catches (no photo step) leave
/// it null; the map/gallery UIs fall back to a species icon tile for
/// those. [weightTier] only applies to `sanglier` (boar) rows.
class HuntCatch {
  final String id;
  final String userId;
  final PreyType preyType;
  final String? imageUrl;
  final String? weightTier; // 'normal' | 'heavy' | 'monster' (boar only)
  final int pointsEarned;
  final double lat;
  final double lng;
  final DateTime createdAt;

  const HuntCatch({
    required this.id,
    required this.userId,
    required this.preyType,
    required this.lat,
    required this.lng,
    required this.createdAt,
    this.imageUrl,
    this.weightTier,
    this.pointsEarned = 0,
  });

  factory HuntCatch.fromMap(Map<String, dynamic> map) {
    // `geom::text` in the Supabase select returns raw EWKB hex (e.g.
    // "0101000020E6100000..."), NOT GeoJSON — parse it accordingly.
    // See lib/utils/ewkb_parser.dart for why this was previously
    // crashing with "type 'String' is not a subtype of type
    // 'Map<String, dynamic>'".
    final point = parseEwkbPointHex(map['geom_hex'] as String);

    return HuntCatch(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      preyType: PreyTypeLabel.fromDb(map['prey_type'] as String),
      imageUrl: map['image_url'] as String?,
      weightTier: map['weight_tier'] as String?,
      pointsEarned: (map['points_earned'] as num?)?.toInt() ?? 0,
      lng: point.longitude,
      lat: point.latitude,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// Represents a row from `public.hunt_sessions` (a "Room").
class HuntSession {
  final String id;
  final String creatorId;
  final String roomCode;
  final bool isActive;
  final DateTime createdAt;

  const HuntSession({
    required this.id,
    required this.creatorId,
    required this.roomCode,
    required this.isActive,
    required this.createdAt,
  });

  factory HuntSession.fromMap(Map<String, dynamic> map) {
    return HuntSession(
      id: map['id'] as String,
      creatorId: map['creator_id'] as String,
      roomCode: map['room_code'] as String,
      isActive: map['is_active'] as bool,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// A live position broadcast for one hunter inside a room.
class LiveHunterPosition {
  final String userId;
  final double lat;
  final double lng;
  final double speedKmh;
  final DateTime updatedAt;

  const LiveHunterPosition({
    required this.userId,
    required this.lat,
    required this.lng,
    required this.speedKmh,
    required this.updatedAt,
  });

  factory LiveHunterPosition.fromMap(Map<String, dynamic> map) {
    final point = parseEwkbPointHex(map['geom_hex'] as String);
    return LiveHunterPosition(
      userId: map['user_id'] as String,
      lng: point.longitude,
      lat: point.latitude,
      speedKmh: (map['speed_kmh'] as num?)?.toDouble() ?? 0.0,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

/// Result of the `log_quick_catch` RPC — how many points this
/// submission earned, the hunter's new total count for that species,
/// which badge tier (if any) was just crossed, and their new overall
/// rank_points.
class QuickCatchResult {
  final int totalPointsEarned;
  final int newSpeciesCount;
  final String? badgeUnlocked; // 'برونزي' | 'فضي' | 'ذهبي' | null
  final int newRankPoints;

  const QuickCatchResult({
    required this.totalPointsEarned,
    required this.newSpeciesCount,
    required this.newRankPoints,
    this.badgeUnlocked,
  });

  factory QuickCatchResult.fromMap(Map<String, dynamic> map) {
    return QuickCatchResult(
      totalPointsEarned: (map['total_points_earned'] as num?)?.toInt() ?? 0,
      newSpeciesCount: (map['new_species_count'] as num?)?.toInt() ?? 0,
      badgeUnlocked: map['badge_unlocked'] as String?,
      newRankPoints: (map['new_rank_points'] as num?)?.toInt() ?? 0,
    );
  }
}
