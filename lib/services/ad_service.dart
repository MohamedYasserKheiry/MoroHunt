import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob interstitial handling for MoroHunt.
///
/// This is the ONLY place in the app that knows the interstitial ad unit
/// id, and the only ad format the app uses (no banner / rewarded /
/// app-open / native). The Map screen is the only caller of
/// [showInterstitialIfAvailable].
///
/// Lifecycle (follows Google's Flutter interstitial guide):
///   1. [initialize] starts the Mobile Ads SDK (non-blocking for startup)
///      and immediately preloads one interstitial.
///   2. [showInterstitialIfAvailable] shows the preloaded ad if there is
///      one. It NEVER blocks the caller's UI: if no ad is ready it waits
///      for a short, bounded time at most, then simply returns false.
///   3. When an ad is dismissed (or fails to show) it is disposed and the
///      next one is preloaded automatically.
///
/// An [InterstitialAd] object can be shown only once, so every ad is
/// disposed after use and a fresh one is loaded.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // ---------------------------------------------------------------------
  // Ad unit ids
  // ---------------------------------------------------------------------

  /// Production interstitial ad unit (AdMob console).
  static const String _productionInterstitialId =
      'ca-app-pub-7957910668550139/4878710513';

  /// Google's official Android test interstitial ad unit. Always safe to
  /// click / impress.
  /// https://developers.google.com/admob/flutter/test-ads
  static const String _testInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';

  /// REAL ads are served only when the app is built with
  ///   --dart-define=ADMOB_PRODUCTION=true
  /// Every other build (debug, profile, plain `flutter build apk
  /// --release`) uses Google's test ad unit, so a developer can never
  /// accidentally impress/click the production ad unit.
  static const bool _useProductionAds =
      bool.fromEnvironment('ADMOB_PRODUCTION');

  static String get _interstitialAdUnitId =>
      _useProductionAds ? _productionInterstitialId : _testInterstitialId;

  // ---------------------------------------------------------------------
  // Tuning
  // ---------------------------------------------------------------------

  /// Minimum time between two interstitials, so quickly flipping between
  /// tabs can't spam the user. Set to [Duration.zero] to show on every
  /// Map opening.
  static const Duration _minIntervalBetweenAds = Duration(minutes: 3);

  /// Google: a loaded interstitial expires after 1 hour. Refresh a bit
  /// earlier rather than risk showing an expired ad.
  static const Duration _adMaxAge = Duration(minutes: 55);

  /// Cap on consecutive failed load attempts (exponential back-off) so a
  /// no-fill / offline state can't hammer the ad server.
  static const int _maxConsecutiveLoadFailures = 3;

  // ---------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------

  Future<void>? _initFuture;
  InterstitialAd? _interstitial;
  DateTime? _interstitialLoadedAt;
  bool _isLoading = false;
  bool _isShowing = false;
  int _consecutiveLoadFailures = 0;
  Timer? _retryTimer;
  Completer<void>? _loadAttempt;
  DateTime? _lastShownAt;
  bool _disposed = false;

  /// The app is an Android app. google_mobile_ads has no web/desktop
  /// implementation, and iOS has no AdMob app id configured in this
  /// project, so initialising there would throw / crash.
  bool get _isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Whether a loaded, non-expired interstitial is waiting to be shown.
  bool get isReady => _interstitial != null && !_isExpired;

  bool get _isExpired {
    final loadedAt = _interstitialLoadedAt;
    return loadedAt != null &&
        DateTime.now().difference(loadedAt) >= _adMaxAge;
  }

  // ---------------------------------------------------------------------
  // Initialise
  // ---------------------------------------------------------------------

  /// Starts the Mobile Ads SDK and preloads the first interstitial.
  /// Safe to call many times; the work happens once. Never throws.
  Future<void> initialize() => _initFuture ??= _initialize();

  Future<void> _initialize() async {
    if (!_isSupportedPlatform) return;
    try {
      await MobileAds.instance.initialize();
      if (kDebugMode) {
        debugPrint(
          '[Ads] SDK initialised. Using '
          '${_useProductionAds ? 'PRODUCTION' : 'TEST'} interstitial unit.',
        );
      }
      _loadInterstitial();
    } catch (e) {
      // Ads are optional: a failure must never affect the app.
      debugPrint('[Ads] SDK initialisation failed: $e');
    }
  }

  // ---------------------------------------------------------------------
  // Load
  // ---------------------------------------------------------------------

  void _loadInterstitial() {
    if (_disposed || !_isSupportedPlatform) return;
    if (_isLoading || _isShowing) return;
    if (_interstitial != null && !_isExpired) return;

    // Drop an expired ad before replacing it.
    _discardLoadedAd();

    _isLoading = true;
    _loadAttempt = Completer<void>();

    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (_disposed) {
            ad.dispose();
            return;
          }
          _interstitial = ad;
          _interstitialLoadedAt = DateTime.now();
          _isLoading = false;
          _consecutiveLoadFailures = 0;
          _finishLoadAttempt();
          if (kDebugMode) debugPrint('[Ads] Interstitial loaded.');
        },
        onAdFailedToLoad: (LoadAdError error) {
          _isLoading = false;
          _consecutiveLoadFailures++;
          _finishLoadAttempt();
          debugPrint('[Ads] Interstitial failed to load: '
              '${error.code} ${error.message}');
          _scheduleRetry();
        },
      ),
    );
  }

  void _finishLoadAttempt() {
    final attempt = _loadAttempt;
    if (attempt != null && !attempt.isCompleted) attempt.complete();
  }

  void _scheduleRetry() {
    if (_disposed) return;
    if (_consecutiveLoadFailures >= _maxConsecutiveLoadFailures) {
      // Give up for now. The next Map opening calls
      // showInterstitialIfAvailable, which starts a fresh attempt.
      return;
    }
    _retryTimer?.cancel();
    // 4s, 8s, ... (exponential back-off).
    final delay = Duration(seconds: 2 << _consecutiveLoadFailures);
    _retryTimer = Timer(delay, _loadInterstitial);
  }

  void _discardLoadedAd() {
    _interstitial?.dispose();
    _interstitial = null;
    _interstitialLoadedAt = null;
  }

  // ---------------------------------------------------------------------
  // Show
  // ---------------------------------------------------------------------

  /// Shows the interstitial if one is available. Returns true if an ad was
  /// handed to the SDK for display.
  ///
  /// * Never throws and never blocks the UI: everything is async, and if no
  ///   ad is ready the wait is capped by [maxWait] (default 3s) after which
  ///   this just returns false and the caller carries on.
  /// * [shouldShow] is re-checked after any wait, so an ad that finished
  ///   loading late is NOT shown if the user has already left the screen.
  /// * Honors a minimum interval between ads and refuses to show two ads
  ///   at the same time.
  Future<bool> showInterstitialIfAvailable({
    Duration maxWait = const Duration(seconds: 3),
    bool Function()? shouldShow,
  }) async {
    if (_disposed || !_isSupportedPlatform || _isShowing) return false;

    final lastShownAt = _lastShownAt;
    if (lastShownAt != null &&
        DateTime.now().difference(lastShownAt) < _minIntervalBetweenAds) {
      return false;
    }

    final deadline = DateTime.now().add(maxWait);

    // SDK may still be starting (e.g. the user is already logged in and
    // lands on the Map right at launch).
    await initialize().timeout(maxWait, onTimeout: () {});

    // Ensure a load is running (e.g. earlier attempts were exhausted).
    if (!isReady) {
      _retryTimer?.cancel();
      _consecutiveLoadFailures = 0;
      _loadInterstitial();
    }

    // Bounded wait for an in-flight load. Not an unbounded await: if the ad
    // isn't ready in time, the Map just opens without it.
    if (!isReady && _loadAttempt != null) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining > Duration.zero) {
        await _loadAttempt!.future.timeout(remaining, onTimeout: () {});
      }
    }

    if (_disposed || _isShowing) return false;
    if (shouldShow != null && !shouldShow()) return false;

    final ad = _interstitial;
    if (ad == null || _isExpired) {
      if (_isExpired) _loadInterstitial();
      return false;
    }

    // Take ownership: an InterstitialAd can be shown only once.
    _interstitial = null;
    _interstitialLoadedAt = null;
    _isShowing = true;
    _lastShownAt = DateTime.now();

    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (shownAd) {
        _isShowing = false;
        shownAd.dispose();
        _loadInterstitial(); // preload the next one
      },
      onAdFailedToShowFullScreenContent: (failedAd, error) {
        debugPrint('[Ads] Interstitial failed to show: '
            '${error.code} ${error.message}');
        _isShowing = false;
        _lastShownAt = null; // nothing was shown, don't start the cooldown
        failedAd.dispose();
        _loadInterstitial();
      },
    );

    try {
      await ad.show();
      return true;
    } catch (e) {
      debugPrint('[Ads] Interstitial show() threw: $e');
      _isShowing = false;
      _lastShownAt = null;
      ad.dispose();
      _loadInterstitial();
      return false;
    }
  }

  // ---------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------

  /// Full teardown: cancels retries and disposes any preloaded ad. The
  /// service is a process-wide singleton that is intentionally kept alive
  /// across Map screen instances (so the next ad stays preloaded); call
  /// this only when the ad system should be shut down for good.
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _discardLoadedAd();
    _finishLoadAttempt();
  }
}
