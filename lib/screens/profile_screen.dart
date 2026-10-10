import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/competitive_rank.dart';
import '../models/hunt_catch.dart';
import '../models/hunter_profile.dart';
import '../l10n/app_strings.dart';
import '../providers/locale_provider.dart';
import '../services/supabase_service.dart';
import '../utils/achievement_badges.dart';
import '../utils/catch_grouping.dart';
import '../widgets/achievement_medal_icon.dart';
import '../widgets/birthdate_dropdowns.dart';
import '../widgets/city_picker_sheet.dart';
import '../widgets/competitive_rank_badge.dart';
import '../widgets/flag_icons.dart';
import '../widgets/language_selection_sheet.dart';
import '../widgets/photo_swipe_viewer.dart';
import '../widgets/prey_counter.dart';
import 'delete_account_screen.dart';
import 'legal_compliance_screen.dart';
import 'notification_center_screen.dart';
import 'support_chat_screen.dart';

/// Tab 4 — "الملف الشخصي": editable avatar + display name, gender/age/
/// city, the user's current competitive rank badge, the 5-species prey
/// counter grid, and — only when viewing your OWN profile — a private
/// gallery of every "trip log" you've pinned on the map, each deletable
/// as a whole (all up-to-5 photos + the map marker at once).
///
/// Legacy-account fallback: if gender/city/birthdate are NULL in the
/// database (accounts created before these fields existed, or where
/// sign-up skipped them), the OWNER sees friendly mock defaults
/// (male / الدار البيضاء / 25 سنة) instead of a blank/broken layout,
/// clearly editable via the pencil affordance. Someone viewing another
/// user's PUBLIC profile never sees fabricated data for fields that
/// are genuinely empty — those rows are simply omitted there instead,
/// so nothing false is shown about someone else.
class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _uploadingAvatar = false;

  bool _loading = true;
  String? _errorMessage;
  HunterProfile? _profile;
  CompetitiveRank _rank = CompetitiveRank.steel;
  List<List<HuntCatch>> _catchGroups = [];

  bool get _isOwnProfile =>
      SupabaseService.instance.currentUserId == widget.userId;

  // ---- Legacy-account mock fallbacks (owner view only) ----------------
  static const _mockGender = 'male';
  static const _mockCity = 'الدار البيضاء';
  static const _mockAge = 25;

  bool get _isGenderMissing => _profile?.gender == null;

  /// Bound to the current language; safe to call from anywhere in this
  /// State (dialogs, callbacks) — not just build().
  String _tr(String key) => AppStrings.translate(key, ref.read(localeProvider));
  bool get _isCityMissing => _profile?.city == null || _profile!.city!.isEmpty;
  bool get _isAgeMissing => _profile?.age == null;

  String? get _displayGender {
    if (_profile?.gender != null) return _profile!.gender;
    return _isOwnProfile ? _mockGender : null;
  }

  String? get _displayCity {
    if (_profile?.city != null && _profile!.city!.isNotEmpty)
      return _profile!.city;
    return _isOwnProfile ? _mockCity : null;
  }

  int? get _displayAge {
    if (_profile?.age != null) return _profile!.age;
    return _isOwnProfile ? _mockAge : null;
  }

  bool get _hasAnyMockValue =>
      _isOwnProfile && (_isGenderMissing || _isCityMissing || _isAgeMissing);

  StreamSubscription<void>? _catchesChangedSubscription;

  @override
  void initState() {
    super.initState();
    _loadProfileData();

    // Refresh species counts / rank points / badges automatically when
    // a catch is logged or deleted anywhere in the app (e.g. the quick
    // catch FAB), without needing a manual pull-to-refresh.
    if (_isOwnProfile) {
      _catchesChangedSubscription =
          SupabaseService.instance.catchesChangedStream.listen((_) {
        _loadProfileData();
      });
    }
  }

  @override
  void dispose() {
    _catchesChangedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final service = SupabaseService.instance;
      final profile = await service.fetchProfile(widget.userId);
      final leaderboard = await service.fetchLeaderboard();

      final position = leaderboard.indexWhere((p) => p.id == widget.userId);
      final rank =
          CompetitiveRank.fromPosition(position == -1 ? 999 : position + 1);

      List<List<HuntCatch>> catchGroups = [];
      if (_isOwnProfile) {
        final catches = await service.fetchUserCatches(widget.userId);
        // Quick-logged catches (no photo — see the FAB flow) only ever
        // increment the species counters server-side; they must never
        // render as a card here. Filter them out before grouping so an
        // empty/photo-less group can never produce a placeholder tile.
        final catchesWithPhotos = catches
            .where((c) => c.imageUrl != null && c.imageUrl!.isNotEmpty)
            .toList();
        catchGroups = groupCatchesByLocation(catchesWithPhotos)
          ..sort((a, b) => b.first.createdAt.compareTo(a.first.createdAt));
      }

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _rank = rank;
        _catchGroups = catchGroups;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _changeAvatar() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await SupabaseService.instance.uploadAvatar(bytes);
      final updated =
          await SupabaseService.instance.updateProfile(avatarUrl: url);
      if (mounted) setState(() => _profile = updated);
    } catch (e) {
      _showError('${_tr('update_photo_failed')}: $e');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _editUsername(String currentUsername) async {
    final controller = TextEditingController(text: currentUsername);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr('edit_name_title')),
        content: TextField(
          controller: controller,
          textAlign: TextAlign.center,
          decoration: InputDecoration(labelText: _tr('username_label')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(_tr('save')),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == currentUsername)
      return;

    try {
      final updated =
          await SupabaseService.instance.updateProfile(username: newName);
      if (mounted) setState(() => _profile = updated);
    } catch (e) {
      _showError('${_tr('update_name_failed')}: $e');
    }
  }

  /// Opens the combined gender / city / birthdate editor, pre-filled
  /// with real values where present (mock values are NEVER pre-filled
  /// as if they were real — the field starts empty so the user
  /// consciously picks their actual data).
  Future<void> _editPersonalDetails() async {
    final result = await showModalBottomSheet<_PersonalDetailsResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1F1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _EditPersonalDetailsSheet(
        initialGender: _profile?.gender,
        initialCity: (_profile?.city != null && _profile!.city!.isNotEmpty)
            ? _profile!.city
            : null,
        initialBirthdate: _profile?.birthdate,
      ),
    );
    if (result == null) return;

    try {
      final updated = await SupabaseService.instance.updateProfile(
        gender: result.gender,
        city: result.city,
        birthdate: result.birthdate,
      );
      if (mounted) setState(() => _profile = updated);
    } catch (e) {
      _showError('${_tr('update_data_failed')}: $e');
    }
  }

  Future<void> _confirmDeleteGroup(List<HuntCatch> group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr('delete_record_title')),
        content: Text(
          group.length > 1
              ? _tr('delete_record_body_multi')
                  .replaceAll('{n}', '${group.length}')
              : _tr('delete_record_body_single'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(_tr('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // 1) Fully await the remote deletion first — nothing touches
    //    widget state until this completes. deleteCatchGroup verifies
    //    the actual deleted row count and throws if RLS silently
    //    blocked it, so a failure here is never silent.
    try {
      await SupabaseService.instance.deleteCatchGroup(group);
    } catch (e) {
      _showError('${_tr('delete_record_failed')}: $e');
      return;
    }

    // 2) Only now, synchronously remove the deleted group from the
    //    already-loaded local list — no network call inside setState,
    //    no re-fetch, just a plain in-memory list mutation.
    if (!mounted) return;
    setState(() {
      _catchGroups = _catchGroups.where((g) => g != group).toList();
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
    // No manual navigation needed — _RootGate's StreamBuilder in
    // main.dart listens to onAuthStateChange and will automatically
    // route back to the sign-in screen the moment the session clears.
    await Supabase.instance.client.auth.signOut();
  }

  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1F1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // Whole sheet wrapped in one Consumer so every string in it
      // (not just the language tile) live-updates the instant the
      // language changes, and so every label below can use the same
      // `tr('key')` call syntax off one local closure.
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final language = ref.watch(localeProvider);
          String tr(String key) => AppStrings.translate(key, language);

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(tr('settings_title'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                // "تغيير اللغة" — directly above "التواصل والدعم الذكي"
                // as specified.
                ListTile(
                  leading: const Icon(Icons.language_outlined,
                      color: Color(0xFF66BB6A)),
                  title: Text(tr('change_language')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LanguageFlagIcon(language: language, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        language.nativeName,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                  onTap: () => showLanguageSelectionSheet(context),
                ),
                ListTile(
                  leading: const Icon(Icons.support_agent_outlined,
                      color: Color(0xFF66BB6A)),
                  title: Text(tr('support_chat')),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SupportChatScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.gavel_outlined,
                      color: Color(0xFF66BB6A)),
                  title: Text(tr('legal_compliance')),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LegalComplianceScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined,
                      color: Colors.redAccent),
                  title: Text(tr('delete_account'),
                      style: const TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DeleteAccountScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: Text(tr('logout'),
                      style: const TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    _logout();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openReportDialog() async {
    final availableTags = [
      _tr('report_reason_offensive_photo'),
      _tr('report_reason_inappropriate_name'),
      _tr('report_reason_stats_cheating'),
      _tr('report_reason_illegal_content'),
      _tr('report_reason_abuse_harassment'),
      _tr('report_reason_other'),
    ];
    final selectedTags = <String>{};
    final detailsController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_tr('report_user_title')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_tr('choose_report_reason'),
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableTags.map((tag) {
                    final selected = selectedTags.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: selected,
                      onSelected: (value) => setDialogState(() {
                        if (value) {
                          selectedTags.add(tag);
                        } else {
                          selectedTags.remove(tag);
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: detailsController,
                  maxLines: 3,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    labelText: _tr('additional_details_optional'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_tr('cancel')),
            ),
            FilledButton(
              onPressed: selectedTags.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: Text(_tr('send_report')),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await SupabaseService.instance.submitUserReport(
        reportedUserId: widget.userId,
        tags: selectedTags.toList(),
        details: detailsController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr('report_sent_thanks'))),
        );
      }
    } catch (e) {
      _showError('${_tr('send_report_failed')}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(localeProvider);
    String tr(String key) => AppStrings.translate(key, language);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('profile_title')),
        // Under the app's global RTL Directionality, `actions` render
        // at the trailing edge, which is the visual LEFT side. Only the
        // owner sees settings/notifications here; a public viewer sees
        // nothing in the app bar (their action is the report button
        // shown lower in the body instead).
        actions: _isOwnProfile
            ? [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: tr('settings_title'),
                  onPressed: _openSettingsSheet,
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  tooltip: tr('notifications_tooltip'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationCenterScreen()),
                  ),
                ),
              ]
            : null,
      ),
      body: Builder(
        builder: (context) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_errorMessage != null) {
            return Center(child: Text('${tr('error_prefix')}: $_errorMessage'));
          }

          final profile = _profile!;

          return RefreshIndicator(
            onRefresh: _loadProfileData,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: (_isOwnProfile && !_uploadingAvatar)
                            ? _changeAvatar
                            : null,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundImage: profile.avatarUrl != null
                                  ? NetworkImage(profile.avatarUrl!)
                                  : null,
                              child: profile.avatarUrl == null
                                  ? const Icon(Icons.person, size: 48)
                                  : null,
                            ),
                            // Camera edit badge — own profile only.
                            if (_isOwnProfile)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  child: _uploadingAvatar
                                      ? const Padding(
                                          padding: EdgeInsets.all(3.0),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.camera_alt,
                                          size: 16, color: Colors.white),
                                ),
                              ),
                            // Gender icon badge — bottom-left corner of
                            // the avatar, blue ♂ / pink ♀. Uses the mock
                            // fallback on your own profile if unset, so
                            // legacy accounts never show a blank corner.
                            if (_displayGender != null)
                              Positioned(
                                left: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onTap: _isOwnProfile
                                      ? _editPersonalDetails
                                      : null,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _displayGender == 'male'
                                          ? const Color(0xFF2196F3)
                                          : const Color(0xFFEC407A),
                                      border: Border.all(
                                          color: Colors.black, width: 2),
                                    ),
                                    child: Icon(
                                      _displayGender == 'male'
                                          ? Icons.male
                                          : Icons.female,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _isOwnProfile
                            ? () => _editUsername(profile.username)
                            : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              profile.username,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            if (_isOwnProfile) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.edit, size: 18),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // --- Age • City row — directly under the username, and
                // directly above the rank badge. Includes an edit pencil
                // (own profile only) and a small hint if any of the
                // three fields are still using mock defaults.
                if (_displayAge != null || _displayCity != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              [
                                if (_displayAge != null)
                                  '$_displayAge ${tr('age_suffix')}',
                                if (_displayCity != null) _displayCity!,
                              ].join('  •  '),
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_isOwnProfile) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: _editPersonalDetails,
                                child: const Icon(Icons.edit,
                                    size: 15, color: Colors.white54),
                              ),
                            ],
                          ],
                        ),
                        if (_hasAnyMockValue)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: GestureDetector(
                              onTap: _editPersonalDetails,
                              child: Text(
                                tr('default_data_note'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.amberAccent,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // Public-profile-only action: reporting a peer. Never
                // shown on your own profile, and no account-editing
                // actions appear anywhere on someone else's profile —
                // every edit affordance above is already gated behind
                // _isOwnProfile.
                if (!_isOwnProfile)
                  Center(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                      onPressed: _openReportDialog,
                      icon: const Icon(Icons.flag_outlined, size: 18),
                      label: Text(tr('report_user_button')),
                    ),
                  ),
                if (!_isOwnProfile) const SizedBox(height: 20),

                Center(
                  child: CompetitiveRankBadge(rank: _rank, size: 88),
                ),
                const SizedBox(height: 24),
                Text(tr('game_counter'),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                PreyCounter(profile: profile),

                if (allBadgesFor(profile).isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(tr('achievement_medals'),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: allBadgesFor(profile).map((b) {
                      return Container(
                        width: 108,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              b.tier.color.withValues(alpha: 0.22),
                              b.tier.color.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: b.tier.color.withValues(alpha: 0.6)),
                        ),
                        child: Column(
                          children: [
                            AchievementMedalIcon(tier: b.tier, size: 40),
                            const SizedBox(height: 8),
                            Text(
                              b.species.label(language),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                            Text(
                              b.tier.label(language),
                              style: TextStyle(
                                  color: b.tier.color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],

                if (_isOwnProfile) ...[
                  const SizedBox(height: 24),
                  Text(tr('my_catch_logs'),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (_catchGroups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        tr('no_catches_yet'),
                        style: const TextStyle(color: Colors.white54),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _catchGroups.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemBuilder: (context, index) {
                        final group = _catchGroups[index];
                        final cover = group.first;
                        return GestureDetector(
                          onTap: () => showPhotoSwipeViewer(context, group),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: (cover.imageUrl == null ||
                                          cover.imageUrl!.isEmpty)
                                      ? Container(
                                          color: Colors.brown.shade300,
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.pets,
                                              color: Colors.white70, size: 28),
                                        )
                                      : Image.network(
                                          cover.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stack) =>
                                                  Container(
                                            color: Colors.brown.shade300,
                                            child: const Icon(
                                                Icons.image_not_supported),
                                          ),
                                        ),
                                ),
                              ),
                              if (group.length > 1)
                                Positioned(
                                  left: 4,
                                  bottom: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${group.length}',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 11),
                                    ),
                                  ),
                                ),
                              Positioned(
                                right: 2,
                                top: 2,
                                child: GestureDetector(
                                  onTap: () => _confirmDeleteGroup(group),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black87,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.delete_outline,
                                        color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PersonalDetailsResult {
  final String? gender;
  final String? city;
  final DateTime? birthdate;
  const _PersonalDetailsResult({this.gender, this.city, this.birthdate});
}

/// Bottom sheet for editing gender / city / birthdate together, reusing
/// the same searchable city picker and day/month/year dropdowns as
/// sign-up so the experience is identical.
class _EditPersonalDetailsSheet extends ConsumerStatefulWidget {
  final String? initialGender;
  final String? initialCity;
  final DateTime? initialBirthdate;

  const _EditPersonalDetailsSheet({
    this.initialGender,
    this.initialCity,
    this.initialBirthdate,
  });

  @override
  ConsumerState<_EditPersonalDetailsSheet> createState() =>
      _EditPersonalDetailsSheetState();
}

class _EditPersonalDetailsSheetState
    extends ConsumerState<_EditPersonalDetailsSheet> {
  String? _gender;
  String? _city;
  int? _day;
  int? _month;
  int? _year;

  @override
  void initState() {
    super.initState();
    _gender = widget.initialGender;
    _city = widget.initialCity;
    final bd = widget.initialBirthdate;
    if (bd != null) {
      _day = bd.day;
      _month = bd.month;
      _year = bd.year;
    }
  }

  Future<void> _pickCity() async {
    final result = await showCityPickerSheet(context);
    if (result != null) setState(() => _city = result);
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(localeProvider);
    String tr(String key) => AppStrings.translate(key, language);
    final birthdate = buildValidBirthdate(_day, _month, _year);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('edit_personal_details_title'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: Text(tr('gender_label'),
                style: const TextStyle(color: Colors.white70)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _GenderChipSmall(
                  label: tr('gender_male'),
                  icon: Icons.male,
                  color: const Color(0xFF2196F3),
                  selected: _gender == 'male',
                  onTap: () => setState(() => _gender = 'male'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GenderChipSmall(
                  label: tr('gender_female'),
                  icon: Icons.female,
                  color: const Color(0xFFEC407A),
                  selected: _gender == 'female',
                  onTap: () => setState(() => _gender = 'female'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: Text(tr('city_label'),
                style: const TextStyle(color: Colors.white70)),
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pickCity,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_city_outlined,
                      color: Colors.white54),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _city ?? tr('choose_city'),
                      style: TextStyle(
                        color: _city == null ? Colors.white38 : Colors.white,
                      ),
                    ),
                  ),
                  const Icon(Icons.expand_more, color: Colors.white54),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: Text(tr('birthdate_label'),
                style: const TextStyle(color: Colors.white70)),
          ),
          const SizedBox(height: 8),
          BirthdateDropdownsRow(
            day: _day,
            month: _month,
            year: _year,
            onDayChanged: (v) => setState(() => _day = v),
            onMonthChanged: (v) => setState(() => _month = v),
            onYearChanged: (v) => setState(() => _year = v),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _PersonalDetailsResult(
                  gender: _gender, city: _city, birthdate: birthdate),
            ),
            child: Text(tr('save')),
          ),
        ],
      ),
    );
  }
}

class _GenderChipSmall extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChipSmall({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? color : Colors.transparent, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : Colors.white54, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
