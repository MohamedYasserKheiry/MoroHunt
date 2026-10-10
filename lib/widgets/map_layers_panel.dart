import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../models/map_zone.dart';
import '../providers/locale_provider.dart';
import '../providers/map_layers_provider.dart';

/// "طبقات الخريطة" — a floating side card anchored to the right edge
/// of the map, NOT a bottom sheet / modal route. It renders inline in
/// the map screen's Stack (see `MapScreen`), so it never blocks
/// gestures on the rest of the screen and can stay open while the
/// user keeps interacting with the map.
///
/// The base-map (satellite/OSM) toggle intentionally lives outside
/// this panel — see the dedicated FAB in `MapScreen`. This card holds
/// exactly two overlay layers: مكري / محميات. مناطق مفتوحة (open
/// zones) and معالم (POIs) were removed entirely — no switches, no
/// underlying state, no rendering.
class MapLayersSidePanel extends ConsumerWidget {
  final VoidCallback onClose;

  const MapLayersSidePanel({required this.onClose, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layers = ref.watch(mapLayersProvider);
    final controller = ref.read(mapLayersProvider.notifier);
    final language = ref.watch(localeProvider);
    String tr(String key) => AppStrings.translate(key, language);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 250,
          constraints: const BoxConstraints(maxHeight: 420),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1F1A).withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close,
                        color: Colors.white54, size: 20),
                    onPressed: onClose,
                  ),
                  Expanded(
                    child: Text(
                      tr('map_layers_title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 28), // balances the close icon
                ],
              ),
              const Divider(color: Colors.white12, height: 20),
              _ZoneCategorySwitch(
                category: HuntZoneCategory.amodie,
                value: layers.isAmodieVisible,
                onChanged: controller.toggleAmodie,
                language: language,
              ),
              _ZoneCategorySwitch(
                category: HuntZoneCategory.reserve,
                value: layers.isReserveVisible,
                onChanged: controller.toggleReserve,
                language: language,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoneCategorySwitch extends StatelessWidget {
  final HuntZoneCategory category;
  final bool value;
  final ValueChanged<bool> onChanged;
  final AppLanguage language;

  const _ZoneCategorySwitch({
    required this.category,
    required this.value,
    required this.onChanged,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    return _LayerSwitchTile(
      leading: Icon(Icons.circle, color: category.color, size: 14),
      title: category.label(language),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// Shared row layout: colored leading icon, single Arabic title,
/// trailing Switch — compact enough to fit the narrow side card.
class _LayerSwitchTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _LayerSwitchTile({
    required this.leading,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      secondary: leading,
      activeThumbColor: const Color(0xFF2E7D32),
      title: Text(
        title,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
