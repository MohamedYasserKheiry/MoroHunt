import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

/// Parses a PostGIS EWKB (Extended Well-Known Binary) hex string — the
/// format Postgres returns when you cast a `geometry` column with
/// `::text` in a Supabase/PostgREST select, e.g. `geom::text`.
///
/// This is NOT GeoJSON. A raw Point value looks like:
///   "0101000020E6100000<16 hex bytes for X><16 hex bytes for Y>"
///     01              -> byte order (01 = little-endian)
///     01000020        -> geometry type (Point) with the SRID flag set
///     E6100000        -> SRID, little-endian uint32 (0x000010E6 = 4326)
///     <8 bytes>       -> X (longitude), IEEE-754 double
///     <8 bytes>       -> Y (latitude), IEEE-754 double
///
/// Passing this hex string straight into `jsonDecode`/`as Map` (the bug
/// this fixes) throws exactly the runtime error this app hit:
/// `TypeError: '0101000020E6...' type 'String' is not a subtype of
/// type 'Map<String, dynamic>'`.
LatLng parseEwkbPointHex(String hex) {
  final bytes = _hexToBytes(hex.trim());
  final data = ByteData.sublistView(bytes);

  var offset = 0;
  final isLittleEndian = data.getUint8(offset) == 1;
  final endian = isLittleEndian ? Endian.little : Endian.big;
  offset += 1;

  final geometryType = data.getUint32(offset, endian);
  offset += 4;

  // The high bit (0x20000000) marks "has SRID" in EWKB.
  final hasSrid = (geometryType & 0x20000000) != 0;
  if (hasSrid) {
    offset += 4; // skip the SRID uint32, we assume 4326 throughout
  }

  final x = data.getFloat64(offset, endian); // longitude
  offset += 8;
  final y = data.getFloat64(offset, endian); // latitude

  return LatLng(y, x);
}

Uint8List _hexToBytes(String hex) {
  final length = hex.length ~/ 2;
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}
