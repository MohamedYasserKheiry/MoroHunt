import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n/app_strings.dart';
import 'providers/locale_provider.dart';
import 'screens/group_hunt_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/map_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/quick_catch_sheet.dart';
import 'services/ad_service.dart';
import 'services/offline_tile_service.dart';
import 'services/supabase_service.dart';
import 'widgets/app_logo.dart';
import 'widgets/birthdate_dropdowns.dart';
import 'widgets/city_picker_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.initialize(
    // TODO: move these into --dart-define / a .env file before shipping.
    supabaseUrl: 'https://xjkiixvagmdjzxcjajfb.supabase.co',
    supabaseAnonKey: 'sb_publishable_0kutmJlVOMoMMgCAE-duxw_bQnHB_kv',
  );

  await OfflineTileService.initialize();

  // Start the Mobile Ads SDK and preload the interstitial in the
  // background. Deliberately NOT awaited so app startup is never delayed
  // by ads; AdService swallows its own errors.
  unawaited(AdService.instance.initialize());

  runApp(const ProviderScope(child: MoroHuntApp()));
}

class MoroHuntApp extends ConsumerWidget {
  const MoroHuntApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching localeProvider here is what makes a language change
    // apply instantly, app-wide: MaterialApp rebuilds with the new
    // Locale, and every descendant picks up the new Directionality
    // through the normal widget-tree inheritance mechanism — no
    // per-screen wiring needed.
    final language = ref.watch(localeProvider);

    // Flutter's built-in Material/Cupertino localizations ship no
    // data for Amazigh ('zgh') — passing it straight to `locale`
    // risks a "No MaterialLocalizations found" crash the moment a
    // core widget (Scaffold, a TextField's context menu, ...) looks
    // it up. So: fall back to Arabic for the FRAMEWORK-CHROME locale
    // only when Amazigh is selected. Our own UI text and
    // Directionality below still follow the real `language` value
    // everywhere — this fallback is invisible to the user.
    final frameworkLocale = language == AppLanguage.amazigh
        ? AppLanguage.arabic.locale
        : language.locale;

    return MaterialApp(
      title: 'MoroHunt · قناص المغرب',
      debugShowCheckedModeBanner: false,
      locale: frameworkLocale,
      supportedLocales: const [Locale('ar'), Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2E7D32),
        brightness: Brightness.dark,
      ),
      builder: (context, child) {
        // Layout structure stays FIXED right-to-left regardless of
        // the selected language — only the strings themselves change.
        // Deliberately NOT `language.textDirection` here: that field
        // still exists on AppLanguage as informational metadata (and
        // is what earlier drove this), but per the fixed-layout
        // requirement, this wrapper always forces RTL so nav bars,
        // icon rows, etc. never mirror when switching to French/
        // English/Amazigh.
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const _RootGate(),
    );
  }
}

/// Listens to Supabase auth state and routes to sign-in/sign-up or the
/// 4-tab app shell.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return const _AuthScreen();
        }
        return _HomeShell(userId: session.user.id);
      },
    );
  }
}

enum _Gender { male, female }

/// Combined sign-in / sign-up screen with a premium dark-theme layout.
/// Sign-up collects: full name, email, a single strong password
/// (validated live — no confirm-password field), gender (styled ♂/♀
/// chips), city (searchable picker from a fixed Moroccan-cities list),
/// and birthdate via 3 Facebook-style day/month/year dropdowns. Age is
/// derived live from the birthdate, never stored as its own value.
class _AuthScreen extends ConsumerStatefulWidget {
  const _AuthScreen();

  @override
  ConsumerState<_AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<_AuthScreen> {
  bool _isSignUp = false;
  bool _loading = false;
  String? _errorMessage;

  String _tr(String key) => AppStrings.translate(key, ref.read(localeProvider));

  // Shared
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Sign-up only
  final _fullNameController = TextEditingController();
  bool _obscureSignUpPassword = true;
  _Gender? _gender;
  String? _selectedCity;
  int? _birthDay;
  int? _birthMonth;
  int? _birthYear;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  DateTime? get _birthdate =>
      buildValidBirthdate(_birthDay, _birthMonth, _birthYear);

  int? get _computedAge {
    final bd = _birthdate;
    if (bd == null) return null;
    final now = DateTime.now();
    var age = now.year - bd.year;
    if (now.month < bd.month || (now.month == bd.month && now.day < bd.day)) {
      age--;
    }
    return age;
  }

  /// At least 8 chars, 1 uppercase, 1 lowercase, 1 digit, 1 special char.
  static final _strongPasswordPattern = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$%\^&\*\(\)_\+\-=\[\]{};:\.,<>\?]).{8,}$',
  );

  Future<void> _pickCity() async {
    final result = await showCityPickerSheet(context);
    if (result != null) setState(() => _selectedCity = result);
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = _describeAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signUp() async {
    setState(() => _errorMessage = null);

    if (_fullNameController.text.trim().isEmpty) {
      setState(() => _errorMessage = _tr('enter_full_name'));
      return;
    }
    if (!_strongPasswordPattern.hasMatch(_passwordController.text)) {
      setState(
        () => _errorMessage = _tr('weak_password_message'),
      );
      return;
    }
    if ((_birthDay != null || _birthMonth != null || _birthYear != null) &&
        _birthdate == null) {
      setState(() => _errorMessage = _tr('invalid_birthdate'));
      return;
    }

    setState(() => _loading = true);
    try {
      final bd = _birthdate;
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'username': _fullNameController.text.trim(),
          if (_gender != null) 'gender': _gender!.name,
          if (_selectedCity != null) 'city': _selectedCity,
          if (bd != null)
            'birthdate': '${bd.year.toString().padLeft(4, '0')}-'
                '${bd.month.toString().padLeft(2, '0')}-'
                '${bd.day.toString().padLeft(2, '0')}',
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr('account_created_message'))),
        );
        setState(() => _isSignUp = false);
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = _describeAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Turns a raw sign-in/sign-up exception into a user-facing message.
  ///
  /// `ClientException: Failed to fetch` (the web-only error this
  /// screen used to swallow as a generic "unexpected error") means the
  /// browser's network request never got a response at all — almost
  /// always because the Supabase project is paused/deleted, the URL
  /// or anon key is wrong, or a browser extension/network is blocking
  /// the request. It is NOT something `Supabase.initialize()` can fix
  /// with headers/config, since the browser — not this Dart code —
  /// enforces CORS before the request even reaches app code. See the
  /// SupabaseService.initialize doc comment for the actual checklist.
  ///
  /// In debug builds the full exception is also printed to the
  /// console so the real cause is visible while developing, instead
  /// of only ever showing the generic translated message.
  String _describeAuthError(Object e) {
    if (kDebugMode) {
      debugPrint('[Auth] raw error: $e');
    }
    final text = e.toString();
    final looksLikeNetworkFailure = text.contains('Failed to fetch') ||
        text.contains('ClientException') ||
        text.contains('SocketException') ||
        text.contains('Connection refused') ||
        text.contains('Connection closed');
    return looksLikeNetworkFailure
        ? _tr('network_error')
        : _tr('unexpected_error');
  }

  InputDecoration _fieldDecoration(
    String label, {
    Widget? suffixIcon,
    Widget? prefixIcon,
  }) {
    final radius = BorderRadius.circular(14);
    return InputDecoration(
      labelText: label,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: Color(0xFF66BB6A), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E1410), Color(0xFF060806)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.035),
                  borderRadius: BorderRadius.circular(24),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  // Column already centers non-stretched children on
                  // the cross axis by default, but making it explicit
                  // here (rather than relying on that default) so the
                  // logo's centering doesn't depend on an implicit
                  // Flutter behavior.
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Center(child: AppLogo(size: 100)),
                    const SizedBox(height: 12),
                    Text(
                      'MoroHunt · قناص المغرب',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isSignUp
                          ? _tr('create_account_title')
                          : _tr('login_title'),
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: Colors.white60),
                    ),
                    const SizedBox(height: 28),
                    if (_isSignUp) ...[
                      TextField(
                        controller: _fullNameController,
                        decoration: _fieldDecoration(
                          _tr('full_name_label'),
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _fieldDecoration(
                        _tr('email_label'),
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText:
                          _isSignUp ? _obscureSignUpPassword : _obscurePassword,
                      decoration: _fieldDecoration(
                        _tr('password_label'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            (_isSignUp
                                    ? _obscureSignUpPassword
                                    : _obscurePassword)
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(() {
                            if (_isSignUp) {
                              _obscureSignUpPassword = !_obscureSignUpPassword;
                            } else {
                              _obscurePassword = !_obscurePassword;
                            }
                          }),
                        ),
                      ),
                    ),
                    if (_isSignUp) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, right: 4),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _tr('password_hint'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _tr('gender_label'),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _GenderChip(
                              label: _tr('gender_male'),
                              icon: Icons.male,
                              color: const Color(0xFF2196F3),
                              selected: _gender == _Gender.male,
                              onTap: () =>
                                  setState(() => _gender = _Gender.male),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _GenderChip(
                              label: _tr('gender_female'),
                              icon: Icons.female,
                              color: const Color(0xFFEC407A),
                              selected: _gender == _Gender.female,
                              onTap: () =>
                                  setState(() => _gender = _Gender.female),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _tr('city_label'),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _pickCity,
                        child: InputDecorator(
                          decoration: _fieldDecoration(
                            '',
                            prefixIcon: const Icon(
                              Icons.location_city_outlined,
                            ),
                            suffixIcon: const Icon(Icons.expand_more),
                          ),
                          child: Text(
                            _selectedCity ?? _tr('choose_city'),
                            style: TextStyle(
                              color: _selectedCity == null
                                  ? Colors.white38
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _tr('birthdate_label'),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 8),
                      BirthdateDropdownsRow(
                        day: _birthDay,
                        month: _birthMonth,
                        year: _birthYear,
                        onDayChanged: (v) => setState(() => _birthDay = v),
                        onMonthChanged: (v) => setState(() => _birthMonth = v),
                        onYearChanged: (v) => setState(() => _birthYear = v),
                      ),
                      if (_computedAge != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              _tr('age_label')
                                  .replaceAll('{n}', '$_computedAge'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 20),
                    if (_errorMessage != null) ...[
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_loading)
                      const CircularProgressIndicator()
                    else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _isSignUp ? _signUp : _signIn,
                          child: Text(
                            _isSignUp
                                ? _tr('create_account_title')
                                : _tr('login_title'),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isSignUp = !_isSignUp;
                            _errorMessage = null;
                          });
                        },
                        child: Text(
                          _isSignUp
                              ? _tr('toggle_to_login')
                              : _tr('toggle_to_signup'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChip({
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : Colors.white54, size: 26),
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

/// The 4-tab bottom navigation shell:
/// خريطة القنص · لوحة الشرف · قنص جماعي · الملف الشخصي
class _HomeShell extends ConsumerStatefulWidget {
  final String userId;
  const _HomeShell({required this.userId});

  @override
  ConsumerState<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<_HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // Local tr() closure bound to the current language — see
    // lib/l10n/app_strings.dart for the dictionary. Any widget that's
    // Consumer-based can add this exact 2-line pattern to get the
    // same `tr('key')` call syntax used here.
    final language = ref.watch(localeProvider);
    String tr(String key) => AppStrings.translate(key, language);

    final screens = [
      // isActive lets the Map screen know when its tab is (re)selected —
      // IndexedStack keeps it alive, so initState alone only fires once.
      MapScreen(isActive: _index == 0),
      const LeaderboardScreen(),
      const GroupHuntScreen(),
      ProfileScreen(userId: widget.userId),
    ];

    // The bottom system inset (home-indicator / gesture bar on phones;
    // 0 on web/desktop) must be ADDED on top of the nav bar's own
    // height, never carved out of it — that inversion is exactly what
    // caused the overflow to get worse last time (a SafeArea nested
    // inside an already-fixed height subtracts from that budget
    // instead of extending it).
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const barContentHeight = kBottomNavigationBarHeight; // 56.0

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        tooltip: tr('log_new_catch'),
        mini: false,
        backgroundColor: Theme.of(context).colorScheme.primary,
        onPressed: () => showQuickCatchSheet(context),
        child: const Icon(Icons.add, size: 28),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: const Color(0xFF15170F),
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        // Fixed total height = the nav bar's own content height PLUS
        // the device's bottom inset, exactly as requested — never one
        // subtracted from the other.
        height: barContentHeight + bottomInset,
        child: Padding(
          // Reserve the inset as space BELOW the icon row, so the
          // system's home-indicator area never overlaps the icons, and
          // the icon row itself always gets the full 56px it needs.
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: _NavIconButton(
                  icon: Icons.map_outlined,
                  selectedIcon: Icons.map,
                  label: tr('nav_map'),
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0),
                ),
              ),
              Expanded(
                child: _NavIconButton(
                  icon: Icons.leaderboard_outlined,
                  selectedIcon: Icons.leaderboard,
                  label: tr('nav_leaderboard'),
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1),
                ),
              ),
              const SizedBox(width: 56), // reserved for the FAB notch
              Expanded(
                child: _NavIconButton(
                  icon: Icons.groups_outlined,
                  selectedIcon: Icons.groups,
                  label: tr('nav_group_hunt'),
                  selected: _index == 2,
                  onTap: () => setState(() => _index = 2),
                ),
              ),
              Expanded(
                child: _NavIconButton(
                  icon: Icons.person_outline,
                  selectedIcon: Icons.person,
                  label: tr('nav_profile'),
                  selected: _index == 3,
                  onTap: () => setState(() => _index = 3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A nav item whose icon+label are wrapped in a [FittedBox] with
/// [BoxFit.scaleDown] — this is the structural guarantee against
/// overflow: FittedBox shrinks its child to fit whatever space it's
/// given and NEVER overflows its constraints, by definition, regardless
/// of exact pixel budgets, font metrics, or device text-scale settings.
class _NavIconButton extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavIconButton({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? Theme.of(context).colorScheme.primary : Colors.white54;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? selectedIcon : icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(color: color, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
