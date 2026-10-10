import 'package:flutter/material.dart';

import '../providers/locale_provider.dart';

/// The three hunting-zone categories shown in the "Map Layers Filter"
/// panel, matching `public.map_zones.category` in Supabase.
enum HuntZoneCategory {
  /// 🔴 Réserve / محميات — protected/forbidden, hunting not allowed.
  reserve,

  /// 🔵 Amodié / مكري — privately leased hunting ground.
  amodie,

  /// 🟡 Zones Ouvertes / مفتوحة — open to any licensed hunter.
  open;

  static HuntZoneCategory fromString(String? value) {
    switch (value) {
      case 'reserve':
        return HuntZoneCategory.reserve;
      case 'amodie':
        return HuntZoneCategory.amodie;
      case 'open':
      default:
        return HuntZoneCategory.open;
    }
  }

  /// Marker/polygon color used consistently across the map + the
  /// layer-filter panel's toggle dots.
  Color get color {
    switch (this) {
      case HuntZoneCategory.reserve:
        return Colors.red;
      case HuntZoneCategory.amodie:
        return Colors.blue;
      case HuntZoneCategory.open:
        return Colors.amber;
    }
  }

  String get labelAr {
    switch (this) {
      case HuntZoneCategory.reserve:
        return 'محميات';
      case HuntZoneCategory.amodie:
        return 'مكري / مكرية';
      case HuntZoneCategory.open:
        return 'مناطق مفتوحة';
    }
  }

  String get labelFr {
    switch (this) {
      case HuntZoneCategory.reserve:
        return 'Réserves';
      case HuntZoneCategory.amodie:
        return 'Amodiations';
      case HuntZoneCategory.open:
        return 'Zones ouvertes';
    }
  }

  String get labelEn {
    switch (this) {
      case HuntZoneCategory.reserve:
        return 'Reserves';
      case HuntZoneCategory.amodie:
        return 'Leased Grounds';
      case HuntZoneCategory.open:
        return 'Open Zones';
    }
  }

  /// Best-effort, not native-speaker-reviewed — see app_strings.dart.
  String get labelZgh {
    switch (this) {
      case HuntZoneCategory.reserve:
        return 'ⵜⵉⵎⵍⴻⵍⵜⵉⵏ';
      case HuntZoneCategory.amodie:
        return 'ⵜⵉⴽⵔⴰⵢⵉⵏ';
      case HuntZoneCategory.open:
        return 'ⵜⵉⵖⵔⴻⵎⵜ ⵜⴰⵔⵓⵙⵙⴰⵏⵜ';
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

/// Represents a row from `public.map_zones` (read through the
/// `map_zones_geojson` view, which pre-converts the PostGIS `geom`
/// column with `st_asgeojson()` so the client never has to parse
/// raw EWKB polygon rings).
class MapZone {
  final String id;
  final String zoneName;
  final HuntZoneCategory category;
  final List<List<double>> polygon; // [[lng, lat], [lng, lat], ...]

  const MapZone({
    required this.id,
    required this.zoneName,
    required this.category,
    required this.polygon,
  });

  /// Builds a [MapZone] straight from a `map_zones_geojson` row:
  /// `{id, zone_name, category, geometry: {type, coordinates}}`.
  factory MapZone.fromSupabaseRow(Map<String, dynamic> row) {
    final geometry = row['geometry'] as Map<String, dynamic>;
    final coords = (geometry['coordinates'] as List).first as List;

    return MapZone(
      id: row['id'] as String,
      zoneName: row['zone_name'] as String,
      category: HuntZoneCategory.fromString(row['category'] as String?),
      polygon: coords
          .map<List<double>>(
            (p) => [(p[0] as num).toDouble(), (p[1] as num).toDouble()],
          )
          .toList(),
    );
  }

  /// Builds a [MapZone] from a standard GeoJSON Feature, e.g. the
  /// cached FeatureCollection persisted for offline use by
  /// [ZoneCheckService].
  factory MapZone.fromGeoJsonFeature(Map<String, dynamic> feature) {
    final props = feature['properties'] as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>;
    final coords = (geometry['coordinates'] as List).first as List;

    return MapZone(
      id: props['id'] as String,
      zoneName: props['zone_name'] as String,
      category: HuntZoneCategory.fromString(props['category'] as String?),
      polygon: coords
          .map<List<double>>(
            (p) => [(p[0] as num).toDouble(), (p[1] as num).toDouble()],
          )
          .toList(),
    );
  }

  /// Serializes back into a GeoJSON Feature for offline caching.
  Map<String, dynamic> toGeoJsonFeature() {
    return {
      'type': 'Feature',
      'properties': {
        'id': id,
        'zone_name': zoneName,
        'category': category.name,
      },
      'geometry': {
        'type': 'Polygon',
        'coordinates': [polygon],
      },
    };
  }

  /// Backward-compatible helper: true for the protected/forbidden
  /// ("reserve") category — used by [ZoneCheckService]'s GPS warning.
  bool get isForbidden => category == HuntZoneCategory.reserve;

  /// Ray-casting point-in-polygon test. Works fully offline once zones
  /// have been cached locally — no network call needed per check.
  bool containsPoint(double lng, double lat) {
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i][0], yi = polygon[i][1];
      final xj = polygon[j][0], yj = polygon[j][1];

      final intersects = ((yi > lat) != (yj > lat)) &&
          (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi);
      if (intersects) inside = !inside;
    }
    return inside;
  }
}
