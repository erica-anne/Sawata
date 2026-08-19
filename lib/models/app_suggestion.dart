/// A gambling-app suggestion written by `SawataAccessibilityService`
/// (native Kotlin) when a newly opened, not-yet-blocked app matches the
/// `app_config/gambling_keywords` list. Shown in `BlockedSitesScreen` for
/// the user to confirm (block it) or dismiss.
class AppSuggestion {
  AppSuggestion({required this.packageName, required this.name});

  final String packageName;
  final String name;
}
