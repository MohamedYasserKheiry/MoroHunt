import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';

class OfflineTileService {
  /// تهيئة الخدمة.
  /// حالياً لا نستخدم التخزين المؤقت، لذلك لا توجد تهيئة مطلوبة.
  static Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('OfflineTileService: Running on Web.');
      return;
    }

    debugPrint('OfflineTileService: Using direct network tiles.');
  }

  /// استخدام NetworkTileProvider مباشرةً بدون FMTC.
  static TileProvider get tileProvider {
    return NetworkTileProvider();
  }

  /// دالة احتياطية إذا تم طلبها كـ Method.
  static TileProvider getTileProvider() => tileProvider;
}