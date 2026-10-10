import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../providers/locale_provider.dart';
import 'flag_icons.dart';

/// Opens the language picker as a bottom sheet listing all 4
/// supported languages with their flag + native name. Tapping one
/// switches the app's locale immediately (via `localeProvider`) and
/// closes the sheet.
Future<void> showLanguageSelectionSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1C1F1A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _LanguageSelectionSheet(),
  );
}

class _LanguageSelectionSheet extends ConsumerWidget {
  const _LanguageSelectionSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider);
    String tr(String key) => AppStrings.translate(key, current);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              tr('change_language'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          for (final language in AppLanguage.values)
            ListTile(
              leading: LanguageFlagIcon(language: language, size: 40),
              title: Text(language.nativeName),
              trailing: language == current
                  ? const Icon(Icons.check_circle, color: Color(0xFF66BB6A))
                  : null,
              onTap: () {
                ref.read(localeProvider.notifier).setLanguage(language);
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
