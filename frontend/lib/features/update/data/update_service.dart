import 'package:package_info_plus/package_info_plus.dart';

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

  Future<UpdateInfo> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;

      final json = await ApiClient.instance.get('/app-version')
          as Map<String, dynamic>;
      final latest = (json['latest_version'] as num?)?.toInt() ?? 0;
      final minSupported =
          (json['min_supported_version'] as num?)?.toInt() ?? 0;
      final apkUrl = (json['apk_url'] as String?) ?? '';

      // No download URL configured → never prompt (nothing to send them to).
      final available = latest > current && apkUrl.isNotEmpty;
      final forced = available && current < minSupported;

      return UpdateInfo(
        available: available,
        forced: forced,
        latestVersion: latest,
        currentVersion: current,
        apkUrl: apkUrl,
        notes: (json['notes'] as String?) ?? '',
      );
    } catch (_) {
      // Never block the app on a failed/absent version check.
      return UpdateInfo.none;
    }
  }
}
