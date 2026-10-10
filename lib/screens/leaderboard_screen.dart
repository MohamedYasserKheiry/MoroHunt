import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../models/competitive_rank.dart';
import '../models/hunt_catch.dart';
import '../models/hunter_profile.dart';
import '../providers/locale_provider.dart';
import '../services/supabase_service.dart';
import '../utils/achievement_badges.dart';
import '../widgets/achievement_medal_icon.dart';
import '../widgets/competitive_rank_badge.dart';
import 'profile_screen.dart';

/// Tab 2 — "لوحة الشرف": a single, permanent hunters ranking — "ترتيب
/// القناصة" — with a search bar at the top filtering by display name.
/// (The former Dogs Ranking tab has been removed entirely; this screen
/// no longer has a TabBar at all.) Rank tiers: الفولاذي (Steel) →
/// الورقة الرابحة (Ace, #4-10) → الماسي (Diamond, #2-3) → الذهبي
/// (Gold, #1 only).
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String _searchQuery = '';
  late Future<List<HunterProfile>> _future;
  StreamSubscription<void>? _catchesChangedSubscription;

  String _tr(String key) => AppStrings.translate(key, ref.read(localeProvider));

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.instance.fetchLeaderboard();

    // Refresh automatically the moment any catch is logged/deleted
    // anywhere in the app (e.g. the quick-catch FAB), so counts, rank
    // points, and badges here are never stale — no manual refresh
    // needed even if this tab was already open when the catch happened.
    _catchesChangedSubscription =
        SupabaseService.instance.catchesChangedStream.listen((_) => _refresh());
  }

  @override
  void dispose() {
    _catchesChangedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final data = SupabaseService.instance.fetchLeaderboard();
    setState(() {
      _future = data;
    });
    await data;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider); // subscribe so a language change rebuilds this
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('nav_leaderboard')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              onChanged: (value) => setState(() => _searchQuery = value.trim()),
              decoration: InputDecoration(
                hintText: _tr('search_by_name_hint'),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<HunterProfile>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${_tr('error_prefix')}: ${snapshot.error}'));
          }

          // Full ordering (and therefore rank tier) is always computed
          // against the complete unfiltered list, then the search
          // query only narrows which rows are *displayed*.
          final allHunters = snapshot.data!;
          final query = _searchQuery.toLowerCase();
          final visibleIndexes = <int>[
            for (var i = 0; i < allHunters.length; i++)
              if (query.isEmpty || allHunters[i].username.toLowerCase().contains(query))
                i,
          ];

          if (allHunters.isEmpty) {
            return Center(child: Text(_tr('no_hunters_yet')));
          }
          if (visibleIndexes.isEmpty) {
            return Center(child: Text(_tr('no_matching_results')));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: visibleIndexes.length,
              itemBuilder: (context, listIndex) {
                final originalIndex = visibleIndexes[listIndex];
                final hunter = allHunters[originalIndex];
                final rank = CompetitiveRank.fromPosition(originalIndex + 1);
                return _LeaderboardTile(
                  position: originalIndex + 1,
                  rank: rank,
                  title: hunter.username,
                  subtitle: '${hunter.rankPoints} ${_tr('points_suffix')}',
                  avatarUrl: hunter.avatarUrl,
                  achievementBadges: allBadgesFor(hunter),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: hunter.id),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------
// ROW WIDGET
// ---------------------------------------------------------------------

class _LeaderboardTile extends StatelessWidget {
  final int position;
  final CompetitiveRank rank;
  final String title;
  final String subtitle;
  final String? avatarUrl;
  final List<({PreyType species, BadgeTier tier})> achievementBadges;
  final VoidCallback? onTap;

  const _LeaderboardTile({
    required this.position,
    required this.rank,
    required this.title,
    required this.subtitle,
    this.avatarUrl,
    this.achievementBadges = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isGold = rank == CompetitiveRank.gold;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: isGold ? 6 : 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isGold
            ? BorderSide(color: rank.color, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '#$position',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 22,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                child: avatarUrl == null ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                    if (achievementBadges.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 22,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: achievementBadges
                              .map((b) => Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: AchievementMedalIcon(tier: b.tier, size: 18),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              CompetitiveRankBadge(rank: rank, size: 44, showLabel: false),
            ],
          ),
        ),
      ),
    );
  }
}
