import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app/app_config.dart';
import '../app/routes.dart';

/// Handles the `sawata://guardian-invites` deep link sent as the
/// `invite_link` EmailJS variable — see the intent-filter on
/// `MainActivity` in AndroidManifest.xml for the Android side.
///
/// This is deliberately generic and NOT invitation-specific: the email no
/// longer references a particular `invites/{id}` doc at all (guardians
/// already have a dedicated in-app screen — [GuardianInvitesScreen] — for
/// reviewing and explicitly Accepting/Rejecting pending requests). This
/// service's only job is getting the guardian to that screen; it never
/// reads Firestore and never accepts or rejects anything itself.
///
/// Also a custom URI scheme, NOT a verified Android App Link — see the
/// AndroidManifest.xml comment on the intent-filter for what that means.
class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  /// Call once, early in `main()`. `uriLinkStream` delivers the very first
  /// link (cold launch) as its first event, then every subsequent one
  /// while the app is running — no separate cold-start check needed.
  void initialize() {
    _subscription = _appLinks.uriLinkStream.listen(
      _handle,
      onError: (Object e) => debugPrint('[DeepLinkService] stream error: $e'),
    );
  }

  void dispose() {
    _subscription?.cancel();
  }

  Future<void> _handle(Uri uri) async {
    debugPrint('[DeepLinkService] received: $uri');
    if (uri.scheme != AppConfig.guardianInvitesScheme ||
        uri.host != AppConfig.guardianInvitesHost) {
      return;
    }

    final navigator = await _waitForNavigator();
    if (navigator == null) return;

    final destination = FirebaseAuth.instance.currentUser == null
        ? AppRoutes.login
        : AppRoutes.guardianInvites;
    // pushNamedAndRemoveUntil (not pushNamed) so this also wins any race
    // against SplashScreen's own unconditional 2s "go to onboarding" timer
    // on a cold launch — clearing the stack disposes SplashScreen's State,
    // and its `if (!mounted) return` guard then skips that stale redirect.
    //
    // If not signed in, the guardian just lands on the normal Login screen
    // — after logging in they reach Guardian Invites the ordinary way (via
    // nav), same as anyone else. There's no invite-specific state to
    // resume, so no special post-login handling is needed here.
    navigator.pushNamedAndRemoveUntil(destination, (route) => false);
  }

  /// The link can arrive before the first frame has attached the root
  /// [Navigator] (cold launch racing app startup). Polls briefly rather
  /// than silently dropping the link.
  Future<NavigatorState?> _waitForNavigator() async {
    for (var i = 0; i < 20; i++) {
      final state = AppRoutes.navigatorKey.currentState;
      if (state != null) return state;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    debugPrint('[DeepLinkService] navigator never became ready; dropping link.');
    return null;
  }
}
