import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';
import '../models/hunt_catch.dart';
import '../models/hunter_profile.dart';
import '../models/hunting_dog.dart';
import '../models/map_zone.dart';
import '../models/room_member.dart';

/// Central service wrapping every Supabase interaction MoroHunt needs:
/// - Realtime room creation / join / live-location broadcast
/// - Catch photo upload + geotagged record insert
/// - Automatic dog score sync
/// - Profile / leaderboard reads
class SupabaseService {
  SupabaseService._internal();
  static final SupabaseService instance = SupabaseService._internal();

  /// Maximum hunters allowed in a single active group-hunt room.
  static const int maxRoomCapacity = 10;

  /// Background poll interval for team positions — a redundancy layer
  /// on top of the Realtime websocket subscription, so positions keep
  /// updating even if a websocket event is ever missed.
  static const Duration _positionsPollInterval = Duration(seconds: 7);

  SupabaseClient get _client => Supabase.instance.client;

  RealtimeChannel? _roomChannel;
  Timer? _locationPushTimer;
  Timer? _positionsPollTimer;
  final _positionsController =
      StreamController<List<LiveHunterPosition>>.broadcast();
  final _catchesChangedController = StreamController<void>.broadcast();
  final _membersController = StreamController<List<RoomMember>>.broadcast();
  final _kickedController = StreamController<void>.broadcast();

  // Set right before this device intentionally removes its own
  // participant row (voluntary leave / ending the session), so the
  // realtime DELETE event that follows isn't mistaken for being kicked
  // by the admin.
  bool _selfInitiatedRemoval = false;
  String? _currentSessionCreatorId;

  /// Stream the UI subscribes to for live pins of every hunter in the room.
  Stream<List<LiveHunterPosition>> get positionsStream =>
      _positionsController.stream;

  /// Fires whenever a catch is added or deleted, so any screen showing
  /// catch markers (like the map) can refresh without a manual reload.
  Stream<void> get catchesChangedStream => _catchesChangedController.stream;

  /// Live member list for the currently-subscribed room (join/leave/kick
  /// all reflected instantly for everyone, via Realtime).
  Stream<List<RoomMember>> get membersStream => _membersController.stream;

  /// Fires exactly once if THIS device's own participant row is
  /// removed by someone else (i.e. the admin kicked them) — never
  /// fires for a voluntary leave initiated locally.
  Stream<void> get kickedStream => _kickedController.stream;

  // ---------------------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------------------

  /// Initializes the Supabase client.
  ///
  /// ### About `ClientException: Failed to fetch` on Flutter Web
  /// This error means the browser's `fetch()` call never got a
  /// response at all — it is thrown by `package:http`'s browser
  /// backend before any Supabase/Dart code sees a status code. There
  /// is no header, option, or client config on `Supabase.initialize()`
  /// (or anywhere in this app) that can make the browser accept a
  /// request it has already decided to block — CORS is enforced by
  /// the browser itself against whatever the *server* (Supabase's own
  /// edge infrastructure) sends back, and Supabase's REST/Auth API
  /// already returns `Access-Control-Allow-Origin: *` for every
  /// origin by default. It is NOT something you allow-list per
  /// origin in the dashboard (that's a common misconception — the
  /// "Redirect URLs" list below is a different, unrelated setting).
  ///
  /// In practice this almost always means the request never reached a
  /// real Supabase server to begin with. Check, in order:
  /// 1. **Project is paused.** Free-tier Supabase projects auto-pause
  ///    after a week of inactivity — this is the single most common
  ///    cause of this exact error. Open the Supabase dashboard; if
  ///    you see a "Restore project" banner, that's it.
  /// 2. **URL/anon key typo,** or pointing at a deleted/old project.
  ///    Re-copy both from Project Settings → API.
  /// 3. **A browser extension** (ad blocker, privacy/VPN extension)
  ///    blocking the request — test in an Incognito window with
  ///    extensions off.
  /// 4. **Auth → URL Configuration → Site URL / Additional Redirect
  ///    URLs** doesn't need `localhost` for the signup/login POST
  ///    itself to work, but DOES need it for email-confirmation links
  ///    and OAuth to redirect back correctly. Add e.g.
  ///    `http://localhost:*` (or your exact `flutter run -d chrome`
  ///    port, since Supabase's matcher supports a `*` wildcard) under
  ///    Authentication → URL Configuration → Additional Redirect URLs
  ///    in the dashboard.
  static Future<void> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      // Verbose request/response logging from the SDK in debug builds
      // only — makes the real failure (DNS error, 404 on a wrong URL,
      // an actual non-2xx response, etc.) visible in the browser
      // console instead of only ever seeing "Failed to fetch".
      debug: kDebugMode,
    );
  }

  String get _uid => _client.auth.currentUser!.id;

  /// Safe nullable accessor for the current user id — useful for UI
  /// code that needs to check "is this my own profile?" without
  /// crashing if somehow called while signed out.
  String? get currentUserId => _client.auth.currentUser?.id;

  // ---------------------------------------------------------------------
  // ROOMS / SESSIONS
  // ---------------------------------------------------------------------

  /// Creates a new hunt session ("room") and returns its human-friendly
  /// room code (e.g. HUNTER-998).
  Future<HuntSession> createRoom() async {
    // Room codes are only 3 random digits (HUNTER-XXX), so collisions
    // are plausible at any real usage volume. Retry with a fresh code
    // on a unique-constraint violation instead of surfacing that as a
    // user-facing error.
    const maxAttempts = 5;
    Map<String, dynamic>? row;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final code = _generateRoomCode();
      try {
        row = await _client
            .from('hunt_sessions')
            .insert({
              'creator_id': _uid,
              'room_code': code,
            })
            .select()
            .single();
        break; // success
      } on PostgrestException catch (e) {
        final isUniqueViolation =
            e.code == '23505' || e.message.contains('room_code');
        if (isUniqueViolation && attempt < maxAttempts) {
          continue; // collided — try again with a new code
        }
        rethrow;
      }
    }

    if (row == null) {
      throw Exception(
          'تعذر إنشاء رمز غرفة فريد بعد عدة محاولات. حاول مرة أخرى.');
    }

    final session = HuntSession.fromMap(row);
    await _joinSessionParticipants(session.id);
    _currentSessionCreatorId = session.creatorId;
    // Pre-existing gap: the room creator never actually subscribed to
    // realtime updates at all (only joinRoom did this) — meaning the
    // creator would never see other hunters' positions or member
    // changes. Fixed here so both create and join paths behave
    // identically.
    await subscribeToRoom(session.id);
    return session;
  }

  /// Joins an existing room by its code and starts realtime subscriptions.
  /// Enforces [maxRoomCapacity] — throws if the room is already full.
  Future<HuntSession> joinRoom(String roomCode) async {
    final row = await _client
        .from('hunt_sessions')
        .select()
        .eq('room_code', roomCode)
        .eq('is_active', true)
        .single();

    final session = HuntSession.fromMap(row);

    final participantRows = await _client
        .from('session_participants')
        .select('user_id')
        .eq('session_id', session.id);

    final alreadyJoined = participantRows.any((r) => r['user_id'] == _uid);
    if (!alreadyJoined && participantRows.length >= maxRoomCapacity) {
      throw Exception('الغرفة ممتلئة (الحد الأقصى $maxRoomCapacity قناصين)');
    }

    await _joinSessionParticipants(session.id);
    _currentSessionCreatorId = session.creatorId;
    await subscribeToRoom(session.id);
    return session;
  }

  /// Registers the current user as a participant in [sessionId]. This
  /// is the exact insert the room members drawer depends on — made
  /// deliberately bulletproof against two known failure modes:
  ///
  /// 1. `.upsert()` without an explicit `onConflict` relies on
  ///    PostgREST inferring the conflict target from the table's
  ///    primary key via its schema cache. PostgREST's own docs warn
  ///    this can misbehave if that cache is stale (e.g. right after a
  ///    migration, before a schema reload) — so the composite primary
  ///    key columns are named explicitly here instead of relying on
  ///    that inference at all.
  /// 2. The previous version's caller never checked whether this
  ///    actually inserted a row — any failure here would have been
  ///    completely invisible. It now reads the row back and throws
  ///    loudly if it's missing, so a real failure can never again look
  ///    identical to "working, but the room is just empty".
  Future<void> _joinSessionParticipants(String sessionId) async {
    final rows = await _client.from('session_participants').upsert(
      {
        'session_id': sessionId,
        'user_id': _uid,
      },
      onConflict: 'session_id,user_id',
    ).select();

    if (rows.isEmpty) {
      throw Exception(
        'تعذر تسجيلك كعضو في الغرفة (session_participants). '
        'حاول مرة أخرى أو تحقق من صلاحيات RLS للجدول.',
      );
    }
  }

  /// Subscribes to `live_locations` changes for [sessionId] over
  /// Supabase Realtime (WebSockets) and republishes a friendly stream
  /// of [LiveHunterPosition] for the map screen to render as pins.
  /// Also starts a background poll every [_positionsPollInterval] as a
  /// redundancy layer, so positions keep refreshing smoothly even if a
  /// websocket event is ever dropped — no manual refresh needed.
  Future<void> subscribeToRoom(String sessionId) async {
    await _roomChannel?.unsubscribe();
    _positionsPollTimer?.cancel();
    _selfInitiatedRemoval = false;

    _roomChannel = _client
        .channel('room:$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'live_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
          callback: (payload) => _refreshRoomPositions(sessionId),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'session_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
          callback: (payload) {
            // Detect being kicked: our own row disappeared and WE
            // didn't just remove it ourselves.
            if (payload.eventType == PostgresChangeEvent.delete) {
              final removedUserId = payload.oldRecord['user_id'] as String?;
              if (removedUserId == currentUserId && !_selfInitiatedRemoval) {
                _kickedController.add(null);
              }
            }
            _refreshRoomMembers(sessionId);
          },
        )
        .subscribe();

    _positionsPollTimer = Timer.periodic(
      _positionsPollInterval,
      (_) => _refreshRoomPositions(sessionId),
    );

    // Prime both streams immediately with current state.
    await _refreshRoomPositions(sessionId);
    await _refreshRoomMembers(sessionId);
  }

  /// Manually retries loading the member list — exposed for the "retry"
  /// action shown when [membersStream] emits an error.
  Future<void> refreshRoomMembersNow(String sessionId) =>
      _refreshRoomMembers(sessionId);

  Future<void> _refreshRoomMembers(String sessionId) async {
    try {
      final members = await fetchRoomMembers(sessionId);
      if (!_membersController.isClosed) {
        _membersController.add(members);
      }
    } catch (e) {
      // Surface the error on the stream instead of silently leaving
      // the UI stuck on an empty list forever with no visible failure
      // (that silent-swallow was exactly what hid the previous bug).
      if (!_membersController.isClosed) {
        _membersController.addError(e);
      }
    }
  }

  /// Joined `session_participants` + `profiles` for [sessionId]. Looks
  /// up the session's creator_id itself so callers don't need to pass
  /// it separately (and so [RoomMember.isAdmin] is always correctly
  /// computed even if the caller only has a session id on hand).
  Future<List<RoomMember>> fetchRoomMembers(String sessionId) async {
    debugPrint(
        '[fetchRoomMembers] querying session_participants for session_id="$sessionId"');

    var creatorId = _currentSessionCreatorId;
    if (creatorId == null) {
      final session = await _client
          .from('hunt_sessions')
          .select('creator_id')
          .eq('id', sessionId)
          .single();
      creatorId = session['creator_id'] as String;
      _currentSessionCreatorId = creatorId;
    }
    debugPrint('[fetchRoomMembers] creatorId="$creatorId"');

    // Deliberately two flat queries + a client-side join instead of a
    // PostgREST relational embed (`profiles(username, avatar_url)`).
    // The embed form is one more thing that can silently fail to
    // resolve (stale schema cache, ambiguous relationship, etc.), and
    // when it did, the old code's blanket try/catch swallowed the
    // error completely — the member list just sat empty forever with
    // no visible failure. Flat queries can't suffer that failure mode.
    final participantRows = await _client
        .from('session_participants')
        .select('user_id, joined_at')
        .eq('session_id', sessionId)
        .order('joined_at', ascending: true);

    debugPrint('[fetchRoomMembers] RAW session_participants rows for this '
        'session_id (${participantRows.length}): $participantRows');

    if (participantRows.isEmpty) return [];

    final userIds = participantRows.map((r) => r['user_id'] as String).toList();
    final profileRows = await _client
        .from('profiles')
        .select('id, username, avatar_url')
        .inFilter('id', userIds);

    debugPrint('[fetchRoomMembers] userIds requested: $userIds');
    debugPrint('[fetchRoomMembers] RAW profiles rows returned '
        '(${profileRows.length}): $profileRows');

    final profilesById = {
      for (final p in profileRows) p['id'] as String: p,
    };

    final members = participantRows.map((r) {
      final userId = r['user_id'] as String;
      final profile = profilesById[userId];
      return RoomMember(
        userId: userId,
        username: profile?['username'] as String? ?? '...',
        avatarUrl: profile?['avatar_url'] as String?,
        joinedAt: DateTime.parse(r['joined_at'] as String),
        isAdmin: userId == creatorId,
      );
    }).toList();

    debugPrint('[fetchRoomMembers] final RoomMember count: ${members.length}');

    // Admin always first, regardless of join order.
    members.sort((a, b) {
      if (a.isAdmin == b.isAdmin) return 0;
      return a.isAdmin ? -1 : 1;
    });
    return members;
  }

  /// Removes [userId] from [sessionId]. RLS only allows this if the
  /// caller is the session's creator (admin) — enforced server-side by
  /// the `participants_delete_by_admin` policy, not just in this UI.
  /// Removes [userId] from [sessionId]. RLS only allows this if the
  /// caller is the session's creator (admin) — enforced server-side by
  /// the `participants_delete_by_admin` policy, not just in this UI.
  ///
  /// Critically, this verifies the row was ACTUALLY deleted. A plain
  /// `.delete()` against a row RLS silently blocks still returns a
  /// normal success response with zero rows affected — it does NOT
  /// throw. Without this check, the UI would show a false "kicked
  /// successfully" message while the row quietly survives, which is
  /// exactly the bug reported: the SnackBar said success but the
  /// member never actually left.
  Future<void> kickMember({
    required String sessionId,
    required String userId,
  }) async {
    final deletedRows = await _client
        .from('session_participants')
        .delete()
        .eq('session_id', sessionId)
        .eq('user_id', userId)
        .select();

    if (deletedRows.isEmpty) {
      throw Exception(
        'لم يتم طرد العضو فعليًا. تأكد من تفعيل صلاحية '
        '"participants_delete_by_admin" على جدول session_participants في Supabase، '
        'ومن أنك بالفعل منشئ هذه الغرفة.',
      );
    }
  }

  Future<void> _refreshRoomPositions(String sessionId) async {
    final rows = await _client
        .from('live_locations')
        .select('user_id, speed_kmh, updated_at, geom_hex:geom::text')
        .eq('session_id', sessionId);

    final positions = <LiveHunterPosition>[];
    for (final row in rows) {
      try {
        positions.add(LiveHunterPosition.fromMap(row));
      } catch (_) {
        // Skip malformed rows rather than crash the whole stream.
      }
    }
    if (!_positionsController.isClosed) {
      _positionsController.add(positions);
    }
  }

  /// Starts pushing this device's GPS position to `live_locations` every
  /// 10 seconds, per the "Live Tracking Payload" spec. Call
  /// [stopBroadcastingLocation] when leaving the room / ending the hunt.
  void startBroadcastingLocation({
    required String sessionId,
    required Future<({double lat, double lng, double speedKmh})> Function()
        getCurrentPosition,
  }) {
    _locationPushTimer?.cancel();
    _locationPushTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final pos = await getCurrentPosition();
        await _client.from('live_locations').upsert({
          'session_id': sessionId,
          'user_id': _uid,
          'geom':
              'SRID=4326;POINT(${pos.lng.toStringAsFixed(6)} ${pos.lat.toStringAsFixed(6)})',
          'speed_kmh': pos.speedKmh,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'session_id,user_id');
      } catch (_) {
        // Fallback silently if location reading times out during network gap.
      }
    });
  }

  void stopBroadcastingLocation() {
    _locationPushTimer?.cancel();
    _locationPushTimer = null;
  }

  /// Leaves [sessionId] for real — previously this only unsubscribed
  /// locally and never actually removed the participant row, meaning
  /// every session's member list grew forever. Now it deletes the row
  /// (RLS allows a user to always remove their own), marking this as
  /// self-initiated first so the realtime listener doesn't mistake it
  /// for an admin kick.
  Future<void> leaveRoom(String sessionId) async {
    _selfInitiatedRemoval = true;
    try {
      await _client
          .from('session_participants')
          .delete()
          .eq('session_id', sessionId)
          .eq('user_id', _uid);
    } catch (_) {
      // Non-fatal — still tear down local subscriptions/timers below
      // even if the delete failed (e.g. already removed).
    }

    stopBroadcastingLocation();
    _positionsPollTimer?.cancel();
    _positionsPollTimer = null;
    _currentSessionCreatorId = null;
    if (_roomChannel != null) {
      await _roomChannel!.unsubscribe();
      _roomChannel = null;
    }
  }

  /// Ends the hunt session and triggers the final dog score sync for
  /// every dog that participated (see [syncDogScore]).
  Future<void> endSession(String sessionId) async {
    await _client.from('hunt_sessions').update({
      'is_active': false,
      'ended_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', sessionId);
    await leaveRoom(sessionId);
  }

  String _generateRoomCode() {
    final rand = Random();
    final number = 100 + rand.nextInt(900); // 3-digit suffix
    return 'HUNTER-$number';
  }

  // ---------------------------------------------------------------------
  // DOG SCORE
  // ---------------------------------------------------------------------

  /// Pushes updated distance/speed for a dog. The `dog_points` field is
  /// then recalculated server-side by the `dogs_before_update` trigger
  /// using: (TotalDistanceKM * 10) + (AvgSpeedKMH * 5).
  Future<HuntingDog> syncDogScore({
    required String dogId,
    required double totalDistanceKm,
    required double avgSpeedKmh,
  }) async {
    final row = await _client
        .from('dogs')
        .update({
          'total_distance_km': totalDistanceKm,
          'avg_speed_kmh': avgSpeedKmh,
        })
        .eq('id', dogId)
        .select()
        .single();

    return HuntingDog.fromMap(row);
  }

  Future<HuntingDog?> fetchDogOfTheMonth() async {
    final rows = await _client.from('dog_of_the_month').select().limit(1);
    if (rows.isEmpty) return null;
    return HuntingDog.fromMap(rows.first);
  }

  Future<List<HuntingDog>> fetchDogsForOwner(String ownerId) async {
    final rows = await _client.from('dogs').select().eq('owner_id', ownerId);
    return rows.map((r) => HuntingDog.fromMap(r)).toList();
  }

  // ---------------------------------------------------------------------
  // CATCHES (community catch map + gamification)
  // ---------------------------------------------------------------------

  /// Uploads a catch photo to the `catches_photos` bucket and inserts the
  /// geotagged record. Awards +50 rank points for a legally logged catch
  /// inside a permitted zone (validated client-side before calling this,
  /// and re-validated by policy/trigger server-side in a full deployment).
  ///
  /// Takes raw [imageBytes] (not a dart:io File) so this works
  /// identically on web, mobile, and desktop — read bytes from an
  /// XFile via `await pickedFile.readAsBytes()` before calling this.
  Future<HuntCatch> logCatch({
    required Uint8List imageBytes,
    required PreyType preyType,
    required double lat,
    required double lng,
    String? sessionId,
  }) async {
    final fileName = '${_uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storagePath = 'public/$fileName';

    await _client.storage.from('catches_photos').uploadBinary(
          storagePath,
          imageBytes,
          fileOptions:
              const FileOptions(upsert: false, contentType: 'image/jpeg'),
        );

    final imageUrl =
        _client.storage.from('catches_photos').getPublicUrl(storagePath);

    final row = await _client
        .from('catches')
        .insert({
          'user_id': _uid,
          'session_id': sessionId,
          'prey_type': preyType.dbValue,
          'image_url': imageUrl,
          'geom':
              'SRID=4326;POINT(${lng.toStringAsFixed(6)} ${lat.toStringAsFixed(6)})',
        })
        .select('*, geom_hex:geom::text')
        .single();

    if (!_catchesChangedController.isClosed) {
      _catchesChangedController.add(null);
    }

    return HuntCatch.fromMap(row);
  }

  /// Top dogs across ALL owners, ordered by dog_points — used by the
  /// "ترتيب الكلاب" (dog leaderboard) tab.
  Future<List<HuntingDog>> fetchTopDogs({int limit = 50}) async {
    final rows = await _client
        .from('dogs')
        .select()
        .order('dog_points', ascending: false)
        .limit(limit);
    return rows.map((r) => HuntingDog.fromMap(r)).toList();
  }

  /// Catches logged by a single user — powers the personal gallery grid
  /// on the profile tab.
  Future<List<HuntCatch>> fetchUserCatches(String userId,
      {int limit = 100}) async {
    final rows = await _client
        .from('catches')
        .select('*, geom_hex:geom::text')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map((r) => HuntCatch.fromMap(r)).toList();
  }

  /// Updates the editable parts of a profile (username / avatar).
  Future<HunterProfile> updateProfile({
    String? username,
    String? avatarUrl,
    String? gender,
    String? city,
    DateTime? birthdate,
  }) async {
    final updates = <String, dynamic>{};
    if (username != null) updates['username'] = username;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (gender != null) updates['gender'] = gender;
    if (city != null) updates['city'] = city;
    if (birthdate != null) {
      updates['birthdate'] = '${birthdate.year.toString().padLeft(4, '0')}-'
          '${birthdate.month.toString().padLeft(2, '0')}-'
          '${birthdate.day.toString().padLeft(2, '0')}';
    }

    final row = await _client
        .from('profiles')
        .update(updates)
        .eq('id', _uid)
        .select()
        .single();
    return HunterProfile.fromMap(row);
  }

  /// Uploads a new avatar image and returns its public URL. Reuses the
  /// same `catches_photos` bucket under an `avatars/` prefix to avoid
  /// requiring a second bucket + policy set. Takes raw bytes so this
  /// works on web too (no dart:io File access there).
  Future<String> uploadAvatar(Uint8List imageBytes) async {
    final path = 'avatars/${_uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from('catches_photos').uploadBinary(
          path,
          imageBytes,
          fileOptions:
              const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
    return _client.storage.from('catches_photos').getPublicUrl(path);
  }

  Future<List<HuntCatch>> fetchCommunityCatches({int limit = 200}) async {
    final rows = await _client
        .from('catches')
        .select('*, geom_hex:geom::text')
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map((r) => HuntCatch.fromMap(r)).toList();
  }

  // ---------------------------------------------------------------------
  // HUNTING ZONES LAYER (Réserve / Amodié / Zones Ouvertes) + POIs
  // ---------------------------------------------------------------------

  /// Fetches every hunting-zone polygon (all 3 categories) from the
  /// `map_zones_geojson` view — which pre-converts PostGIS `geom` with
  /// `st_asgeojson()`, so no EWKB polygon parsing is needed client-side.
  ///
  /// The screen/provider is responsible for filtering by category based
  /// on which layer-panel switches are enabled; we fetch everything
  /// once and filter client-side so toggling a switch never re-hits
  /// the network.
  Future<List<MapZone>> fetchHuntingZones() async {
    final rows = await _client
        .from('map_zones_geojson')
        .select('id, zone_name, category, geometry');
    return rows.map<MapZone>((r) => MapZone.fromSupabaseRow(r)).toList();
  }

  /// Same data as [fetchHuntingZones] but wrapped as a GeoJSON
  /// FeatureCollection, for [ZoneCheckService.cacheZonesFromGeoJson]
  /// (offline caching for in-field forbidden-zone GPS checks).
  Future<Map<String, dynamic>> fetchHuntingZonesAsFeatureCollection() async {
    final zones = await fetchHuntingZones();
    return {
      'type': 'FeatureCollection',
      'features': zones.map((z) => z.toGeoJsonFeature()).toList(),
    };
  }

  /// Awards rank points for validated activities, e.g.:
  /// - +50 for a legal session registered in a permitted zone
  /// - +100 for a community-voted environmental cleanup photo
  Future<void> awardRankPoints({
    required String userId,
    required int points,
  }) async {
    await _client.rpc('award_rank_points', params: {
      'p_user_id': userId,
      'p_points': points,
    });
  }

  // ---------------------------------------------------------------------
  // PROFILE / LEADERBOARD
  // ---------------------------------------------------------------------

  Future<HunterProfile> fetchProfile(String userId) async {
    final row =
        await _client.from('profiles').select().eq('id', userId).single();
    return HunterProfile.fromMap(row);
  }

  Future<List<HunterProfile>> fetchLeaderboard({int limit = 50}) async {
    final rows = await _client
        .from('profiles')
        .select()
        .order('rank_points', ascending: false)
        .limit(limit);
    return rows.map((r) => HunterProfile.fromMap(r)).toList();
  }

  /// Deletes an entire catch "trip log" at once — all photos, their
  /// storage files, and the map marker for that pin.
  Future<void> deleteCatchGroup(List<HuntCatch> group) async {
    if (group.isEmpty) return;
    final ids = group.map((c) => c.id).toList();

    final deletedRows = await _client
        .from('catches')
        .delete()
        .inFilter('id', ids)
        .eq('user_id', _uid)
        .select('id');

    if ((deletedRows as List).isEmpty) {
      throw Exception(
        'لم يتم حذف أي سجل من قاعدة البيانات. تأكد من تفعيل صلاحية الحذف '
        '(RLS policy "catches_delete_own") على جدول catches في Supabase.',
      );
    }

    // Best-effort storage cleanup
    final paths = group
        .map(
            (c) => c.imageUrl != null ? _extractStoragePath(c.imageUrl!) : null)
        .whereType<String>()
        .toList();

    if (paths.isNotEmpty) {
      try {
        await _client.storage.from('catches_photos').remove(paths);
      } catch (_) {
        // Ignore storage cleanup failure if DB row was successfully removed
      }
    }

    if (!_catchesChangedController.isClosed) {
      _catchesChangedController.add(null);
    }
  }

  // ---------------------------------------------------------------------
  // QUICK CATCH LOGGING (no photo, weight-aware scoring, badge check)
  // ---------------------------------------------------------------------

  Future<QuickCatchResult> logQuickCatch({
    required PreyType preyType,
    required int count,
    String? weightTier,
    double? lat,
    double? lng,
  }) async {
    final response = await _client.rpc('log_quick_catch', params: {
      'p_prey_type': preyType.dbValue,
      'p_count': count,
      'p_weight_tier': weightTier,
      'p_lat': lat,
      'p_lng': lng,
    });

    final Map<String, dynamic> row;
    if (response is List && response.isNotEmpty) {
      row = response.first as Map<String, dynamic>;
    } else if (response is Map<String, dynamic>) {
      row = response;
    } else {
      throw Exception('استجابة غير متوقعة من الخادم عند تسجيل الصيد');
    }

    final result = QuickCatchResult.fromMap(row);

    if (!_catchesChangedController.isClosed) {
      _catchesChangedController.add(null);
    }
    return result;
  }

  Future<List<AppNotification>> fetchNotifications({int limit = 100}) async {
    final rows = await _client
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map((r) => AppNotification.fromMap(r)).toList();
  }

  // ---------------------------------------------------------------------
  // PEER REPORTING (إبلاغ عن مستخدم)
  // ---------------------------------------------------------------------

  Future<void> submitUserReport({
    required String reportedUserId,
    required List<String> tags,
    String? details,
  }) async {
    await _client.from('user_reports').insert({
      'reporter_id': _uid,
      'reported_user_id': reportedUserId,
      'tags': tags,
      if (details != null && details.trim().isNotEmpty)
        'details': details.trim(),
    });
  }

  // ---------------------------------------------------------------------
  // SECURE ACCOUNT DELETION
  // ---------------------------------------------------------------------

  Future<void> deleteAccountWithReauth({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);

    final response = await _client.functions.invoke('delete-account');
    if (response.status != 200) {
      throw Exception('فشل حذف الحساب: ${response.data}');
    }

    await _client.auth.signOut();
  }

  /// Extracts storage object path from a Supabase public URL.
  String? _extractStoragePath(String publicUrl) {
    const marker = '/storage/v1/object/public/catches_photos/';
    final idx = publicUrl.indexOf(marker);
    if (idx == -1) return null;
    return publicUrl.substring(idx + marker.length);
  }

  void dispose() {
    _locationPushTimer?.cancel();
    _positionsPollTimer?.cancel();
    _roomChannel?.unsubscribe();
    _positionsController.close();
    _catchesChangedController.close();
    _membersController.close();
    _kickedController.close();
  }
}
