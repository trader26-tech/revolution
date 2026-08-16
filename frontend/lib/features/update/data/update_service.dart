import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';

/// The result of an update check.
class UpdateInfo {
  const UpdateInfo({
    required this.available,
    required this.forced,
    required this.latestVersion,
    required this.currentVersion,
    required this.apkUrl,
    required this.notes,
  });

  /// A newer build exists.
  final bool available;

  /// The installed build is below the server's min-supported → must update.
  final bool forced;

  final int latestVersion;
  final int currentVersion;
  final String apkUrl;
  final String notes;

  static const none = UpdateInfo(
    available: false,
    forced: false,
    latestVersion: 0,
    currentVersion: 0,
    apkUrl: '',
    notes: '',
  );
}

/// Checks the backend's `/app-version` against the installed build number.
///
/// The app is sideloaded (direct APK), so "update" means downloading a newer
/// APK — [UpdateInfo.apkUrl] is where the Update button sends the user.
class UpdateService {
  const UpdateService._();
  static const instance = UpdateService._();

  // Cached from the LAST successful check, so a mandatory update keeps blocking
  // even when the device later goes offline — it can't "escape" the requirement
  // by turning off the network. Cleared once the installed build catches up.
  static const _kForcedApkUrl = 'update_forced_apk_url';
  static const _kForcedMin = 'update_forced_min_version';
  static const _kForcedNotes = 'update_forced_notes';

  Future<UpdateInfo> check() async {
    final info = await PackageInfo.fromPlatform();
    final current = int.tryParse(info.buildNumber) ?? 0;
    final prefs = await SharedPreferences.getInstance();

    try {
      final json = await ApiClient.instance.get('/app-version')
          as Map<String, dynamic>;
      final latest = (json['latest_version'] as num?)?.toInt() ?? 0;
      final minSupported =
          (json['min_supported_version'] as num?)?.toInt() ?? 0;
      final apkUrl = (json['apk_url'] as String?) ?? '';
      final notes = (json['notes'] as String?) ?? '';

      // No download URL configured → never prompt (nothing to send them to).
      final available = latest > current && apkUrl.isNotEmpty;
      final forced = available && current < minSupported;

      // Persist the forced requirement so it survives going offline. Clear it
      // once this build is at/above min-supported (i.e. after they've updated).
      if (forced) {
        await prefs.setString(_kForcedApkUrl, apkUrl);
        await prefs.setInt(_kForcedMin, minSupported);
        await prefs.setString(_kForcedNotes, notes);
      } else if (current >= minSupported) {
        await prefs.remove(_kForcedApkUrl);
        await prefs.remove(_kForcedMin);
        await prefs.remove(_kForcedNotes);
      }

      return UpdateInfo(
        available: available,
        forced: forced,
        latestVersion: latest,
        currentVersion: current,
        apkUrl: apkUrl,
        notes: notes,
      );
    } catch (_) {
      // Offline / server down: fall back to the LAST-KNOWN forced requirement,
      // so a device told to update can't dodge it by disconnecting.
      final cachedMin = prefs.getInt(_kForcedMin) ?? 0;
      final cachedUrl = prefs.getString(_kForcedApkUrl) ?? '';
      if (cachedUrl.isNotEmpty && current < cachedMin) {
        return UpdateInfo(
          available: true,
          forced: true,
          latestVersion: cachedMin,
          currentVersion: current,
          apkUrl: cachedUrl,
          notes: prefs.getString(_kForcedNotes) ?? '',
        );
      }
      // No cached requirement → never block the app on a failed check.
      return UpdateInfo.none;
    }
  }

  /// Download the new APK from [apkUrl] and hand it to Android's package
  /// installer — a real in-app update (no browser detour). [onProgress] reports
  /// 0→1 as bytes arrive (null total → indeterminate, reported as null).
  ///
  /// Returns an [InstallResult]: [InstallResult.launched] means the OS install
  /// screen opened (the user still taps "Install" — Android always requires that
  /// final confirmation; the app cannot silently replace itself). Anything else
  /// is a failure the caller should surface (with the browser link as a
  /// fallback).
  Future<InstallResult> downloadAndInstall(
    String apkUrl, {
    void Function(double? progress)? onProgress,
  }) async {
    if (apkUrl.isEmpty) return InstallResult.failed;
    http.Client? client;
    try {
      client = http.Client();
      final req = http.Request('GET', Uri.parse(apkUrl));
      final res = await client.send(req).timeout(const Duration(minutes: 5));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return InstallResult.failed;
      }

      final total = res.contentLength; // may be null
      final bytes = <int>[];
      var received = 0;
      onProgress?.call(total == null ? null : 0);
      await for (final chunk in res.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (total != null && total > 0) {
          onProgress?.call((received / total).clamp(0.0, 1.0));
        }
      }

      // Save to a private temp file we can hand to the installer. A stable name
      // (overwritten each time) so repeated updates don't pile up files.
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/remora-update.apk');
      await file.writeAsBytes(bytes, flush: true);

      // Hand the APK to the OS. open_filex opens it with the package installer,
      // which shows Android's own install confirmation screen.
      final opened = await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );
      return opened.type == ResultType.done
          ? InstallResult.launched
          : InstallResult.failed;
    } catch (_) {
      return InstallResult.failed;
    } finally {
      client?.close();
    }
  }
}

/// The outcome of [UpdateService.downloadAndInstall].
enum InstallResult {
  /// The APK downloaded and Android's install screen opened (user confirms).
  launched,

  /// Download or hand-off failed — fall back to opening the link in a browser.
  failed,
}
