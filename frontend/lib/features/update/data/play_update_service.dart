import 'dart:io';

import 'package:in_app_update/in_app_update.dart';

import 'update_service.dart';

/// Compile-time flavour flag: true for the build uploaded to Google Play, false
/// for the sideloaded landing-page APK. Set at build time with
/// `--dart-define=PLAY_BUILD=true` (the Play .aab build does this). It lets the
/// app pick the RIGHT update mechanism — Play In-App Updates vs. the direct APK
/// download — with zero runtime guessing.
const bool kPlayBuild =
    bool.fromEnvironment('PLAY_BUILD', defaultValue: false);

/// Google Play In-App Updates — the Play-compliant update path.
///
/// Play forbids an app from downloading/sideloading its own APK, so the old
/// [UpdateService.downloadAndInstall] can NOT be used on a Play build. Instead
/// Play itself performs the update; we only decide WHEN, and whether it's
/// mandatory, using our own backend flag ([UpdateInfo.forced], driven by the
/// server's `min_supported_version`). You keep full control of "this version is
/// now the standard everyone must be on" from the backend — nothing hardcoded.
///
/// Two flavours, matching Play's API:
///   • MANDATORY (forced) → `immediateUpdate`: Play takes over the whole screen
///     and the user cannot use the app until they update (or the update fails).
///   • OPTIONAL → `flexibleUpdate`: downloads in the background; the user keeps
///     using the app and installs when ready.
class PlayUpdateService {
  const PlayUpdateService._();
  static const instance = PlayUpdateService._();

  /// Whether in-app updates can even apply here. Play In-App Updates are Android
  /// only AND only meaningful when the app was installed from Play — so this is
  /// a cheap platform guard; the Play availability check does the real gating.
  bool get _supported => Platform.isAndroid && kPlayBuild;

  /// True when this is the Android build that ships through Google Play — the
  /// only context where Play In-App Updates apply. The shell uses this to choose
  /// the Play update path over the sideload-APK path.
  bool get isAndroidPlayContext => Platform.isAndroid && kPlayBuild;

  /// Ask Play whether an update is available and, if so, what type it can run.
  /// Returns null when unavailable/unsupported (so callers no-op quietly).
  Future<AppUpdateInfo?> _playInfo() async {
    if (!_supported) return null;
    try {
      final info = await InAppUpdate.checkForUpdate();
      return info;
    } catch (_) {
      // Not installed from Play, offline, or Play services missing → no-op.
      return null;
    }
  }

  /// The launch entry point. [forced] comes from OUR backend
  /// ([UpdateInfo.forced] — the installed build is below `min_supported`).
  ///
  ///   • forced == true  → attempt Play's blocking immediateUpdate. Returns
  ///     [PlayUpdateOutcome.blockedNeedsUpdate] if the update is required but
  ///     did NOT complete (user cancelled, or Play can't service it) — the
  ///     caller must then hard-gate the app so it stays unusable.
  ///   • forced == false → if an update exists, kick a silent flexible update
  ///     and return [PlayUpdateOutcome.optionalInProgress]; else
  ///     [PlayUpdateOutcome.upToDate].
  Future<PlayUpdateOutcome> run({required bool forced}) async {
    if (!_supported) return PlayUpdateOutcome.unsupported;

    final info = await _playInfo();
    if (info == null) {
      // Play can't tell us anything. If our server says this build is forced,
      // we still can't let them in — the caller gates. Otherwise, carry on.
      return forced
          ? PlayUpdateOutcome.blockedNeedsUpdate
          : PlayUpdateOutcome.upToDate;
    }

    final hasUpdate =
        info.updateAvailability == UpdateAvailability.updateAvailable;

    if (forced) {
      if (!hasUpdate) {
        // Server says update-required but Play has nothing newer to offer (e.g.
        // Play listing not yet live). Don't fake success — gate the app.
        return PlayUpdateOutcome.blockedNeedsUpdate;
      }
      try {
        final result = await InAppUpdate.performImmediateUpdate();
        // SUCCESS means the update flow completed (the app usually restarts).
        return result == AppUpdateResult.success
            ? PlayUpdateOutcome.updated
            : PlayUpdateOutcome.blockedNeedsUpdate;
      } catch (_) {
        // User dismissed the Play flow, or it errored → keep them blocked.
        return PlayUpdateOutcome.blockedNeedsUpdate;
      }
    }

    // Optional update.
    if (!hasUpdate) return PlayUpdateOutcome.upToDate;
    try {
      // Flexible = background download; we don't await completion. When it's
      // downloaded the caller can prompt to complete, or it applies on next
      // launch. Fire-and-forget is fine for an optional update.
      await InAppUpdate.startFlexibleUpdate();
      return PlayUpdateOutcome.optionalInProgress;
    } catch (_) {
      return PlayUpdateOutcome.upToDate;
    }
  }

  /// Complete a finished flexible (optional) update — installs the downloaded
  /// bytes (the app restarts). Safe to call; no-ops if nothing is staged.
  Future<void> completeFlexibleUpdate() async {
    if (!_supported) return;
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (_) {}
  }
}

/// The result of [PlayUpdateService.run], telling the caller how to gate the UI.
enum PlayUpdateOutcome {
  /// Not an Android/Play context — ignore (e.g. iOS, or a sideloaded build).
  unsupported,

  /// No newer version — proceed into the app.
  upToDate,

  /// An OPTIONAL update is downloading in the background — proceed into the app.
  optionalInProgress,

  /// A forced update completed (the app typically restarts into the new build).
  updated,

  /// A forced update is REQUIRED but did not complete — the caller MUST keep the
  /// app gated (unusable) until the user updates.
  blockedNeedsUpdate,
}
