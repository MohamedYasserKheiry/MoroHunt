import '../models/hunt_catch.dart';

/// Catches logged within ~11m of each other are treated as one "hunting
/// trip log" pin (same long-press upload session), shared between the
/// map screen and the profile gallery so both group photos identically.
String locationKeyFor(double lat, double lng) =>
    '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';

List<List<HuntCatch>> groupCatchesByLocation(List<HuntCatch> catches) {
  final groups = <String, List<HuntCatch>>{};
  for (final c in catches) {
    groups.putIfAbsent(locationKeyFor(c.lat, c.lng), () => []).add(c);
  }
  return groups.values.toList();
}
