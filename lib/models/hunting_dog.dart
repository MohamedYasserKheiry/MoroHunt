/// Represents a row from `public.dogs`.
class HuntingDog {
  final String id;
  final String ownerId;
  final String dogName;
  final String? breed;
  final String? avatarUrl;
  final double totalDistanceKm;
  final double avgSpeedKmh;
  final int dogPoints;
  final String? imeiGpsTracker;

  const HuntingDog({
    required this.id,
    required this.ownerId,
    required this.dogName,
    required this.totalDistanceKm,
    required this.avgSpeedKmh,
    required this.dogPoints,
    this.breed,
    this.avatarUrl,
    this.imeiGpsTracker,
  });

  factory HuntingDog.fromMap(Map<String, dynamic> map) {
    return HuntingDog(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      dogName: map['dog_name'] as String,
      breed: map['breed'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      totalDistanceKm: (map['total_distance_km'] as num?)?.toDouble() ?? 0.0,
      avgSpeedKmh: (map['avg_speed_kmh'] as num?)?.toDouble() ?? 0.0,
      dogPoints: (map['dog_points'] as num?)?.toInt() ?? 0,
      imeiGpsTracker: map['imei_gps_tracker'] as String?,
    );
  }

  /// Mirrors the SQL trigger: (distance_km * 10) + (avg_speed_kmh * 5).
  /// Kept here too so the UI can preview a score before syncing to the server.
  static int calculateScore({
    required double totalDistanceKm,
    required double avgSpeedKmh,
  }) {
    return ((totalDistanceKm * 10) + (avgSpeedKmh * 5)).round();
  }
}
