import 'dart:typed_data';

/// One entry from the device's installed-apps picker — see
/// [InstalledAppsService] (lib/services/installed_apps_service.dart).
class InstalledApp {
  const InstalledApp({required this.name, required this.packageName, this.icon});

  final String name;
  final String packageName;

  /// Small PNG, best-effort — null if the OS couldn't resolve an icon for
  /// this app. Never persisted; only used to render the picker.
  final Uint8List? icon;
}
