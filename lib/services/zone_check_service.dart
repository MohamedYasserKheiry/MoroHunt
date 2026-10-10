import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../models/map_zone.dart';
import '../providers/locale_provider.dart';
import 'supabase_service.dart';

/// Handles offline caching of hunting-zone polygons (downloaded once
/// while online) and pure-local point-in-polygon checks against the
/// user's GPS fix — no network round-trip required in the field.
///
/// Uses SharedPreferences (not raw file I/O) specifically so this works
/// identically on web/Chrome as well as mobile/desktop.
class ZoneCheckService {
  ZoneCheckService._internal();
  static final ZoneCheckService instance = ZoneCheckService._internal();

  static const _cacheKey = 'morohunt_cached_map_zones';

  List<MapZone> _cachedZones = [];
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _lastWarningWasForbidden = false;

  Future<void> initNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    try {
      await _notifications.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
      );
    } catch (_) {
      // Local notifications aren't available on web — safe to ignore
      // there; forbidden-zone warnings simply won't show as OS
      // notifications in a browser tab.
    }
  }

  /// Persists a GeoJSON FeatureCollection (fetched from `map_zones`
  /// while online) so it survives offline sessions in the field.
  Future<void> cacheZonesFromGeoJson(Map<String, dynamic> featureCollection) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(featureCollection));
    _loadZonesFromJson(featureCollection);
  }

  /// Loads previously cached zones on app start / offline boot.
  Future<void> loadCachedZones() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) {
      _cachedZones = [];
      return;
    }
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _loadZonesFromJson(json);
  }

  void _loadZonesFromJson(Map<String, dynamic> featureCollection) {
    final features = featureCollection['features'] as List;
    _cachedZones = features
        .map((f) => MapZone.fromGeoJsonFeature(f as Map<String, dynamic>))
        .toList();
  }

  List<MapZone> get cachedZones => List.unmodifiable(_cachedZones);

  /// Pulls the latest zones from Supabase and refreshes both the
  /// in-memory list and the offline cache. Safe to call on every map
  /// screen load — falls back silently to whatever is already cached
  /// (or an empty list) if the device is offline.
  Future<void> refreshZonesFromSupabase() async {
    try {
      final featureCollection =
          await SupabaseService.instance.fetchHuntingZonesAsFeatureCollection();
      await cacheZonesFromGeoJson(featureCollection);
    } catch (_) {
      // Offline or request failed — keep using whatever is cached.
    }
  }

  /// Checks [lat]/[lng] against every cached zone. Returns the matching
  /// forbidden zone if the point falls inside one, or null otherwise.
  MapZone? checkForbiddenZone({required double lat, required double lng}) {
    for (final zone in _cachedZones) {
      if (zone.isForbidden && zone.containsPoint(lng, lat)) {
        return zone;
      }
    }
    return null;
  }

  /// Call this on every GPS update during a hunt. Fires a persistent
  /// local notification the moment the hunter crosses into a forbidden
  /// polygon, and clears the flag once they exit it. [language]
  /// controls the notification's text — defaults to Arabic if the
  /// caller doesn't have a language handy.
  Future<void> evaluatePosition({
    required double lat,
    required double lng,
    AppLanguage language = AppLanguage.arabic,
  }) async {
    final forbiddenZone = checkForbiddenZone(lat: lat, lng: lng);

    if (forbiddenZone != null && !_lastWarningWasForbidden) {
      _lastWarningWasForbidden = true;
      await _showForbiddenZoneWarning(forbiddenZone, language);
    } else if (forbiddenZone == null) {
      _lastWarningWasForbidden = false;
    }
  }

  Future<void> _showForbiddenZoneWarning(MapZone zone, AppLanguage language) async {
    const androidDetails = AndroidNotificationDetails(
      'forbidden_zone_channel',
      'Forbidden Zone Alerts',
      channelDescription:
          'Warns when entering a protected / forbidden hunting zone',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
    );
    const details = NotificationDetails(android: androidDetails);

    try {
      await _notifications.show(
        1001,
        AppStrings.translate('forbidden_zone_notif_title', language),
        AppStrings.translate('forbidden_zone_notif_body', language)
            .replaceAll('{zone}', zone.zoneName),
        details,
      );
    } catch (_) {
      // No-op on platforms without local notification support (web).
    }
  }
}
