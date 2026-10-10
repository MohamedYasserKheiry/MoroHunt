import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../providers/locale_provider.dart';

/// "دستور وقوانين التطبيق" — the app's compliance framework: legal
/// hunting seasons/quotas, prohibited content, the administration's
/// content-purge rights, and the liability disclaimer.
///
/// This is original app policy text (not a reproduction of any actual
/// government statute), and deliberately does NOT state specific quota
/// numbers or season date ranges — those are set by yearly ministerial
/// decree and change over time, so hard-coding a figure here could
/// mislead a hunter into relying on stale/wrong information. The text
/// instead points to the relevant authority for the current figures.
///
/// TRANSLATION CAVEAT: the FR/EN copy is a best-effort translation of
/// this app-authored text, not a certified legal translation — get it
/// reviewed before treating it as authoritative. The Amazigh (زgh)
/// copy for this screen specifically uses Latin-script Tamazight
/// (ɣ/ṛ/ḍ) rather than the Tifinagh glyphs used elsewhere in the app —
/// attempting fabricated Tifinagh for legal-register prose this long
/// risked producing nonsense, so Latin Tamazight (a real, also-used
/// writing convention) was the safer failure mode. This inconsistency
/// with the rest of the app's Amazigh presentation should be resolved
/// by a native speaker, not left as-is long-term.
class LegalComplianceScreen extends ConsumerWidget {
  const LegalComplianceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(localeProvider);
    String tr(String key) => AppStrings.translate(key, language);

    return Scaffold(
      appBar: AppBar(title: Text(tr('legal_title'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionCard(
            icon: Icons.gavel_outlined,
            title: tr('legal_section1_title'),
            body: tr('legal_section1_body'),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.block,
            title: tr('legal_section2_title'),
            body: tr('legal_section2_body'),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.delete_sweep_outlined,
            title: tr('legal_section3_title'),
            body: tr('legal_section3_body'),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.warning_amber_outlined,
            title: tr('legal_section4_title'),
            body: tr('legal_section4_body'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _SectionCard(
      {required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF66BB6A)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
                height: 1.7, color: Colors.white70, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}
