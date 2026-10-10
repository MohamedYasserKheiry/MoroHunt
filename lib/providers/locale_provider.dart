import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The 4 languages MoroHunt supports. Each case carries everything the
/// UI needs — locale, native display name, flag glyph, and text
/// direction — so the settings tile / language sheet / MaterialApp
/// wiring all read from one place instead of duplicating a switch
/// statement in three files.
enum AppLanguage {
  arabic(
    locale: Locale('ar'),
    nativeName: 'العربية',
    flagGlyph: '🇲🇦',
    textDirection: TextDirection.rtl,
  ),
  amazigh(
    locale: Locale('zgh'), // Standard Moroccan Tamazight (ISO 639-3)
    nativeName: 'ⵜⴰⵎⴰⵣⵉⵖⵜ',
    flagGlyph: 'ⵣ',
    // Modern digital Tifinagh (the Unicode block) is conventionally
    // rendered left-to-right, unlike Arabic script — flagged as
    // ambiguous in the spec, this is the standard used by Morocco's
    // own digital services.
    textDirection: TextDirection.ltr,
  ),
  french(
    locale: Locale('fr'),
    nativeName: 'Français',
    flagGlyph: '🇫🇷',
    textDirection: TextDirection.ltr,
  ),
  english(
    locale: Locale('en'),
    nativeName: 'English',
    flagGlyph: '🇬🇧',
    textDirection: TextDirection.ltr,
  );

  const AppLanguage({
    required this.locale,
    required this.nativeName,
    required this.flagGlyph,
    required this.textDirection,
  });

  final Locale locale;
  final String nativeName;
  final String flagGlyph;

  /// Informational only — NOT used to drive the app's actual layout
  /// direction anymore. The app's overall structure is locked to RTL
  /// regardless of language (see the `Directionality` wrapper in
  /// main.dart's `MoroHuntApp.build`), so nav bars/icon rows never
  /// mirror when switching languages. This field is kept for any
  /// future per-string direction needs (e.g. an isolated LTR text run
  /// inside an RTL screen).
  final TextDirection textDirection;

  static AppLanguage fromLanguageCode(String? code) {
    return AppLanguage.values.firstWhere(
      (lang) => lang.locale.languageCode == code,
      orElse: () => AppLanguage.arabic,
    );
  }
}

const _prefsKey = 'morohunt_selected_language';

class LocaleController extends StateNotifier<AppLanguage> {
  LocaleController() : super(AppLanguage.arabic) {
    _restore();
  }

  /// Loads the persisted choice on app start. Defaults to Arabic
  /// (matching the app's original hardcoded default) until this
  /// resolves, then swaps in whatever was saved last session.
  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code != null) {
      state = AppLanguage.fromLanguageCode(code);
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, language.locale.languageCode);
  }
}

/// Watch this anywhere the UI needs the current language (flag/name
/// display, direction-sensitive layout, ...). Watching it in
/// `MaterialApp` (see main.dart) is what makes a change apply
/// instantly, app-wide — every widget under it rebuilds through the
/// normal Locale/Directionality inheritance mechanism.
final localeProvider = StateNotifierProvider<LocaleController, AppLanguage>(
  (ref) => LocaleController(),
);
