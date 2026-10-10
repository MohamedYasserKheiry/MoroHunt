import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

import '../models/reserve_feature.dart';

/// Loads and parses the two bundled reserve/amodiation GeoJSON assets.
///
/// Parsing ~150k coordinate points (post-simplification — see
/// `assets/geo/README.md`) is real work, so the JSON decode + geometry
/// conversion for each file runs inside its own isolate via
/// `compute()`. The UI thread only ever touches the finished
/// `List<ReserveFeature>` — it never blocks on the parse itself.
class GeoReserveService {
  GeoReserveService._();
  static final GeoReserveService instance = GeoReserveService._();

  static const String reserveAsset = 'assets/geo/JEU_RESERVE.geojson';
  static const String amodiationAsset = 'assets/geo/AMODIATIONS_part1.geojson';

  /// Loads `JEU_RESERVE.geojson` (محميات — protected reserves).
  Future<List<ReserveFeature>> loadReserves() =>
      _loadAndParse(reserveAsset, ReserveSource.reserve);

  /// Loads `AMODIATIONS_part1.geojson` (مكري — leased hunting grounds).
  Future<List<ReserveFeature>> loadAmodiations() =>
      _loadAndParse(amodiationAsset, ReserveSource.amodiation);

  Future<List<ReserveFeature>> _loadAndParse(
    String assetPath,
    ReserveSource source,
  ) async {
    // Reading the asset itself is already async/non-blocking.
    final raw = await rootBundle.loadString(assetPath);
    // The actual JSON decode + LatLng conversion is CPU-bound, so it
    // goes through compute() to run on a background isolate.
    return compute(_parseGeoJsonInIsolate, _ParseRequest(raw, source));
  }
}

/// Plain-data message passed across the isolate boundary — must stay
/// free of closures/native handles, so it's just two primitives.
class _ParseRequest {
  final String raw;
  final ReserveSource source;
  const _ParseRequest(this.raw, this.source);
}

/// Top-level function so `compute()` can spawn it in a fresh isolate.
List<ReserveFeature> _parseGeoJsonInIsolate(_ParseRequest request) {
  final decoded = jsonDecode(request.raw) as Map<String, dynamic>;
  final rawFeatures = (decoded['features'] as List?) ?? const [];

  final results = <ReserveFeature>[];
  for (var i = 0; i < rawFeatures.length; i++) {
    final feature = rawFeatures[i] as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    if (geometry == null) continue;

    final parts = _partsFromGeometry(geometry);
    if (parts.isEmpty) continue;

    results.add(
      ReserveFeature(
        id: '${request.source.name}_$i',
        source: request.source,
        properties:
            (feature['properties'] as Map<String, dynamic>?) ?? const {},
        parts: parts,
      ),
    );
  }
  return results;
}

/// Handles both `Polygon` (single part) and `MultiPolygon` (one part
/// per disjoint shape) geometry types.
List<GeoPolygonPart> _partsFromGeometry(Map<String, dynamic> geometry) {
  final type = geometry['type'] as String?;
  final coordinates = geometry['coordinates'];
  if (coordinates == null) return const [];

  if (type == 'Polygon') {
    final part = _partFromRings(coordinates as List);
    return part == null ? const [] : [part];
  }

  if (type == 'MultiPolygon') {
    final parts = <GeoPolygonPart>[];
    for (final polygonRings in coordinates as List) {
      final part = _partFromRings(polygonRings as List);
      if (part != null) parts.add(part);
    }
    return parts;
  }

  // Any other geometry type (Point, LineString, ...) isn't a reserve
  // boundary — skip it rather than throw, so one malformed feature
  // never takes down the whole file.
  return const [];
}

/// `rings[0]` is the outer boundary; any further rings are holes.
GeoPolygonPart? _partFromRings(List rings) {
  if (rings.isEmpty) return null;
  final outer = _ringToLatLng(rings.first as List);
  if (outer.length < 3) return null;

  final holes = <List<LatLng>>[];
  for (var i = 1; i < rings.length; i++) {
    final hole = _ringToLatLng(rings[i] as List);
    if (hole.length >= 3) holes.add(hole);
  }
  return GeoPolygonPart(outer: outer, holes: holes);
}

List<LatLng> _ringToLatLng(List ring) {
  final points = <LatLng>[];
  for (final raw in ring) {
    final coord = raw as List;
    final lng = (coord[0] as num).toDouble();
    final lat = (coord[1] as num).toDouble();
    points.add(LatLng(lat, lng));
  }
  return points;
}
