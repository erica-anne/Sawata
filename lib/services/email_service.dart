import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'email/email_config.dart';
import 'email/email_provider.dart';
import 'email/emailjs_provider.dart';
import 'email/email_templates.dart';
import 'email/rate_limiter.dart';
import 'email/retry_policy.dart';
import 'email/security_event.dart';

export 'email/email_provider.dart' show EmailErrorCode, EmailResult;

/// Orchestrates outbound email: validation, rate limiting, retry, and
/// Firestore logging. This class never talks HTTP directly — actual
/// delivery is delegated to a provider, so callers (UI code) never need to
/// know or care about transport details.
///
/// The Guardian Invitation email ([sendGuardianInvite]) always goes through
/// [EmailJsProvider] (EmailJS, using the `template_gap8skh` dashboard
/// template) — it is not affected by [EmailConfig.transport]. Every other
/// email type below still goes through whichever [EmailProvider]
/// `EmailConfig.transport` selects (see
/// lib/services/email/email_config.dart) — currently the dev-only
/// client-side Resend integration.
class EmailService {
  EmailService._();

  static final EmailProvider _provider = EmailConfig.buildProvider();
  static const RateLimiter _rateLimiter = RateLimiter();
  static const RetryPolicy _retryPolicy = RetryPolicy();

  static const _emailPattern = r'^[^@\s]+@[^@\s]+\.[^@\s]+$';

  // ---------------------------------------------------------------------
  // Public API — one method per email type required by the spec.
  // ---------------------------------------------------------------------

  /// Sends the Guardian Invitation notification email via EmailJS.
  /// [appLink] is the generic `sawata://guardian-invites` deep link (see
  /// [AppConfig]) — not invitation-specific, since the guardian reviews
  /// and Accepts/Rejects the request inside the app, not via the email.
  static Future<EmailResult> sendGuardianInvite({
    required String toEmail,
    required String guardianName,
    required String userName,
    required String appLink,
  }) {
    return _sendViaProvider(
      type: 'guardian_invite',
      toEmail: toEmail,
      send: () => EmailJsProvider.sendGuardianInvite(
        toEmail: toEmail,
        guardianName: guardianName,
        userName: userName,
        appLink: appLink,
      ),
    );
  }

  static Future<EmailResult> sendGuardianAccepted({
    required String toEmail,
    required String toName,
    required String guardianName,
    DateTime? acceptedAt,
  }) {
    return _send(
      type: 'guardian_accepted',
      toEmail: toEmail,
      subject: '$guardianName accepted your Guardian invitation',
      html: EmailTemplates.guardianAccepted(
        toName: toName,
        guardianName: guardianName,
        acceptedAt: acceptedAt ?? DateTime.now(),
      ),
    );
  }

  static Future<EmailResult> sendGuardianRejected({
    required String toEmail,
    required String toName,
    required String guardianName,
  }) {
    return _send(
      type: 'guardian_rejected',
      toEmail: toEmail,
      subject: 'Your Sawatâ Guardian invitation was declined',
      html: EmailTemplates.guardianRejected(
        toName: toName,
        guardianName: guardianName,
      ),
    );
  }

  // NOTE: no sendVerificationEmail() — use AuthEmailService.sendEmailVerification()
  // (Firebase Auth's built-in verification flow), not this service.

  /// OPTIONAL security notification only — NOT the password-reset link
  /// itself. Send that via `AuthEmailService.sendPasswordResetEmail()`
  /// (Firebase Auth's built-in flow). Call this alongside it if you want
  /// an additional "was this you?" heads-up email.
  static Future<EmailResult> sendPasswordResetAlert({
    required String toEmail,
    required String toName,
    DateTime? requestedAt,
    String? ipAddress,
  }) {
    return _send(
      type: 'password_reset_alert',
      toEmail: toEmail,
      subject: 'Password reset requested for your Sawatâ account',
      html: EmailTemplates.passwordResetAlert(
        toName: toName,
        requestedAt: requestedAt ?? DateTime.now(),
        device: _currentDeviceLabel(),
        ipAddress: ipAddress,
      ),
    );
  }

  /// Notifies a guardian of a security event for the user they're
  /// connected to. See [SecurityEventType] for wiring status of each event.
  static Future<EmailResult> sendSecurityAlert({
    required String toEmail,
    required String userName,
    required SecurityEventType event,
    DateTime? timestamp,
    String? deviceName,
  }) {
    return _send(
      type: 'security_alert_${event.name}',
      toEmail: toEmail,
      subject:
          '⚠️ Security Alert: ${securityEventCatalog[event]!.label}',
      html: EmailTemplates.securityAlert(
        userName: userName,
        event: event,
        timestamp: timestamp ?? DateTime.now(),
        deviceName: deviceName ?? _currentDeviceLabel(),
      ),
    );
  }

  static Future<EmailResult> sendWeeklyGuardianReport({
    required String toEmail,
    required String guardianName,
    required String userName,
    required int streakDays,
    required int blockedAttempts,
    required double protectionUptimePct,
  }) {
    return _send(
      type: 'weekly_guardian_report',
      toEmail: toEmail,
      subject: "$userName's Weekly Recovery Report",
      html: EmailTemplates.weeklyGuardianReport(
        guardianName: guardianName,
        userName: userName,
        streakDays: streakDays,
        blockedAttempts: blockedAttempts,
        protectionUptimePct: protectionUptimePct,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Internals: validation, rate limiting, retry (delegated to
  // [_retryPolicy]), provider dispatch (delegated to [_provider]), and
  // Firestore logging. No transport-specific code lives here.
  // ---------------------------------------------------------------------

  static Future<EmailResult> _send({
    required String type,
    required String toEmail,
    required String subject,
    required String html,
  }) {
    return _sendViaProvider(
      type: type,
      toEmail: toEmail,
      send: () => _provider.send(toEmail: toEmail, subject: subject, html: html),
    );
  }

  /// Shared pipeline behind every `send*` method above: recipient
  /// validation, rate limiting, retry (delegated to [_retryPolicy]), and
  /// Firestore logging. [send] performs exactly one provider-specific send
  /// attempt (e.g. [EmailProvider.send] for the Resend-backed types, or
  /// [EmailJsProvider.sendGuardianInvite] for the guardian invite) — no
  /// transport-specific code lives here.
  static Future<EmailResult> _sendViaProvider({
    required String type,
    required String toEmail,
    required Future<EmailResult> Function() send,
  }) async {
    if (!RegExp(_emailPattern).hasMatch(toEmail)) {
      debugPrint(
        '[EmailService] send($type) aborted: invalid recipient address '
        '"$toEmail".',
      );
      return EmailResult.failure(
        EmailErrorCode.invalidRecipient,
        'Invalid recipient email address: $toEmail',
      );
    }

    final recentTimestamps = await _fetchRecentSendTimestamps(
      type: type,
      toEmail: toEmail,
    );
    if (_rateLimiter.isLimited(recentTimestamps, DateTime.now())) {
      const result = EmailResult.failure(
        EmailErrorCode.rateLimited,
        'Rate limit exceeded for this recipient and email type.',
      );
      debugPrint('[EmailService] send($type) rate-limited for $toEmail.');
      await _logEmail(
        type: type,
        toEmail: toEmail,
        status: 'rate_limited',
        retries: 0,
        errorMessage: result.errorMessage,
      );
      return result;
    }

    var attempts = 0;
    final result = await _retryPolicy.execute(() {
      attempts++;
      return send();
    });

    if (result.success) {
      debugPrint(
        '[EmailService] send($type) to $toEmail succeeded after $attempts '
        'attempt(s).',
      );
    } else {
      debugPrint(
        '[EmailService] send($type) to $toEmail failed after $attempts '
        'attempt(s): ${result.errorCode} — ${result.errorMessage}',
      );
    }

    await _logEmail(
      type: type,
      toEmail: toEmail,
      status: result.success ? 'sent' : 'failed',
      retries: attempts - 1,
      errorMessage: result.errorMessage,
    );
    return result;
  }

  /// Fetches this-recipient/this-type send timestamps from the last
  /// [RateLimiter.window] for [RateLimiter.isLimited] to evaluate.
  /// Best-effort: if Firestore is unreachable, returns an empty list so a
  /// logging outage never blocks sending.
  static Future<List<DateTime>> _fetchRecentSendTimestamps({
    required String type,
    required String toEmail,
  }) async {
    try {
      final since = DateTime.now().subtract(_rateLimiter.window);
      final snapshot = await FirebaseFirestore.instance
          .collection('email_logs')
          .where('recipient', isEqualTo: toEmail)
          .where('emailType', isEqualTo: type)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
          .get();
      return snapshot.docs
          .map((d) => (d.data()['timestamp'] as Timestamp?)?.toDate())
          .whereType<DateTime>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Best-effort audit write — wrapped in try/catch so a logging failure
  /// (including a rules rejection) never surfaces as a send failure to the
  /// caller. [userId] is read fresh here rather than threaded through every
  /// `send*`/`_send` call site, since every current caller already runs in
  /// an authenticated context by the time it sends an email; this is also
  /// what `firestore.rules`' `email_logs` create rule checks against.
  static Future<void> _logEmail({
    required String type,
    required String toEmail,
    required String status,
    required int retries,
    String? errorMessage,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('email_logs').add({
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'recipient': toEmail,
        'emailType': type,
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
        'retries': retries,
        'errorMessage': errorMessage,
      });
    } catch (_) {
      // Non-fatal — logging failures shouldn't block the caller.
    }
  }

  static String _currentDeviceLabel() {
    try {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {
      return 'Unknown';
    }
  }
}
