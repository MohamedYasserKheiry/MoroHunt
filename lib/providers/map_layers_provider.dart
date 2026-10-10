import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Toggle state for every switch in the "طبقات الخريطة" panel.
/// Kept as one immutable snapshot so the whole panel + map rebuild
/// together off a single `ref.watch`.
///
/// Only two zone layers exist now — محميات (Réserve) and مكري
/// (Amodié). مناطق مفتوحة (open zones) and معالم (POIs) were removed
/// entirely: no state, no toggle, no rendering.
class MapLayersState {
  final bool isReserveVisible; // 🔴 Réserve / محميات
  final bool isAmodieVisible; // 🔵 Amodié / مكري
  final bool isSatelliteView; // 🛰️ Base Map: satellite imagery vs standard

  const MapLayersState({
    this.isReserveVisible = false,
    this.isAmodieVisible = false,
    this.isSatelliteView = false,
  });

  /// True as soon as either zone-category switch is on — lets the map
  /// screen decide in one check whether the layers button should show
  /// as "active".
  bool get anyZoneLayerVisible => isReserveVisible || isAmodieVisible;

  MapLayersState copyWith({
    bool? isReserveVisible,
    bool? isAmodieVisible,
    bool? isSatelliteView,
  }) {
    return MapLayersState(
      isReserveVisible: isReserveVisible ?? this.isReserveVisible,
      isAmodieVisible: isAmodieVisible ?? this.isAmodieVisible,
      isSatelliteView: isSatelliteView ?? this.isSatelliteView,
    );
  }
}

class MapLayersController extends StateNotifier<MapLayersState> {
  MapLayersController() : super(const MapLayersState());

  void toggleReserve(bool value) =>
      state = state.copyWith(isReserveVisible: value);

  void toggleAmodie(bool value) =>
      state = state.copyWith(isAmodieVisible: value);

  void toggleSatellite(bool value) =>
      state = state.copyWith(isSatelliteView: value);
}

final mapLayersProvider =
    StateNotifierProvider<MapLayersController, MapLayersState>(
  (ref) => MapLayersController(),
);
