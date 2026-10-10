import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:latlong2/latlong.dart';

import '../l10n/app_strings.dart';
import '../models/hunt_catch.dart';
import '../models/hunter_profile.dart';
import '../models/room_member.dart';
import '../providers/locale_provider.dart';
import '../services/offline_tile_service.dart';
import '../services/supabase_service.dart';
import '../widgets/map_controls.dart';
import '../widgets/room_members_drawer.dart';

/// Tab 3 — "قنص جماعي": starts as a simple dashboard with two actions
/// (create a room / join via code — capped at
/// [SupabaseService.maxRoomCapacity] hunters per room). Once a room is
/// active, this screen swaps to a live team-tracking map: every other
/// hunter is rendered as their actual profile picture with their name
/// underneath (not a generic pin), refreshed both by Supabase Realtime
/// and a background poll — no manual refresh needed.
class GroupHuntScreen extends ConsumerStatefulWidget {
  const GroupHuntScreen({super.key});

  @override
  ConsumerState<GroupHuntScreen> createState() => _GroupHuntScreenState();
}

class _GroupHuntScreenState extends ConsumerState<GroupHuntScreen> {
  final MapController _mapController = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  StreamSubscription<List<LiveHunterPosition>>? _positionsSubscription;
  StreamSubscription<List<RoomMember>>? _membersSubscription;
  StreamSubscription<void>? _kickedSubscription;

  String? _activeSessionId;
  String? _activeRoomCode;
  bool _busy = false;
  bool _isAdmin = false;
  List<RoomMember> _members = [];
  String? _membersError;

  LatLng _myPosition = const LatLng(31.7917, -7.0926);
  LatLng _mapCenter = const LatLng(31.7917, -7.0926);
  List<LiveHunterPosition> _teamPositions = [];
  HunterProfile? _myProfile;

  // Cache of profile lookups for every hunter seen in this room, so we
  // don't re-fetch on every position update. Null value = still loading.
  final Map<String, HunterProfile?> _profileCache = {};

  bool _isSatelliteView = false;
  // Esri World Street Map — synced with map_screen.dart, and fixes the
  // same dashed-Sahara-border issue OpenStreetMap's default stylesheet
  // has (this screen was still on plain OSM tiles before this change).
  static const _standardTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}';
  // Real high-resolution satellite imagery — synced with map_screen.dart.
  // Pure aerial photography with no vector boundary data, so Morocco/
  // Western Sahara reads as one unbroken territory here (no dashed line).
  static const _satelliteTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  @override
  void dispose() {
    _positionsSubscription?.cancel();
    _membersSubscription?.cancel();
    _kickedSubscription?.cancel();
    SupabaseService.instance.stopBroadcastingLocation();
    super.dispose();
  }

  Future<void> _createRoom() async {
    setState(() => _busy = true);
    try {
      final session = await SupabaseService.instance.createRoom();
      await _startRoomTracking(session.id, session.roomCode, session.creatorId);
    } catch (e) {
      _showCriticalError(_tr('room_create_failed'), '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinRoomDialog() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr('join_hunt_room')),
        content: TextField(
          controller: controller,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(hintText: 'HUNTER-123'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(_tr('join')),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;

    setState(() => _busy = true);
    try {
      final session = await SupabaseService.instance.joinRoom(code);
      await _startRoomTracking(session.id, session.roomCode, session.creatorId);
    } catch (e) {
      _showCriticalError(_tr('room_join_failed'), '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startRoomTracking(
    String sessionId,
    String roomCode,
    String creatorId,
  ) async {
    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }

    setState(() {
      _activeSessionId = sessionId;
      _activeRoomCode = roomCode;
      _isAdmin = SupabaseService.instance.currentUserId == creatorId;
      _membersError = null;
      _members = [];
    });

    // Load our own profile once so we can render our own avatar+name
    // marker below, exactly like every other hunter in the room.
    final myId = SupabaseService.instance.currentUserId;
    if (myId != null) {
      SupabaseService.instance.fetchProfile(myId).then((profile) {
        if (mounted) setState(() => _myProfile = profile);
      }).catchError((_) {
        // Leave as null on failure — marker falls back to an initial.
      });
    }

    SupabaseService.instance.startBroadcastingLocation(
      sessionId: sessionId,
      getCurrentPosition: () async {
        final pos = await geo.Geolocator.getCurrentPosition();
        setState(() => _myPosition = LatLng(pos.latitude, pos.longitude));
        return (
          lat: pos.latitude,
          lng: pos.longitude,
          speedKmh: pos.speed * 3.6
        );
      },
    );

    // Realtime websocket updates + a 7-second background poll (inside
    // SupabaseService.subscribeToRoom) both feed this same stream, so
    // team positions stay current with no manual refresh required.
    _positionsSubscription =
        SupabaseService.instance.positionsStream.listen((positions) {
      if (!mounted) return;
      setState(() => _teamPositions = positions);
      _ensureProfilesLoaded(positions);
    });

    // Live members sidebar — updates instantly for everyone the moment
    // anyone joins, leaves, or gets kicked.
    _membersSubscription = SupabaseService.instance.membersStream.listen(
      (members) {
        if (!mounted) return;
        setState(() {
          _members = members;
          _membersError = null;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _membersError = '$e');
      },
    );

    // Fires exactly once if THIS device gets removed by the admin —
    // never for our own voluntary leave.
    _kickedSubscription = SupabaseService.instance.kickedStream.listen((_) {
      _handleKicked();
    });
  }

  Future<void> _handleKicked() async {
    if (!mounted || _activeSessionId == null) return;
    // Tear down local state the same way a voluntary leave would —
    // the participant row is already gone server-side, this just
    // cleans up subscriptions/timers on this device.
    await SupabaseService.instance.leaveRoom(_activeSessionId!);
    await _positionsSubscription?.cancel();
    await _membersSubscription?.cancel();
    await _kickedSubscription?.cancel();
    if (!mounted) return;
    setState(() {
      _activeSessionId = null;
      _activeRoomCode = null;
      _teamPositions = [];
      _members = [];
      _isAdmin = false;
      _profileCache.clear();
    });

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_tr('kicked_title')),
          content: Text(_tr('kicked_message')),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_tr('ok')),
            ),
          ],
        ),
      );
    }
  }

  void _ensureProfilesLoaded(List<LiveHunterPosition> positions) {
    final myId = SupabaseService.instance.currentUserId;
    for (final p in positions) {
      if (p.userId == myId) continue; // don't need our own profile card
      if (_profileCache.containsKey(p.userId)) continue;
      _profileCache[p.userId] = null; // mark as loading
      SupabaseService.instance.fetchProfile(p.userId).then((profile) {
        if (mounted) setState(() => _profileCache[p.userId] = profile);
      }).catchError((_) {
        // Leave as null on failure — marker falls back to an initial.
      });
    }
  }

  Future<void> _leaveRoom() async {
    if (_activeSessionId == null) return;
    await SupabaseService.instance.leaveRoom(_activeSessionId!);
    await _positionsSubscription?.cancel();
    await _membersSubscription?.cancel();
    await _kickedSubscription?.cancel();
    setState(() {
      _activeSessionId = null;
      _activeRoomCode = null;
      _teamPositions = [];
      _members = [];
      _isAdmin = false;
      _profileCache.clear();
    });
  }

  Future<void> _endSession() async {
    if (_activeSessionId == null) return;
    await SupabaseService.instance.endSession(_activeSessionId!);
    await _positionsSubscription?.cancel();
    await _membersSubscription?.cancel();
    await _kickedSubscription?.cancel();
    setState(() {
      _activeSessionId = null;
      _activeRoomCode = null;
      _teamPositions = [];
      _members = [];
      _isAdmin = false;
      _profileCache.clear();
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// A SnackBar auto-dismisses in a few seconds and can be easy to
  /// miss — used here instead of [_showError] for failures that must
  /// never go unnoticed (e.g. failing to register as a room member),
  /// so a real problem can never again look identical to "it worked,
  /// but the room is just empty".
  void _showCriticalError(String title, String details) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(details)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_tr('ok')),
          ),
        ],
      ),
    );
  }

  void _zoomIn() {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom + 1);
  }

  void _zoomOut() {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom - 1);
  }

  void _toggleMapStyle() {
    setState(() => _isSatelliteView = !_isSatelliteView);
  }

  void _centerOnMyLocation() {
    _mapController.move(_myPosition, 15);
  }

  /// Bound to the current language; safe to call from anywhere in this
  /// State (build methods, dialogs, callbacks) — not just build().
  String _tr(String key) => AppStrings.translate(key, ref.read(localeProvider));

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider); // subscribe so a language change rebuilds this
    if (_activeSessionId == null) {
      return _buildDashboard();
    }
    return _buildLiveTrackingMap();
  }

  // ---------------------------------------------------------------------
  // DASHBOARD (no active room)
  // ---------------------------------------------------------------------

  Widget _buildDashboard() {
    return Scaffold(
      appBar: AppBar(title: Text(_tr('nav_group_hunt'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.groups_2_outlined,
                  size: 96, color: Colors.green),
              const SizedBox(height: 16),
              Text(
                _tr('group_hunt_subtitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _tr('max_hunters_per_room')
                      .replaceAll('{n}', '${SupabaseService.maxRoomCapacity}'),
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ),
              const SizedBox(height: 32),
              if (_busy)
                const CircularProgressIndicator()
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _createRoom,
                    icon: const Icon(Icons.group_add),
                    label: Text(_tr('create_room')),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _joinRoomDialog,
                    icon: const Icon(Icons.login),
                    label: Text(_tr('join_room')),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // LIVE TRACKING MAP (active room)
  // ---------------------------------------------------------------------

  Widget _buildLiveTrackingMap() {
    final myId = SupabaseService.instance.currentUserId;
    // Exclude our own row from "other hunters" — we already render our
    // own position with the blue locate-me-style marker below, so this
    // avoids a duplicate marker for ourselves.
    final otherHunters = _teamPositions.where((p) => p.userId != myId).toList();

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: RoomMembersDrawer(
        sessionId: _activeSessionId!,
        members: _members,
        isCurrentUserAdmin: _isAdmin,
        errorMessage: _membersError,
        onRetry: () =>
            SupabaseService.instance.refreshRoomMembersNow(_activeSessionId!),
      ),
      appBar: AppBar(
        title: Text('${_tr('hunt_room_title')} · $_activeRoomCode'),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.groups_outlined),
                tooltip: _tr('room_members_tooltip'),
                onPressed: () {
                  // Force a fresh fetch every time the drawer is
                  // opened. The subscribeToRoom priming fetch already
                  // covers the normal case, but if the user opens the
                  // drawer immediately after joining — before that
                  // async fetch resolves — it would otherwise sit on
                  // an empty list until the next realtime event fires.
                  if (_activeSessionId != null) {
                    SupabaseService.instance
                        .refreshRoomMembersNow(_activeSessionId!);
                  }
                  _scaffoldKey.currentState?.openEndDrawer();
                },
              ),
              if (_members.isNotEmpty)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_members.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: _tr('share_room_code_tooltip'),
            onPressed: () =>
                _showError('${_tr('room_code_label')}: $_activeRoomCode'),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _myPosition,
              initialZoom: 14,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onPositionChanged: (camera, hasGesture) {
                setState(() => _mapCenter = camera.center);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    _isSatelliteView ? _satelliteTileUrl : _standardTileUrl,
                userAgentPackageName: 'com.morohunt.app',
                tileProvider: OfflineTileService.tileProvider,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _myPosition,
                    width: 76,
                    height: 74,
                    alignment: Alignment.topCenter,
                    // Same avatar+label marker as every other hunter —
                    // shows correctly even solo in the room, since it
                    // only depends on _myProfile / _myPosition, not on
                    // any other participant being present.
                    child: _HunterAvatarMarker(profile: _myProfile),
                  ),
                  ...otherHunters.map((hunter) {
                    final profile = _profileCache[hunter.userId];
                    return Marker(
                      point: LatLng(hunter.lat, hunter.lng),
                      width: 76,
                      height: 74,
                      alignment: Alignment.topCenter,
                      child: _HunterAvatarMarker(profile: profile),
                    );
                  }),
                ],
              ),
            ],
          ),

          // Same style-switcher control as Tab 1, so both maps behave
          // consistently.
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              bottom: false,
              child: LayerControlButton(
                icon:
                    _isSatelliteView ? Icons.map_outlined : Icons.satellite_alt,
                tooltip: _isSatelliteView
                    ? _tr('normal_map')
                    : _tr('toggle_satellite'),
                active: _isSatelliteView,
                onTap: _toggleMapStyle,
              ),
            ),
          ),

          // Same +/- zoom + locate-me controls as Tab 1.
          Positioned(
            bottom: 24,
            right: 16,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  ZoomButton(icon: Icons.add, onTap: _zoomIn),
                  const SizedBox(height: 8),
                  ZoomButton(icon: Icons.remove, onTap: _zoomOut),
                  const SizedBox(height: 8),
                  ZoomButton(
                      icon: Icons.my_location, onTap: _centerOnMyLocation),
                ],
              ),
            ),
          ),

          // Same live coordinates ribbon as Tab 1.
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1F1A).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'LAT: ${_mapCenter.latitude.toStringAsFixed(5)}   '
                    'LNG: ${_mapCenter.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'leave',
            onPressed: _leaveRoom,
            icon: const Icon(Icons.logout),
            label: Text(_tr('leave_room')),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'end',
            backgroundColor: Colors.red,
            onPressed: _endSession,
            icon: const Icon(Icons.stop_circle_outlined),
            label: Text(_tr('end_session')),
          ),
        ],
      ),
    );
  }
}

/// A live team member's marker: their actual circular profile picture
/// (falling back to their first initial while it loads or if they have
/// none set) with their display name in a small legible label directly
/// underneath — replacing generic pin icons entirely.
class _HunterAvatarMarker extends StatelessWidget {
  final HunterProfile? profile;

  const _HunterAvatarMarker({required this.profile});

  @override
  Widget build(BuildContext context) {
    final username = profile?.username;
    final avatarUrl = profile?.avatarUrl;
    final initial = (username != null && username.isNotEmpty)
        ? username[0].toUpperCase()
        : '?';

    return SizedBox(
      width: 76,
      height: 74,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black45, blurRadius: 5, offset: Offset(0, 2)),
              ],
            ),
            child: ClipOval(
              child: avatarUrl != null
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) =>
                          _initialAvatar(initial),
                    )
                  : _initialAvatar(initial),
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 72),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                username ?? '...',
                style: const TextStyle(color: Colors.white, fontSize: 10),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initialAvatar(String initial) {
    return Container(
      color: const Color(0xFF2E7D32),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}
