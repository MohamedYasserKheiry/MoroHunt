import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../l10n/app_strings.dart';
import '../models/hunt_catch.dart';
import '../providers/locale_provider.dart';
import '../services/supabase_service.dart';
import '../utils/achievement_badges.dart';

/// Opens the ultra-fast, no-photo catch logging sheet triggered by the
/// center FAB. Submits one `log_quick_catch` RPC call per species with
/// a non-zero count, then shows a congratulatory dialog for every
/// badge tier crossed in this batch.
Future<void> showQuickCatchSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1C1F1A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _QuickCatchSheet(),
  );
}

class _SpeciesSpec {
  final PreyType type;
  final String emoji;
  const _SpeciesSpec(this.type, this.emoji);

  /// Short-form label key (distinct from PreyType.label, which is the
  /// longer form used elsewhere — this UI needs compact chip labels).
  String get shortLabelKey {
    switch (type) {
      case PreyType.perdrix:
        return 'species_perdrix_short';
      case PreyType.lievre:
        return 'species_lievre_short';
      case PreyType.sanglier:
        return 'species_sanglier_short';
      case PreyType.caille:
        return 'species_caille_short';
      case PreyType.tourtereau:
        return 'species_perdrix_short'; // not offered in this sheet
    }
  }
}

const _species = [
  _SpeciesSpec(PreyType.perdrix, '🐓'),
  _SpeciesSpec(PreyType.lievre, '🐇'),
  _SpeciesSpec(PreyType.sanglier, '🐗'),
  _SpeciesSpec(PreyType.caille, '🐦'),
];

class _QuickCatchSheet extends ConsumerStatefulWidget {
  const _QuickCatchSheet();

  @override
  ConsumerState<_QuickCatchSheet> createState() => _QuickCatchSheetState();
}

class _QuickCatchSheetState extends ConsumerState<_QuickCatchSheet> {
  String _tr(String key) => AppStrings.translate(key, ref.read(localeProvider));
  final Map<PreyType, int> _counts = {for (final s in _species) s.type: 0};
  String _boarWeightTier = 'normal';
  bool _submitting = false;

  double? _lat;
  double? _lng;
  bool _locating = true;

  @override
  void initState() {
    super.initState();
    _captureLocationSilently();
  }

  Future<void> _captureLocationSilently() async {
    try {
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      final pos = await geo.Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
          _locating = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _locating = false);
    }
  }

  int get _totalAnimals => _counts.values.fold(0, (a, b) => a + b);

  int get _estimatedTotalPoints {
    var total = 0;
    for (final s in _species) {
      final c = _counts[s.type] ?? 0;
      if (c == 0) continue;
      final weightTier = s.type == PreyType.sanglier ? _boarWeightTier : null;
      total += pointsForCatch(s.type, weightTier: weightTier) * c;
    }
    return total;
  }

  void _increment(PreyType type) {
    if (_submitting) return; // 🛑 يمنع التعديل أثناء الإرسال
    setState(() => _counts[type] = (_counts[type] ?? 0) + 1);
  }

  void _decrement(PreyType type) {
    if (_submitting) return; // 🛑 يمنع التعديل أثناء الإرسال
    setState(() {
      final current = _counts[type] ?? 0;
      if (current > 0) _counts[type] = current - 1;
    });
  }

  Future<void> _submit() async {
    // 🛑 1. الحماية الرئيسية: يمنع إعادة التنفيذ فوراً إذا كان الطلب جارياً بالفعل
    if (_submitting || _totalAnimals == 0) return;

    if (_lat == null || _lng == null) {
      final retry = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_tr('location_failed_title')),
          content: Text(_tr('location_failed_body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_tr('retry')),
            ),
          ],
        ),
      );
      if (retry == true) {
        setState(() => _locating = true);
        await _captureLocationSilently();
      }
      return;
    }

    // 🔒 قفل الزر والبدء في الإرسال
    setState(() => _submitting = true);

    final language = ref.read(localeProvider);
    final unlockedBadges = <String>[];
    String? errorMessage;
    final totalSubmitted = _totalAnimals;

    try {
      for (final s in _species) {
        final count = _counts[s.type] ?? 0;
        if (count == 0) continue;

        final result = await SupabaseService.instance.logQuickCatch(
          preyType: s.type,
          count: count,
          weightTier: s.type == PreyType.sanglier ? _boarWeightTier : null,
          lat: _lat,
          lng: _lng,
        );

        if (result.badgeUnlocked != null) {
          unlockedBadges.add(
            AppStrings.translate('congrats_badge_message', language)
                .replaceAll('{badge}', '${result.badgeUnlocked}')
                .replaceAll('{species}', s.type.label(language))
                .replaceAll('{count}', '${result.newSpeciesCount}'),
          );
        }
      }
    } catch (e) {
      errorMessage = '$e';
    }

    if (!mounted) return;

    if (errorMessage != null) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_tr('catch_submit_failed')}: $errorMessage')));
      return;
    }

    // 1. حفظ مرجع للـ Context الرئيسي قبل إغلاق الـ Sheet
    final parentContext = Navigator.of(context).context;

    // 2. إغلاق الـ Sheet لمرة واحدة فقط وإرجاع قيمة true لشاشة الخريطة/البروفايل
    Navigator.pop(context, true);

    // 3. التحقق والتأكد من سلامة الـ Context قبل إظهار الأوسمة والـ SnackBar
    if (!parentContext.mounted) return;

    for (final message in unlockedBadges) {
      if (!parentContext.mounted) break;
      await showDialog(
        context: parentContext,
        builder: (ctx) => AlertDialog(
          title: Text(_tr('new_achievement')),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_tr('awesome')),
            ),
          ],
        ),
      );
    }

    if (parentContext.mounted) {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(
          content: Text(AppStrings.translate('catch_logged_success', language)
              .replaceAll('{n}', '$totalSubmitted')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(localeProvider);
    final hasBoar = (_counts[PreyType.sanglier] ?? 0) > 0;

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
            _tr('log_hunt_title'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              _locating ? _tr('locating') : _tr('location_found'),
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: _species.map((s) {
              final count = _counts[s.type] ?? 0;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: count > 0
                      ? Border.all(color: const Color(0xFF66BB6A), width: 1.5)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${s.emoji}  ${AppStrings.translate(s.shortLabelKey, language)}',
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _CounterButton(
                          icon: Icons.remove,
                          onTap: _submitting ? null : () => _decrement(s.type),
                        ),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '$count',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        _CounterButton(
                          icon: Icons.add,
                          onTap: _submitting ? null : () => _increment(s.type),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          if (hasBoar) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Text(_tr('boar_weight_header'),
                  style: const TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _WeightChip(
                    label: _tr('weight_normal'),
                    sublabel: _tr('weight_normal_sublabel'),
                    selected: _boarWeightTier == 'normal',
                    onTap: _submitting
                        ? () {}
                        : () => setState(() => _boarWeightTier = 'normal'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _WeightChip(
                    label: _tr('weight_heavy'),
                    sublabel: _tr('weight_heavy_sublabel'),
                    selected: _boarWeightTier == 'heavy',
                    onTap: _submitting
                        ? () {}
                        : () => setState(() => _boarWeightTier = 'heavy'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _WeightChip(
                    label: _tr('weight_monster'),
                    sublabel: _tr('weight_monster_sublabel'),
                    selected: _boarWeightTier == 'monster',
                    onTap: _submitting
                        ? () {}
                        : () => setState(() => _boarWeightTier = 'monster'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          if (_totalAnimals > 0)
            Center(
              child: Text(
                '${_tr('estimated_total_points_prefix')}: $_estimatedTotalPoints',
                style: const TextStyle(color: Colors.amberAccent, fontSize: 13),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: (_totalAnimals == 0 || _submitting) ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_tr('confirm_and_log')),
            ),
          ),
        ],
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CounterButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: onTap == null ? 0.03 : 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? Colors.white30 : Colors.white,
        ),
      ),
    );
  }
}

class _WeightChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  const _WeightChip({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF66BB6A).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF66BB6A) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13)),
            const SizedBox(height: 2),
            Text(sublabel,
                style: const TextStyle(fontSize: 10, color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
