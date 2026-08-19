import '../../app/app_config.dart';
import 'security_event.dart';

/// Builds responsive, dark-mode-aware HTML emails for Sawatâ.
///
/// All templates share [_wrap] for consistent branding (logo mark, footer,
/// support email placeholder) and are plain inline-styled HTML tables/divs
/// for maximum email-client compatibility (no external CSS/JS).
class EmailTemplates {
  EmailTemplates._();

  static const String _brandGreen = '#2E7D6B';
  static const String _deepTeal = '#16332B';
  static const String _mintBg = '#DDEEE7';

  static String _wrap({required String title, required String bodyHtml}) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>$title</title>
<meta name="color-scheme" content="light dark" />
<meta name="supported-color-schemes" content="light dark" />
<style>
  body { margin:0; padding:0; background-color:#F4FAF7; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; }
  @media (prefers-color-scheme: dark) {
    body, .bg { background-color:#0F1F1A !important; }
    .card { background-color:#16332B !important; }
    .text-main { color:#EAF3EF !important; }
    .text-muted { color:#9DB6AC !important; }
  }
  a.btn:hover { opacity:0.9; }
</style>
</head>
<body class="bg" style="margin:0;padding:0;background-color:#F4FAF7;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="padding:24px 0;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" style="max-width:560px;" cellpadding="0" cellspacing="0">
          <tr>
            <td align="center" style="padding-bottom:20px;">
              <span style="font-size:22px;font-weight:800;color:$_deepTeal;letter-spacing:0.5px;">🛡️ Sawatâ</span>
            </td>
          </tr>
          <tr>
            <td class="card" style="background:#FFFFFF;border-radius:18px;padding:32px 28px;box-shadow:0 4px 16px rgba(0,0,0,0.06);">
              $bodyHtml
            </td>
          </tr>
          <tr>
            <td align="center" style="padding-top:22px;">
              <p class="text-muted" style="margin:0;font-size:12px;color:#5B7269;line-height:1.6;">
                You're receiving this because you're connected to a Sawatâ account.<br/>
                Need help? Contact us at <a href="mailto:${AppConfig.supportEmail}" style="color:$_brandGreen;">${AppConfig.supportEmail}</a>
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }

  static String _heading(String text) =>
      '<h1 class="text-main" style="margin:0 0 12px;font-size:20px;font-weight:800;color:$_deepTeal;">$text</h1>';

  static String _paragraph(String text) =>
      '<p class="text-muted" style="margin:0 0 12px;font-size:14px;line-height:1.6;color:#5B7269;">$text</p>';

  static String _infoRow(String label, String value) => '''
<tr>
  <td style="padding:6px 0;font-size:13px;color:#5B7269;">$label</td>
  <td style="padding:6px 0;font-size:13px;font-weight:700;color:$_deepTeal;text-align:right;">$value</td>
</tr>
''';

  static String _infoCard(List<String> rows) => '''
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:$_mintBg;border-radius:14px;padding:14px 16px;margin:16px 0;">
  ${rows.join()}
</table>
''';

  // ---------------------------------------------------------------------
  // NOTE: there is intentionally no "Guardian Invitation" template here —
  // that email is now sent via EmailJS (see
  // lib/services/email/emailjs_provider.dart), which renders its own
  // `template_gap8skh` dashboard template from named variables instead of
  // an HTML string built here.
  // ---------------------------------------------------------------------

  // ---------------------------------------------------------------------
  // Guardian Accepted
  // ---------------------------------------------------------------------
  static String guardianAccepted({
    required String toName,
    required String guardianName,
    required DateTime acceptedAt,
  }) {
    final body =
        _heading('$guardianName accepted your invitation! 🎉') +
        _paragraph(
          'Great news, $toName — $guardianName is now your guardian on '
          'Sawatâ and will be notified of important security events on your '
          'recovery journey.',
        ) +
        _infoCard([
          _infoRow('Guardian', guardianName),
          _infoRow('Accepted on', _formatDateTime(acceptedAt)),
        ]) +
        _paragraph('Keep going — you\'ve got support behind you now.');
    return _wrap(title: 'Guardian Accepted', bodyHtml: body);
  }

  // ---------------------------------------------------------------------
  // Guardian Rejected
  // ---------------------------------------------------------------------
  static String guardianRejected({
    required String toName,
    required String guardianName,
  }) {
    final body =
        _heading('Invitation declined') +
        _paragraph(
          '$guardianName declined your guardian invitation on Sawatâ. You '
          'can send a new invitation to someone else from the Add Guardian '
          'screen whenever you\'re ready.',
        );
    return _wrap(title: 'Guardian Invitation Declined', bodyHtml: body);
  }

  // ---------------------------------------------------------------------
  // NOTE: there is intentionally no custom "verification" template here.
  // Email verification is handled by Firebase Authentication's built-in
  // `User.sendEmailVerification()` (see lib/services/auth_email_service.dart),
  // which generates and validates its own secure link — something a
  // client-only Resend integration can't safely replicate without a
  // backend to issue/verify tokens.
  // ---------------------------------------------------------------------

  // ---------------------------------------------------------------------
  // Password Reset — OPTIONAL security notification only. The actual
  // reset link is sent by Firebase Auth's `sendPasswordResetEmail()` (see
  // lib/services/auth_email_service.dart); this is just a heads-up email
  // in case the request wasn't the account owner.
  // ---------------------------------------------------------------------
  static String passwordResetAlert({
    required String toName,
    required DateTime requestedAt,
    String? device,
    String? ipAddress,
  }) {
    final body =
        _heading('Password reset requested') +
        _paragraph(
          'Hi $toName, a password reset was just requested for your Sawatâ '
          'account.',
        ) +
        _infoCard([
          _infoRow('Date', _formatDate(requestedAt)),
          _infoRow('Time', _formatTime(requestedAt)),
          _infoRow('Device', device ?? 'Unknown'),
          _infoRow('IP Address', ipAddress ?? 'Unknown'),
        ]) +
        _paragraph(
          '<strong>This wasn\'t me?</strong> Secure your account immediately '
          'by changing your password and contact support at '
          '${AppConfig.supportEmail}.',
        );
    return _wrap(title: 'Password Reset Requested', bodyHtml: body);
  }

  // ---------------------------------------------------------------------
  // Security Alert (to Guardian)
  // ---------------------------------------------------------------------
  static String securityAlert({
    required String userName,
    required SecurityEventType event,
    required DateTime timestamp,
    String? deviceName,
  }) {
    final info = securityEventCatalog[event]!;
    final severityColor = switch (info.severity) {
      SecuritySeverity.low => '#5B7269',
      SecuritySeverity.medium => '#C98A2E',
      SecuritySeverity.high => '#D9622B',
      SecuritySeverity.critical => '#C0392B',
    };
    final severityLabel = info.severity.name.toUpperCase();
    final body =
        _heading('⚠️ Security Alert: ${info.label}') +
        _paragraph(
          'This is an automated alert about $userName\'s Sawatâ protection.',
        ) +
        _infoCard([
          _infoRow('User', userName),
          _infoRow('Event', info.label),
          _infoRow('Timestamp', _formatDateTime(timestamp)),
          _infoRow('Device', deviceName ?? 'Unknown'),
          _infoRow(
            'Severity',
            '<span style="color:$severityColor;">$severityLabel</span>',
          ),
        ]) +
        _heading('Recommended Action') +
        _paragraph(info.recommendedAction);
    return _wrap(title: 'Sawatâ Security Alert', bodyHtml: body);
  }

  // ---------------------------------------------------------------------
  // Weekly Recovery Report (to Guardian)
  // ---------------------------------------------------------------------
  static String weeklyGuardianReport({
    required String guardianName,
    required String userName,
    required int streakDays,
    required int blockedAttempts,
    required double protectionUptimePct,
  }) {
    final body =
        _heading('$userName\'s Weekly Recovery Report') +
        _paragraph(
          'Hi $guardianName, here\'s a quick summary of $userName\'s '
          'progress this week.',
        ) +
        _infoCard([
          _infoRow('Current Streak', '$streakDays days'),
          _infoRow('Blocked Attempts', '$blockedAttempts'),
          _infoRow(
            'Protection Uptime',
            '${protectionUptimePct.toStringAsFixed(0)}%',
          ),
        ]) +
        _paragraph(
          '$userName is showing real commitment to their recovery. Your '
          'support makes a difference — consider sending a quick note of '
          'encouragement today. 💚',
        );
    return _wrap(title: 'Weekly Recovery Report', bodyHtml: body);
  }

  static String _formatDate(DateTime d) =>
      '${_month(d.month)} ${d.day}, ${d.year}';
  static String _formatTime(DateTime d) {
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $ampm';
  }

  static String _formatDateTime(DateTime d) =>
      '${_formatDate(d)} at ${_formatTime(d)}';

  static String _month(int m) => const [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ][m - 1];
}
