import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../l10n/app_strings.dart';
import '../models/hunt_catch.dart';
import '../models/reserve_feature.dart';
import '../providers/locale_provider.dart';
import '../providers/map_layers_provider.dart';
import '../providers/reserve_layers_provider.dart';
import '../services/ad_service.dart';
import '../services/offline_tile_service.dart';
import '../services/supabase_service.dart';
import '../services/zone_check_service.dart';
import '../utils/catch_grouping.dart';
import '../widgets/map_controls.dart';
import '../widgets/map_layers_panel.dart';
import '../widgets/photo_swipe_viewer.dart';

/// Tab 1 — "خريطة القنص": the main hunting map.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.isActive = true});

  /// Whether the Map tab is currently the visible tab. The shell keeps
  /// this screen alive in an IndexedStack, so a false -> true change is
  /// how the screen learns it has been "opened" again.
  final bool isActive;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const LatLng _moroccoCenter = LatLng(31.7917, -7.0926);

  String _tr(String key) =>
      AppStrings.translate(key, ref.read(localeProvider));

  // OpenStreetMap standard map.
  // No API key is required.
  static const _standardTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // ArcGIS World Imagery satellite map.
  static const _satelliteTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  StreamSubscription<geo.Position>? _gpsSubscription;
  StreamSubscription<void>? _catchesChangedSubscription;

  List<HuntCatch> _communityCatches = [];
  bool _loadingCatches = true;
  bool _searching = false;

  bool _showPhotosLayer = false;
  bool _isLayersPanelOpen = false;

  double _currentZoom = 6;

  bool _didAutoFitReserveBounds = false;

  LatLng? _myLocation;
  LatLng _mapCenter = _moroccoCenter;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await ZoneCheckService.instance.initNotifications();
    await ZoneCheckService.instance.loadCachedZones();
    unawaited(ZoneCheckService.instance.refreshZonesFromSupabase());
    await _requestLocationPermission();
    // First Map opening of this session. Triggered after the permission
    // prompt so the ad never competes with a system dialog. Fire-and-forget.
    _showOpenInterstitial();
    _startGpsTracking();
    await _loadCommunityCatches();

    _catchesChangedSubscription =
        SupabaseService.instance.catchesChangedStream.listen((_) {
      _loadCommunityCatches();
    });
  }

  Future<void> _requestLocationPermission() async {
    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
  }

  Future<void> _loadCommunityCatches() async {
    try {
      final catches =
          await SupabaseService.instance.fetchCommunityCatches();

      if (mounted) {
        setState(() {
          _communityCatches = catches;
          _loadingCatches = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingCatches = false);
      }
    }
  }

  void _startGpsTracking() {
    const settings = geo.LocationSettings(
      accuracy: geo.LocationAccuracy.high,
      distanceFilter: 5,
    );

    _gpsSubscription =
        geo.Geolocator.getPositionStream(locationSettings: settings)
            .listen((position) {
      ZoneCheckService.instance.evaluatePosition(
        lat: position.latitude,
        lng: position.longitude,
        language: ref.read(localeProvider),
      );

      if (mounted) {
        setState(() {
          _myLocation = LatLng(
            position.latitude,
            position.longitude,
          );
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // User switched back to the Map tab: that is one new "opening".
    // Ordinary rebuilds keep isActive unchanged and do nothing here.
    if (widget.isActive && !oldWidget.isActive) {
      _showOpenInterstitial();
    }
  }

  /// Requests the interstitial for ONE Map opening. Called only from the
  /// initial bootstrap and from the false -> true isActive transition —
  /// never from build() — so widget rebuilds can't trigger extra ads.
  /// Non-blocking: if no ad is ready the map is simply left as it is.
  void _showOpenInterstitial() {
    if (!mounted || !widget.isActive) return;
    unawaited(
      AdService.instance.showInterstitialIfAvailable(
        // Skip if the user left the Map while the ad was still loading.
        shouldShow: () => mounted && widget.isActive,
      ),
    );
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _catchesChangedSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // SEARCH
  // ---------------------------------------------------------------------

  Future<void> _handleSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() => _searching = true);

    try {
      final directMatch =
          RegExp(r'^\s*(-?\d+(\.\d+)?)\s*,\s*(-?\d+(\.\d+)?)\s*$');

      final match = directMatch.firstMatch(trimmed);

      if (match != null) {
        final lat = double.parse(match.group(1)!);
        final lng = double.parse(match.group(3)!);

        _mapController.move(
          LatLng(lat, lng),
          13,
        );

        return;
      }

      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeQueryComponent(trimmed)}'
        '&countrycodes=ma&format=json&limit=1',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'MoroHuntApp/1.0',
        },
      );

      if (response.statusCode == 200) {
        final results = jsonDecode(response.body) as List;

        if (results.isNotEmpty) {
          final lat = double.parse(results.first['lat'] as String);
          final lng = double.parse(results.first['lon'] as String);

          _mapController.move(
            LatLng(lat, lng),
            12,
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_tr('search_no_results')),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr('search_failed')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  // ---------------------------------------------------------------------
  // ZOOM + LOCATE CONTROLS
  // ---------------------------------------------------------------------

  void _zoomIn() {
    final camera = _mapController.camera;
    _mapController.move(
      camera.center,
      camera.zoom + 1,
    );
  }

  void _zoomOut() {
    final camera = _mapController.camera;
    _mapController.move(
      camera.center,
      camera.zoom - 1,
    );
  }

  Future<void> _centerOnMyLocation() async {
    LatLng? target = _myLocation;

    if (target == null) {
      try {
        final pos = await geo.Geolocator.getCurrentPosition();

        target = LatLng(
          pos.latitude,
          pos.longitude,
        );

        setState(() => _myLocation = target);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _tr('location_failed_generic'),
              ),
            ),
          );
        }

        return;
      }
    }

    _mapController.move(
      target,
      15,
    );
  }

  // ---------------------------------------------------------------------
  // LAYER PANEL
  // ---------------------------------------------------------------------

  void _toggleLayersPanel() {
    setState(() {
      if (_isLayersPanelOpen) {
        _isLayersPanelOpen = false;
      } else {
        _isLayersPanelOpen = true;

        if (_showPhotosLayer) {
          _showPhotosLayer = false;
        }
      }
    });
  }

  void _toggleSatelliteView() {
    final layers = ref.read(mapLayersProvider);

    ref
        .read(mapLayersProvider.notifier)
        .toggleSatellite(!layers.isSatelliteView);
  }

  void _togglePhotosLayer() {
    final layersController =
        ref.read(mapLayersProvider.notifier);

    setState(() {
      if (_showPhotosLayer) {
        _showPhotosLayer = false;
      } else {
        _showPhotosLayer = true;
        _isLayersPanelOpen = false;

        layersController
          ..toggleReserve(false)
          ..toggleAmodie(false);
      }
    });
  }

  // ---------------------------------------------------------------------
  // PHOTO GROUPING + VIEWER
  // ---------------------------------------------------------------------

  void _openPhotoGroupPopup(List<HuntCatch> group) {
    showPhotoSwipeViewer(
      context,
      group,
    );
  }

  // ---------------------------------------------------------------------
  // LONG-PRESS TO LOG A CATCH
  // ---------------------------------------------------------------------

  Future<void> _handleMapLongPress(LatLng point) async {
    final result = await showModalBottomSheet<_CatchUploadResult>(
      context: context,
      backgroundColor: const Color(0xFF1C1F1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) => _CatchUploadSheet(
        imagePicker: _imagePicker,
      ),
    );

    if (result == null || result.images.isEmpty) {
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(_tr('uploading_photos')),
          ],
        ),
      ),
    );

    try {
      for (final image in result.images) {
        final bytes = await image.readAsBytes();

        await SupabaseService.instance.logCatch(
          imageBytes: bytes,
          preyType: result.preyType,
          lat: point.latitude,
          lng: point.longitude,
        );
      }

      await _loadCommunityCatches();

      setState(() => _showPhotosLayer = true);

      ref.read(mapLayersProvider.notifier)
        ..toggleReserve(false)
        ..toggleAmodie(false);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_tr('photo_upload_failed')}: $e',
            ),
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  double _reserveBorderStrokeWidthForZoom(double zoom) {
    if (zoom < 7) return 0.4;
    if (zoom < 9) return 0.7;
    if (zoom < 11) return 1.0;
    if (zoom < 13) return 1.5;
    return 2.2;
  }

  @override
  Widget build(BuildContext context) {
    final mapLayers = ref.watch(mapLayersProvider);

    final reservesAsync =
        ref.watch(reserveGeoFeaturesProvider);

    final amodiationsAsync =
        ref.watch(amodiationGeoFeaturesProvider);

    final List<ReserveFeature> reserveFeatures =
        reservesAsync.maybeWhen(
      data: (f) => f,
      orElse: () => const <ReserveFeature>[],
    );

    final List<ReserveFeature> amodiationFeatures =
        amodiationsAsync.maybeWhen(
      data: (f) => f,
      orElse: () => const <ReserveFeature>[],
    );

    ref.listen<AsyncValue<LatLngBounds?>>(
      reserveLayersBoundsProvider,
      (previous, next) {
        final bounds = next.valueOrNull;

        if (bounds != null && !_didAutoFitReserveBounds) {
          _didAutoFitReserveBounds = true;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(24),
              ),
            );
          });
        }
      },
    );

    final borderStrokeWidth =
        _reserveBorderStrokeWidthForZoom(_currentZoom);

    final groupedList =
        groupCatchesByLocation(_communityCatches);

    final locationGroups = <String, List<HuntCatch>>{
      for (final g in groupedList)
        locationKeyFor(
          g.first.lat,
          g.first.lng,
        ): g,
    };

    final photoMarkers = locationGroups.values.map((group) {
      final cover = group.first;

      final capped =
          group.length > 5 ? group.sublist(0, 5) : group;

      return Marker(
        point: LatLng(
          cover.lat,
          cover.lng,
        ),
        width: 64,
        height: 62,
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () => _openPhotoGroupPopup(capped),
          child: _ApplePhotoMarker(
            imageUrl: cover.imageUrl,
            preyType: cover.preyType,
            count: group.length > 1 ? group.length : null,
          ),
        ),
      );
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _moroccoCenter,
              initialZoom: 6,
              minZoom: 3,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onLongPress: (tapPosition, point) =>
                  _handleMapLongPress(point),
              onPositionChanged: (camera, hasGesture) {
                setState(() {
                  _mapCenter = camera.center;
                  _currentZoom = camera.zoom;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: mapLayers.isSatelliteView
                    ? _satelliteTileUrl
                    : _standardTileUrl,
                userAgentPackageName: 'com.example.morohunt',
                tileProvider:
                    OfflineTileService.tileProvider,
              ),

              // OpenStreetMap attribution.
              if (!mapLayers.isSatelliteView)
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                    ),
                  ],
                ),

              // مكري
              if (mapLayers.isAmodieVisible &&
                  amodiationFeatures.isNotEmpty)
                PolygonLayer(
                  polygons: [
                    for (final feature in amodiationFeatures)
                      for (final part in feature.parts)
                        Polygon(
                          points: part.outer,
                          holePointsList:
                              part.holes.isEmpty
                                  ? null
                                  : part.holes,
                          color:
                              Colors.blue.withValues(alpha: 0.22),
                          borderColor: Colors.blue,
                          borderStrokeWidth:
                              borderStrokeWidth,
                        ),
                  ],
                ),

              // محميات
              if (mapLayers.isReserveVisible &&
                  reserveFeatures.isNotEmpty)
                PolygonLayer(
                  polygons: [
                    for (final feature in reserveFeatures)
                      for (final part in feature.parts)
                        Polygon(
                          points: part.outer,
                          holePointsList:
                              part.holes.isEmpty
                                  ? null
                                  : part.holes,
                          color:
                              Colors.red.withValues(alpha: 0.22),
                          borderColor: Colors.red,
                          borderStrokeWidth:
                              borderStrokeWidth,
                        ),
                  ],
                ),

              if (_showPhotosLayer)
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 60,
                    size: const Size(64, 62),
                    zoomToBoundsOnClick: true,
                    markers: photoMarkers,
                    builder: (context, markers) {
                      final totalPhotos =
                          markers.fold<int>(
                        0,
                        (sum, m) {
                          final key = locationKeyFor(
                            m.point.latitude,
                            m.point.longitude,
                          );

                          return sum +
                              (locationGroups[key]?.length ?? 1);
                        },
                      );

                      final firstKey = locationKeyFor(
                        markers.first.point.latitude,
                        markers.first.point.longitude,
                      );

                      final previewUrl =
                          locationGroups[firstKey]
                              ?.first
                              .imageUrl;

                      final previewPreyType =
                          locationGroups[firstKey]
                              ?.first
                              .preyType;

                      return _ApplePhotoMarker(
                        imageUrl: previewUrl,
                        preyType: previewPreyType,
                        count: totalPhotos,
                        showGhosts: true,
                      );
                    },
                  ),
                ),

              // Live GPS blue dot.
              if (_myLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _myLocation!,
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blueAccent,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ---------------- Floating search bar ----------------
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SafeArea(
              bottom: false,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFF1C1F1A),
                child: TextField(
                  controller: _searchController,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: _tr('map_search_hint'),
                    hintStyle: const TextStyle(
                      color: Colors.white54,
                    ),
                    prefixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(
                              Icons.search,
                              color: Colors.white70,
                            ),
                            onPressed: () =>
                                _handleSearch(
                              _searchController.text,
                            ),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding:
                        const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 12,
                    ),
                  ),
                  onSubmitted: _handleSearch,
                ),
              ),
            ),
          ),

          // -------- Layer-control buttons --------
          Positioned(
            top: 84,
            right: 16,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  LayerControlButton(
                    icon: mapLayers.isSatelliteView
                        ? Icons.map_outlined
                        : Icons.satellite_alt,
                    tooltip: mapLayers.isSatelliteView
                        ? _tr('normal_map')
                        : _tr('toggle_satellite'),
                    active: mapLayers.isSatelliteView,
                    onTap: _toggleSatelliteView,
                  ),
                  const SizedBox(height: 10),
                  LayerControlButton(
                    icon: Icons.photo_library_outlined,
                    tooltip:
                        _tr('photos_layer_tooltip'),
                    active: _showPhotosLayer,
                    onTap: _togglePhotosLayer,
                  ),
                  const SizedBox(height: 10),
                  LayerControlButton(
                    icon: Icons.layers_outlined,
                    tooltip: _tr('map_layers_title'),
                    active: _isLayersPanelOpen,
                    onTap: _toggleLayersPanel,
                  ),
                ],
              ),
            ),
          ),

          // ---- Map layers side card ----
          if (_isLayersPanelOpen)
            Positioned(
              top: 196,
              right: 68,
              child: SafeArea(
                bottom: false,
                child: MapLayersSidePanel(
                  onClose: () => setState(
                    () => _isLayersPanelOpen = false,
                  ),
                ),
              ),
            ),

          // ------- Zoom + locate controls -------
          Positioned(
            bottom: 56,
            right: 16,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  ZoomButton(
                    icon: Icons.add,
                    onTap: _zoomIn,
                  ),
                  const SizedBox(height: 8),
                  ZoomButton(
                    icon: Icons.remove,
                    onTap: _zoomOut,
                  ),
                  const SizedBox(height: 8),
                  ZoomButton(
                    icon: Icons.my_location,
                    onTap: _centerOnMyLocation,
                  ),
                ],
              ),
            ),
          ),

          // -------------- Coordinates ribbon -------------
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1F1A)
                        .withValues(alpha: 0.9),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: Text(
                    'LAT: ${_mapCenter.latitude.toStringAsFixed(5)}   '
                    'LNG: ${_mapCenter.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFeatures: [
                        FontFeature.tabularFigures()
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (_loadingCatches)
            Positioned(
              top: 84,
              left: 16,
              child: SafeArea(
                bottom: false,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1F1A),
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Apple Photos-map-style marker.
IconData _speciesIcon(PreyType? type) {
  switch (type) {
    case PreyType.perdrix:
      return Icons.egg_alt_outlined;
    case PreyType.lievre:
      return Icons.cruelty_free_outlined;
    case PreyType.sanglier:
      return Icons.pets;
    case PreyType.caille:
      return Icons.flutter_dash;
    case PreyType.tourtereau:
      return Icons.air;
    case null:
      return Icons.image_outlined;
  }
}

class _ApplePhotoMarker extends StatelessWidget {
  final String? imageUrl;
  final PreyType? preyType;
  final int? count;
  final bool showGhosts;

  const _ApplePhotoMarker({
    this.imageUrl,
    this.preyType,
    this.count,
    this.showGhosts = false,
  });

  Widget _ghost(double angle) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(11),
          color: Colors.white24,
          border: Border.all(
            color: Colors.white54,
            width: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _mainTile() {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white,
          width: 2.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(9.5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            (imageUrl == null ||
                    imageUrl!.isEmpty)
                ? Container(
                    color: Colors.brown.shade300,
                    alignment: Alignment.center,
                    child: Icon(
                      _speciesIcon(preyType),
                      color: Colors.white,
                      size: 24,
                    ),
                  )
                : Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (context, error, stack) =>
                            Container(
                      color:
                          Colors.brown.shade300,
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ),
            if (count != null && count! > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 18,
                  decoration:
                      const BoxDecoration(
                    gradient: LinearGradient(
                      begin:
                          Alignment.topCenter,
                      end:
                          Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black87,
                      ],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 62,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (showGhosts)
            Positioned(
              top: -4,
              left: 23,
              child: _ghost(0.18),
            ),
          if (showGhosts)
            Positioned(
              top: -2,
              left: 7,
              child: _ghost(-0.14),
            ),
          Positioned(
            top: 0,
            left: 5,
            child: _mainTile(),
          ),
          const Positioned(
            top: 52,
            left: 25,
            child: _PointerAnchor(),
          ),
        ],
      ),
    );
  }
}

class _PointerAnchor extends StatelessWidget {
  const _PointerAnchor();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(14, 8),
      painter: _PointerPainter(),
    );
  }
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(
        size.width / 2,
        size.height,
      )
      ..close();

    canvas.drawShadow(
      path,
      Colors.black45,
      2,
      false,
    );

    canvas.drawPath(
      path,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) =>
      false;
}

class _CatchUploadResult {
  final List<XFile> images;
  final PreyType preyType;

  const _CatchUploadResult({
    required this.images,
    required this.preyType,
  });
}

class _CatchUploadSheet
    extends ConsumerStatefulWidget {
  final ImagePicker imagePicker;

  const _CatchUploadSheet({
    required this.imagePicker,
  });

  @override
  ConsumerState<_CatchUploadSheet> createState() =>
      _CatchUploadSheetState();
}

class _CatchUploadSheetState
    extends ConsumerState<_CatchUploadSheet> {
  List<XFile> _selectedImages = [];
  PreyType _preyType = PreyType.perdrix;

  Future<void> _pickImages() async {
    final picked =
        await widget.imagePicker.pickMultiImage(
      limit: 5,
      maxWidth: 1600,
      imageQuality: 85,
    );

    if (picked.isEmpty) return;

    setState(() {
      _selectedImages =
          picked.length > 5
              ? picked.sublist(0, 5)
              : picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final language =
        ref.watch(localeProvider);

    String tr(String key) =>
        AppStrings.translate(
          key,
          language,
        );

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom:
            MediaQuery.of(context)
                    .viewInsets
                    .bottom +
                20,
      ),
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('log_hunt_title'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<PreyType>(
            initialValue: _preyType,
            dropdownColor:
                const Color(0xFF1C1F1A),
            style: const TextStyle(
              color: Colors.white,
            ),
            decoration: InputDecoration(
              labelText:
                  tr('prey_type_label'),
              labelStyle:
                  const TextStyle(
                color: Colors.white70,
              ),
              border:
                  const OutlineInputBorder(),
            ),
            items: PreyType.values
                .map(
                  (p) => DropdownMenuItem(
                    value: p,
                    child: Text(
                      p.label(language),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(
                  () => _preyType = value,
                );
              }
            },
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickImages,
            icon: const Icon(
              Icons.add_a_photo_outlined,
            ),
            label: Text(
              _selectedImages.isEmpty
                  ? tr(
                      'choose_up_to_5_photos',
                    )
                  : tr(
                      'selected_n_photos',
                    ).replaceAll(
                      '{n}',
                      '${_selectedImages.length}',
                    ),
            ),
          ),
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection:
                    Axis.horizontal,
                itemCount:
                    _selectedImages.length,
                separatorBuilder:
                    (_, __) =>
                        const SizedBox(
                  width: 8,
                ),
                itemBuilder:
                    (context, index) =>
                        ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                  child:
                      FutureBuilder<
                          Uint8List>(
                    future:
                        _selectedImages[
                                index]
                            .readAsBytes(),
                    builder: (
                      context,
                      snapshot,
                    ) {
                      if (!snapshot.hasData) {
                        return Container(
                          width: 70,
                          height: 70,
                          color:
                              Colors.white10,
                          child:
                              const Center(
                            child:
                                SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        );
                      }

                      return Image.memory(
                        snapshot.data!,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed:
                _selectedImages.isEmpty
                    ? null
                    : () => Navigator.pop(
                          context,
                          _CatchUploadResult(
                            images:
                                _selectedImages,
                            preyType:
                                _preyType,
                          ),
                        ),
            child: Text(
              tr('upload_photos_button'),
            ),
          ),
        ],
      ),
    );
  }
}