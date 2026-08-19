import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sawata/app/routes.dart';
import 'package:sawata/data/dummy_data_store.dart';
import 'package:sawata/models/guardian_relationship.dart';
import 'package:sawata/models/user_stats.dart';
import 'package:sawata/services/email/security_event.dart';
import 'package:sawata/services/email_service.dart';
import 'package:sawata/services/guardian_service.dart';
import 'package:sawata/services/user_data_service.dart';
import 'package:sawata/widgets/snackbar_helper.dart';
import '../dashboard/widgets/dashboard_header.dart';
import 'widgets/lock_hero.dart';
import 'widgets/protected_since_card.dart';

/// Bridges to `SawataAccessibilityService` (android/app/.../SawataAccessibilityService.kt).
/// Android never lets an app grant this permission for itself, so the Turn
/// On Protection flow can only ask (`openSettings`) and re-check
/// (`isEnabled`) after the user returns — see `_ensureAccessibilityReady`.
const _accessibilityChannel = MethodChannel('sawata/accessibility');

/// Bridges to `SawataVpnService` (android/app/.../vpn/SawataVpnService.kt).
/// Unlike Accessibility, the VPN *can* be started/stopped by the app once
/// consent is granted — `prepareVPN`/`stopVPN`/`isRunning` are the same
/// methods [WebsiteProtectionScreen] uses for manual control; Turn On/Off
/// Protection drives them directly as part of the master-switch flow (see
/// `_ensureVpnReady` / `_turnOffProtection`) so the user doesn't need a
/// separate trip to that screen.
const _vpnChannel = MethodChannel('sawata/vpn');

class ProtectionScreen extends StatefulWidget {
  const ProtectionScreen({super.key});

  @override
  State<ProtectionScreen> createState() => _ProtectionScreenState();
}

class _ProtectionScreenState extends State<ProtectionScreen>
    with WidgetsBindingObserver {
  // Profile name is still on AppStore pending a separate migration.
  // Guardian relationship data (for security-alert emails) now comes from
  // GuardianService/Firestore — see `_notifyGuardianOfSecurityEvent`.
  // Protection status/stats are live Firestore data via UserDataService.
  final store = AppStore.instance;

  static const _accent = Color(0xFF2E7D6B);
  static const _accentDeep = Color(0xFF16332B);
  static const _mint = Color(0xFFDDEEE7);
  static const _warning = Color(0xFFC98A2E);
  static const _warningBg = Color(0xFFFBEBD6);

  bool _accessibilityEnabled = false;
  bool _vpnRunning = false;

  // True while Turn On/Off Protection is orchestrating the activation or
  // deactivation sequence — guards against double-taps and drives the
  // "SETTING UP PROTECTION" transient UI state.
  bool _activating = false;

  // Lets an in-flight activation `await` the user's return from Android
  // Settings (see `_ensureAccessibilityReady`) instead of guessing with a
  // fixed delay — completed by `didChangeAppLifecycleState` on the next
  // resume, so the flow continues automatically with no second tap.
  Completer<void>? _resumeCompleter;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAccessibilityStatus();
    _refreshVpnStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Unstick anything still awaiting a resume that will now never come —
    // the awaiting code checks `mounted` right after and bails out cleanly.
    if (_resumeCompleter?.isCompleted == false) {
      _resumeCompleter!.complete();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint(
        'Protection: lifecycle resumed, '
        'resumeCompleterPending=${_resumeCompleter != null && _resumeCompleter?.isCompleted == false}',
      );
      _refreshAccessibilityStatus();
      _refreshVpnStatus();
      if (_resumeCompleter?.isCompleted == false) {
        _resumeCompleter!.complete();
      }
    }
  }

  Future<void> _refreshAccessibilityStatus() async {
    bool enabled;
    try {
      enabled =
          await _accessibilityChannel.invokeMethod<bool>('isEnabled') ??
          false;
    } catch (_) {
      enabled = false;
    }
    if (mounted) setState(() => _accessibilityEnabled = enabled);
  }

  Future<void> _openAccessibilitySettings() async {
    try {
      await _accessibilityChannel.invokeMethod('openSettings');
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not open Accessibility Settings.');
      }
    }
  }

  Future<void> _refreshVpnStatus() async {
    bool running;
    try {
      running = await _vpnChannel.invokeMethod<bool>('isRunning') ?? false;
    } catch (_) {
      running = false;
    }
    if (mounted) setState(() => _vpnRunning = running);
  }

  Future<void> _openWebsiteProtection() async {
    await Navigator.of(context).pushNamed(AppRoutes.websiteProtection);
    _refreshVpnStatus();
  }

  /// Orchestrates the whole Turn On Protection sequence: ready-check App
  /// Blocking, ready-check Website Blocking (requesting the system
  /// permission/consent for either one if needed, in order), and only once
  /// BOTH are confirmed actually working does it write
  /// `protectionActive = true` to Firestore — that field is the master
  /// switch the native services gate every block decision on (see
  /// `SawataAccessibilityService.kt` / `DomainBlocklist.kt`), so it must
  /// never be set true on a guess. If the user cancels or denies either
  /// step, activation aborts cleanly and Protection stays off.
  Future<void> _turnOnProtection() async {
    if (_activating) return;
    debugPrint('Protection: TURN ON START');
    setState(() => _activating = true);
    try {
      final accessibilityReady = await _ensureAccessibilityReady();
      debugPrint('Protection: accessibility ready = $accessibilityReady');
      if (!mounted) return;
      if (!accessibilityReady) {
        _showActivationFailedMessage();
        return;
      }

      final vpnReady = await _ensureVpnReady();
      debugPrint('Protection: vpn ready = $vpnReady');
      if (!mounted) return;
      if (!vpnReady) {
        _showActivationFailedMessage();
        return;
      }

      final uid = _uid;
      if (uid == null) return;
      debugPrint('Protection: writing protectionActive=true');
      try {
        await UserDataService.setProtectionActive(uid, true);
        debugPrint('Protection: Firestore write succeeded');
      } catch (e) {
        debugPrint('Protection: Firestore write FAILED: $e');
        if (mounted) _showActivationFailedMessage();
        return;
      }
      if (!mounted) return;
      showAppSnackBar(context, 'Protection is now active', isSuccess: true);
    } finally {
      debugPrint('Protection: clearing activating (finally), mounted=$mounted');
      if (mounted) setState(() => _activating = false);
      debugPrint('Protection: TURN ON END');
    }
  }

  void _showActivationFailedMessage() {
    if (!mounted) return;
    showAppSnackBar(
      context,
      'Protection could not be activated. Please try again.',
      isSuccess: false,
    );
  }

  /// Turns the master switch off: flips `protectionActive` false FIRST (so
  /// the native services stop enforcing global *and* personal blocks the
  /// instant their next Firestore snapshot arrives, regardless of what
  /// happens next), then stops the VPN process itself via the existing
  /// `stopVPN` channel method so it's not left running unnecessarily.
  Future<void> _turnOffProtection() async {
    if (_activating) return;
    setState(() => _activating = true);
    try {
      final uid = _uid;
      if (uid == null) return;
      try {
        await UserDataService.setProtectionActive(uid, false);
      } catch (_) {
        if (mounted) {
          showAppSnackBar(
            context,
            "Couldn't turn off Protection. Please try again.",
            isSuccess: false,
          );
        }
        return;
      }
      _notifyGuardianOfSecurityEvent(SecurityEventType.protectionDisabledManually);

      try {
        await _vpnChannel.invokeMethod('stopVPN');
      } catch (_) {
        // Best-effort — protectionActive=false already stops enforcement
        // natively (see DomainBlocklist.isBlocked) regardless of whether
        // the VPN process itself actually stops.
      }
      if (!mounted) return;
      await _refreshVpnStatus();
      if (!mounted) return;
      showAppSnackBar(context, 'Protection paused', isSuccess: false);
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  /// Step 1 of Turn On Protection. Already granted → returns true with no
  /// user interaction. Otherwise explains why, sends the user to Android's
  /// Accessibility settings, and awaits their return (via
  /// [_waitForResume]) before re-checking — so activation continues
  /// automatically with no second tap. Returns false if the user declines
  /// the explanation dialog or comes back without enabling it.
  Future<bool> _ensureAccessibilityReady() async {
    await _refreshAccessibilityStatus();
    if (!mounted) return false;
    if (_accessibilityEnabled) return true;

    final proceed = await _showEnableAppBlockingDialog();
    if (!proceed || !mounted) return false;

    await _openAccessibilitySettings();
    if (!mounted) return false;
    debugPrint('Protection: waiting for resume after opening Accessibility settings');
    await _waitForResume();
    debugPrint('Protection: resume wait finished (event or timeout)');
    if (!mounted) return false;

    await _refreshAccessibilityStatus();
    return _accessibilityEnabled;
  }

  Future<bool> _showEnableAppBlockingDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable App Blocking'),
        content: const Text(
          'Sawatâ needs App Blocking enabled to prevent access to blocked apps.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Resolves on the next `AppLifecycleState.resumed` — see
  /// `didChangeAppLifecycleState` / `dispose`, both of which complete this.
  /// Bounded by a timeout as a safety net: some OEM multi-window/split-
  /// screen/pop-up-view modes (seen on Samsung tablets) can open Settings
  /// without ever fully pausing the host activity, so `resumed` may never
  /// re-fire. Without this, Turn On Protection would hang on "Setting Up"
  /// forever in that case. A genuine resume shortly after the timeout still
  /// completes the completer harmlessly (guarded by `isCompleted`); either
  /// way, [_ensureAccessibilityReady] does a fresh status check right after
  /// this returns, so a timeout just means "check now" instead of "assume
  /// success."
  Future<void> _waitForResume() {
    final completer = Completer<void>();
    _resumeCompleter = completer;
    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        debugPrint('Protection: resume wait timed out after 60s');
      },
    );
  }

  /// Step 2 of Turn On Protection — also reused standalone as the Website
  /// Blocking row's "Enable" recovery action. Already running → returns
  /// true immediately. Otherwise calls `prepareVPN`, which already shows
  /// Android's VPN consent prompt itself when needed and starts the
  /// service on approval; either way this re-checks the real `isRunning`
  /// state afterward rather than trusting the consent result alone.
  Future<bool> _ensureVpnReady() async {
    await _refreshVpnStatus();
    if (!mounted) return false;
    if (_vpnRunning) return true;
    try {
      await _vpnChannel.invokeMethod<bool>('prepareVPN');
    } catch (_) {
      // Fall through to the fresh isRunning check below either way.
    }
    if (!mounted) return false;
    // MainActivity's already-consented path calls Context.startService()
    // and resolves `prepareVPN` immediately — startService() only
    // schedules SawataVpnService.onStartCommand (where `isRunning` actually
    // flips true), it doesn't run it synchronously. So a single isRunning
    // check right here can legitimately still read stale `false`. This is
    // a short, bounded poll for that specific known-async handoff — not a
    // guess at how long *activation* should take.
    for (var attempt = 0; attempt < 5; attempt++) {
      await _refreshVpnStatus();
      if (_vpnRunning || !mounted) break;
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return false;
    }
    debugPrint('Protection: vpn isRunning after poll = $_vpnRunning');
    return _vpnRunning;
  }

  /// Whether a guardian with [permissions] should be alerted for [event],
  /// based on which alert category the event falls under. Guardians who
  /// have turned off the relevant permission are skipped.
  bool _permissionAllows(GuardianPermissions permissions, SecurityEventType event) {
    switch (event) {
      case SecurityEventType.uninstallAttempt:
      case SecurityEventType.deviceAdminRemoved:
      case SecurityEventType.excessiveFailedPinAttempts:
        return permissions.uninstallAlerts;
      case SecurityEventType.vpnDisabled:
      case SecurityEventType.protectionDisabledManually:
      case SecurityEventType.multipleGamblingAttempts:
        return permissions.blockedAlerts;
      case SecurityEventType.guardianRemoved:
        return true;
    }
  }

  /// Fires a guardian security-alert email for a real event that just
  /// happened in-app, to every connected guardian who has the relevant
  /// alert permission enabled. Reads the live relationship from
  /// [GuardianService] (Firestore) — this is the single source of truth
  /// for "who is this user's guardian", not the old in-memory
  /// `AppStore.guardian`. Silently no-ops if no guardian is connected yet,
  /// or logs (via [EmailService]'s own Firestore logging) if sending fails
  /// — this must never block or crash the UI flow that triggered it.
  Future<void> _notifyGuardianOfSecurityEvent(SecurityEventType event) async {
    final uid = _uid;
    if (uid == null) return;
    final guardians = await GuardianService.fetchGuardians(uid);
    for (final guardian in guardians) {
      if (guardian.email.isEmpty) continue;
      if (!_permissionAllows(guardian.permissions, event)) continue;
      EmailService.sendSecurityAlert(
        toEmail: guardian.email,
        userName: store.profile.name,
        event: event,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<UserStats>(
          stream: uid == null ? null : UserDataService.watchStats(uid),
          builder: (context, statsSnapshot) {
            final stats = statsSnapshot.data ?? UserStats.initial();
            return _buildBody(context, stats);
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, UserStats stats) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = stats.protectionActive;
    // Protection Lock (`active`) is the master switch — while it's off, the
    // native services enforce NOTHING, global or personal (see
    // SawataAccessibilityService.kt / DomainBlocklist.kt). Once activation
    // (_turnOnProtection) has actually confirmed both services are ready,
    // `active` and `fullyReady` should already agree; `setupRequired` is a
    // drift fallback (e.g. the user manually revoked Accessibility, or
    // `protectionActive` synced true from another device) — normal
    // activation never leaves the app in that state on its own.
    final fullyReady = _accessibilityEnabled && _vpnRunning;
    final fullyActive = active && fullyReady;
    final setupRequired = active && !fullyReady;
    // `_activating` is a local, transient flag that can only ever be a
    // best-effort guess about what Turn On/Off Protection is doing — if it
    // ever ends up stale (e.g. the async flow got stuck on some await after
    // the Firestore write it was waiting on already landed), the REAL state
    // — Firestore's `protectionActive` plus live service status — must
    // always win over it. So "activating" only drives the UI when it's not
    // contradicted by an already-confirmed fully-active state.
    final activating = _activating && !fullyActive;
    // A blocking service being off only needs to grab attention when
    // Protection is actually on and depending on it — otherwise it's just
    // an inert, unsurprising status, not a problem to flag.
    final appBlockingNeedsAttention = active && !_accessibilityEnabled;
    final websiteBlockingNeedsAttention = active && !_vpnRunning;

    final String statusTitle;
    final String statusText;
    final Color statusColor;
    if (fullyActive) {
      statusTitle = 'PROTECTION ACTIVE';
      statusText = 'Known gambling apps, websites, and your personal '
          'blocked items are being restricted.';
      statusColor = _accent;
    } else if (activating) {
      statusTitle = 'SETTING UP PROTECTION';
      statusText = 'Preparing app and website protection.';
      statusColor = _accent;
    } else if (setupRequired) {
      statusTitle = 'SETUP REQUIRED';
      statusText = 'Protection is turned on, but it needs the blocking '
          'services below enabled to fully work.';
      statusColor = _warning;
    } else {
      statusTitle = 'AUTOMATIC PROTECTION OFF';
      statusText = 'Known gambling apps, websites, and your personal '
          'blocked items are currently not being restricted.';
      statusColor = colorScheme.onSurfaceVariant;
    }

    final Color buttonBg;
    final Color buttonFg;
    final double buttonElevation;
    if (activating || fullyActive) {
      buttonBg = _mint;
      buttonFg = _accentDeep;
      buttonElevation = 0;
    } else if (setupRequired) {
      buttonBg = _warningBg;
      buttonFg = _warning;
      buttonElevation = 0;
    } else {
      buttonBg = _accentDeep;
      buttonFg = Colors.white;
      buttonElevation = 4;
    }

    final Widget buttonIcon = activating
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: buttonFg,
            ),
          )
        : Icon(
            fullyActive
                ? Icons.verified_user
                : setupRequired
                    ? Icons.warning_amber_rounded
                    : Icons.lock_outline,
          );

    final String buttonLabel = activating
        ? 'Setting Up…'
        : active
            ? 'Turn Off Protection'
            : 'Turn On Protection';

    final VoidCallback? onPressButton = activating
        ? null
        : () => active ? _turnOffProtection() : _turnOnProtection();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        DashboardHeader(
          onBellTap: () => showAppSnackBar(context, "You're all caught up!"),
          onSettingsTap: () =>
              Navigator.of(context).pushNamed(AppRoutes.settings),
        ),
        const SizedBox(height: 18),
        Text(
          'Protection',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Your protection, made simple.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Column(
              children: [
                LockHero(
                  active: active,
                  onTap: activating
                      ? () {}
                      : () => active ? _turnOffProtection() : _turnOnProtection(),
                ),
                const SizedBox(height: 18),
                Text(
                  statusTitle,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  statusText,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: FilledButton.icon(
                    onPressed: onPressButton,
                    style: FilledButton.styleFrom(
                      backgroundColor: buttonBg,
                      foregroundColor: buttonFg,
                      disabledBackgroundColor: buttonBg,
                      disabledForegroundColor: buttonFg,
                      elevation: buttonElevation,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: buttonIcon,
                    label: Text(
                      buttonLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  // Gated on `fullyActive`, not the raw `active` flag — the
                  // Firestore-stored timestamp can be stale/historical (from
                  // a previous activation) while Protection is off, setting
                  // up, or only partially ready, and showing "Protected
                  // Since" during any of those is misleading. The timestamp
                  // itself is left untouched in Firestore either way.
                  child: fullyActive && stats.protectedSince != null
                      ? Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: ProtectedSinceCard(since: stats.protectedSince!),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _BlockingServicesSection(
          appBlockingOn: _accessibilityEnabled,
          appBlockingNeedsAttention: appBlockingNeedsAttention,
          onAppBlockingTap: _openAccessibilitySettings,
          websiteBlockingOn: _vpnRunning,
          websiteBlockingNeedsAttention: websiteBlockingNeedsAttention,
          onWebsiteBlockingTap: _openWebsiteProtection,
          onWebsiteBlockingEnable: _ensureVpnReady,
        ),
        const SizedBox(height: 16),
        _NavRow(
          icon: Icons.shield_outlined,
          title: 'Protection Settings',
          subtitle: 'Customize how Sawatâ protects you.',
          onTap: () =>
              Navigator.of(context).pushNamed(AppRoutes.protectionSettings),
        ),
        _NavRow(
          icon: Icons.apps_outlined,
          title: 'Blocked Sites & Apps',
          subtitle: 'Choose additional apps or websites to block while Protection is active.',
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.blockedSites),
        ),
      ],
    );
  }
}

/// The two Android mechanisms Turn On/Off Protection orchestrates. App
/// Blocking (Accessibility) is a permission Sawatâ can never fully control
/// — Android won't let an app grant or revoke it — so it's shown as
/// "Ready"/"Setup needed" rather than "On"/"Off", to avoid implying Sawatâ
/// is actively blocking apps just because the permission happens to be
/// granted while Protection itself is off. Website Blocking (the VPN) *is*
/// something Sawatâ starts/stops directly, so it gets a real "On"/"Off".
/// Either row's status only turns amber (needs attention) when Protection
/// is on and depending on it; otherwise it's a neutral, unsurprising status.
/// Normally the user never needs these rows at all — Turn On Protection
/// handles both automatically; they exist as status visibility plus a
/// recovery control if something drifts out of sync.
class _BlockingServicesSection extends StatelessWidget {
  const _BlockingServicesSection({
    required this.appBlockingOn,
    required this.appBlockingNeedsAttention,
    required this.onAppBlockingTap,
    required this.websiteBlockingOn,
    required this.websiteBlockingNeedsAttention,
    required this.onWebsiteBlockingTap,
    required this.onWebsiteBlockingEnable,
  });

  final bool appBlockingOn;
  final bool appBlockingNeedsAttention;
  final VoidCallback onAppBlockingTap;

  final bool websiteBlockingOn;
  final bool websiteBlockingNeedsAttention;
  final VoidCallback onWebsiteBlockingTap;
  final VoidCallback onWebsiteBlockingEnable;

  static const _accent = Color(0xFF2E7D6B);
  static const _warning = Color(0xFFC98A2E);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Blocking Services',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            _row(
              context,
              title: 'App Blocking',
              subtitle: appBlockingOn
                  ? 'Ready to block apps when Protection is active.'
                  : 'Required before Protection can block apps.',
              onLabel: 'Ready',
              offLabel: 'Setup needed',
              on: appBlockingOn,
              needsAttention: appBlockingNeedsAttention,
              onTap: onAppBlockingTap,
              onEnable: onAppBlockingTap,
              topBorder: false,
            ),
            _row(
              context,
              title: 'Website Blocking',
              subtitle: 'Starts automatically when Protection turns on.',
              onLabel: 'On',
              offLabel: 'Off',
              on: websiteBlockingOn,
              needsAttention: websiteBlockingNeedsAttention,
              onTap: onWebsiteBlockingTap,
              onEnable: onWebsiteBlockingEnable,
              topBorder: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String onLabel,
    required String offLabel,
    required bool on,
    required bool needsAttention,
    required VoidCallback onTap,
    required VoidCallback onEnable,
    required bool topBorder,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = on
        ? _accent
        : needsAttention
            ? _warning
            : colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: topBorder
              ? Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              on ? onLabel : offLabel,
              style: TextStyle(fontWeight: FontWeight.w700, color: statusColor),
            ),
            if (!on) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                height: 34,
                child: OutlinedButton(
                  onPressed: onEnable,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text('Enable'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  static const _mint = Color(0xFFDDEEE7);
  static const _accent = Color(0xFF2E7D6B);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: _mint,
          foregroundColor: _accent,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
