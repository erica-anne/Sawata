import 'package:flutter/services.dart';

import '../models/installed_app.dart';

/// Thrown when the platform side couldn't enumerate installed apps (rare —
/// e.g. a PackageManager failure). Callers should catch this and show a
/// friendly message rather than the raw platform exception.
class InstalledAppsException implements Exception {
  const InstalledAppsException(this.message);
  final String message;
}

/// Bridges to `InstalledAppsProvider.kt` (android/app/.../InstalledAppsProvider.kt)
/// via `MainActivity.kt`'s `sawata/apps` channel — lists normal,
/// user-launchable installed apps for the "Choose an App" picker in
/// Blocked Sites & Apps, so a user never has to type an Android package
/// name themselves.
class InstalledAppsService {
  InstalledAppsService._();

  static const _channel = MethodChannel('sawata/apps');

  static Future<List<InstalledApp>> list() async {
    final List<Object?> raw;
    try {
      raw = await _channel.invokeMethod<List<Object?>>('getInstalledApps') ?? const [];
    } on PlatformException {
      throw const InstalledAppsException("Couldn't read installed apps on this device.");
    } on MissingPluginException {
      throw const InstalledAppsException('Installed-app lookup is not available.');
    }

    return raw
        .whereType<Map<Object?, Object?>>()
        .map(
          (entry) => InstalledApp(
            name: entry['name'] as String? ?? '',
            packageName: entry['packageName'] as String? ?? '',
            icon: entry['icon'] as Uint8List?,
          ),
        )
        .where((app) => app.packageName.isNotEmpty)
        .toList();
  }
}
