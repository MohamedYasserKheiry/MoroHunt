import 'package:latlong2/latlong.dart';

/// One "polygon part": an outer ring plus any interior holes.
/// A `Polygon` GeoJSON geometry has exactly one part; a `MultiPolygon`
/// has one part per disjoint shape (e.g. a reserve split across two
/// separate areas).
class GeoPolygonPart {
  final List<LatLng> outer;
  final List<List<LatLng>> holes;

  const GeoPolygonPart({required this.outer, this.holes = const []});
}

/// Which local GeoJSON asset a feature came from — also doubles as
/// the hunting-zone category it visually maps to on the Layer Filter
/// side panel (مكري / محميات).
enum ReserveSource {
  /// JEU_RESERVE.geojson — محمية (protected game reserve).
  reserve,

  /// AMODIATIONS_part1.geojson — أرض مكرية (leased hunting ground).
  amodiation,
}

/// A single reserve/amodiation polygon parsed from the local GeoJSON
/// assets, with its full `properties` payload preserved for the
/// detail bottom sheet.
class ReserveFeature {
  final String id;
  final ReserveSource source;
  final Map<String, dynamic> properties;
  final List<GeoPolygonPart> parts;

  const ReserveFeature({
    required this.id,
    required this.source,
    required this.properties,
    required this.parts,
  });

  /// Best-effort human name pulled from whichever property key this
  /// dataset actually uses ("Nom" for reserves, "AMODIATAIR" for
  /// amodiations) — falls back to a generic label per source.
  String get displayName {
    for (final key in ['Nom', 'NOM', 'nom', 'name', 'AMODIATAIR']) {
      final value = properties[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    switch (source) {
      case ReserveSource.reserve:
        return 'محمية صيد';
      case ReserveSource.amodiation:
        return 'أرض مكرية';
    }
  }
}
