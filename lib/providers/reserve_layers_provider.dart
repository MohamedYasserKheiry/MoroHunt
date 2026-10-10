import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reserve_feature.dart';
import '../services/geo_reserve_service.dart';

/// محميات — protected reserve polygons, parsed once from
/// `assets/geo/JEU_RESERVE.geojson` and cached for the app's lifetime.
final reserveGeoFeaturesProvider = FutureProvider<List<ReserveFeature>>(
  (ref) => GeoReserveService.instance.loadReserves(),
);

/// مكري — leased hunting-ground polygons, parsed once from
/// `assets/geo/AMODIATIONS_part1.geojson`.
final amodiationGeoFeaturesProvider = FutureProvider<List<ReserveFeature>>(
  (ref) => GeoReserveService.instance.loadAmodiations(),
);

/// Combined bounds of every loaded reserve + amodiation polygon, used
/// once to auto-fit the map camera on first load. Resolves only once
/// both datasets have finished loading.
final reserveLayersBoundsProvider = FutureProvider<LatLngBounds?>((ref) async {
  final reserves = await ref.watch(reserveGeoFeaturesProvider.future);
  final amodiations = await ref.watch(amodiationGeoFeaturesProvider.future);

  LatLngBounds? bounds;
  for (final feature in [...reserves, ...amodiations]) {
    for (final part in feature.parts) {
      for (final point in part.outer) {
        if (bounds == null) {
          bounds = LatLngBounds(point, point);
        } else {
          bounds.extend(point);
        }
      }
    }
  }
  return bounds;
});
