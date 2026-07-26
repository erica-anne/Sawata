import 'package:flutter/material.dart';

import '../screens/guardian/guardian_alerts_screen.dart';
import '../screens/guardian/guardian_dashboard_screen.dart';
import '../screens/guardian/guardian_invites_screen.dart';
import '../screens/guardian/guardian_reports_screen.dart';
import '../screens/guardian/guardian_settings_screen.dart';
import '../screens/user/auth/login_screen.dart';
import '../screens/user/auth/register_screen.dart';
import '../screens/user/guardian_contact/guardian_contact_screen.dart';
import '../screens/user/guardian_onboarding/add_guardian_screen.dart';
import '../screens/user/onboarding/onboarding_screen.dart';
import '../screens/user/settings/settings_screen.dart';
import '../screens/user/splash/splash_screen.dart';
import 'app_shell.dart';

class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const settings = '/settings';

  /// The user's own "manage my guardian contact" screen — part of the User
  /// app, not the Guardian app itself.
  static const guardianContact = '/guardian-contact';

  /// The User-side "Add a Guardian" wizard.
  static const addGuardian = '/add-guardian';

  /// The real Guardian-side monitoring dashboard, reached via the Guardian
  /// Login mode on the login screen.
  static const guardianDashboard = '/guardian-dashboard';

  /// The Guardian-side alerts feed.
  static const guardianAlerts = '/guardian-alerts';

  /// The Guardian-side invites (Request / Accepted) screen.
  static const guardianInvites = '/guardian-invites';

  /// The Guardian-side recovery reports screen.
  static const guardianReports = '/guardian-reports';

  /// The Guardian-side settings screen.
  static const guardianSettings = '/guardian-settings';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const AppShell());
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case guardianContact:
        return MaterialPageRoute(builder: (_) => const GuardianContactScreen());
      case addGuardian:
        return MaterialPageRoute(builder: (_) => const AddGuardianScreen());
      case guardianDashboard:
        return MaterialPageRoute(
          builder: (_) => const GuardianDashboardScreen(),
        );
      case guardianAlerts:
        return MaterialPageRoute(builder: (_) => const GuardianAlertsScreen());
      case guardianInvites:
        return MaterialPageRoute(builder: (_) => const GuardianInvitesScreen());
      case guardianReports:
        return MaterialPageRoute(builder: (_) => const GuardianReportsScreen());
      case guardianSettings:
        return MaterialPageRoute(
          builder: (_) => const GuardianSettingsScreen(),
        );
      default:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
    }
  }
}
