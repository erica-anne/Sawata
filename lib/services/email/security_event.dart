/// Security events that can trigger a guardian alert email.
///
/// NOTE ON WIRING STATUS: only [multipleGamblingAttempts] (via
/// `AppStore.simulateBlockAttempt` / the Protection screen's "Simulate
/// attempt") and [protectionDisabledManually] (via the Protection screen's
/// status toggle) are currently triggered by real app code. The others
/// ([uninstallAttempt], [vpnDisabled], [deviceAdminRemoved],
/// [excessiveFailedPinAttempts], [guardianRemoved]) have no corresponding
/// detection logic yet (no PIN screen, no uninstall/device-admin listener,
/// no real VPN-disabled callback) — call [EmailService.sendSecurityAlert]
/// with these once that native detection exists.
enum SecurityEventType {
  uninstallAttempt,
  vpnDisabled,
  deviceAdminRemoved,
  protectionDisabledManually,
  multipleGamblingAttempts,
  excessiveFailedPinAttempts,
  guardianRemoved,
}

enum SecuritySeverity { low, medium, high, critical }

class SecurityEventInfo {
  const SecurityEventInfo({
    required this.label,
    required this.severity,
    required this.recommendedAction,
  });

  final String label;
  final SecuritySeverity severity;
  final String recommendedAction;
}

const Map<SecurityEventType, SecurityEventInfo> securityEventCatalog = {
  SecurityEventType.uninstallAttempt: SecurityEventInfo(
    label: 'Attempted to Uninstall Sawatâ',
    severity: SecuritySeverity.critical,
    recommendedAction:
        'Reach out to your loved one now. Repeated uninstall attempts often '
        'signal an urge to gamble.',
  ),
  SecurityEventType.vpnDisabled: SecurityEventInfo(
    label: 'Website Protection (VPN) Disabled',
    severity: SecuritySeverity.high,
    recommendedAction:
        'Website blocking is currently off. Check in and encourage them to '
        're-enable protection in the app.',
  ),
  SecurityEventType.deviceAdminRemoved: SecurityEventInfo(
    label: 'Device Administrator Permission Removed',
    severity: SecuritySeverity.critical,
    recommendedAction:
        'App-blocking protection may no longer be enforced. Ask them to '
        're-grant the permission in Settings.',
  ),
  SecurityEventType.protectionDisabledManually: SecurityEventInfo(
    label: 'Protection Manually Turned Off',
    severity: SecuritySeverity.medium,
    recommendedAction:
        'Protection was turned off from within the app. A quick check-in '
        'goes a long way.',
  ),
  SecurityEventType.multipleGamblingAttempts: SecurityEventInfo(
    label: 'Multiple Gambling Access Attempts Detected',
    severity: SecuritySeverity.high,
    recommendedAction:
        'Several blocked attempts in a short window can indicate a strong '
        'urge. Consider reaching out today.',
  ),
  SecurityEventType.excessiveFailedPinAttempts: SecurityEventInfo(
    label: 'Excessive Failed PIN Attempts',
    severity: SecuritySeverity.medium,
    recommendedAction:
        'Repeated failed PIN attempts may mean someone is trying to change '
        'protection settings without authorization.',
  ),
  SecurityEventType.guardianRemoved: SecurityEventInfo(
    label: 'Guardian Relationship Removed',
    severity: SecuritySeverity.high,
    recommendedAction:
        'You are no longer a connected guardian for this user. If this was '
        'unexpected, reach out to them directly.',
  ),
};
