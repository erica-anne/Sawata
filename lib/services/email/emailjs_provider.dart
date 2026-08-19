import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'email_provider.dart';

/// Sends the Guardian Invitation email via EmailJS's REST API
/// (https://www.emailjs.com/docs/rest-api/send/), rendering the
/// `template_gap8skh` template configured in the EmailJS dashboard.
///
/// Unlike the retired [ResendEmailProvider] (see resend_email_provider.dart),
/// none of the three IDs below are secrets — EmailJS explicitly designs the
/// Service ID, Template ID, and Public Key to be embedded in client-side
/// code (see https://www.emailjs.com/docs/faq/is-it-okay-to-expose-my-public-key/).
/// The one EmailJS credential that must never ship client-side is the
/// *Private Key* (opt-in, used only for strict-mode abuse protection) —
/// this integration doesn't use it.
///
/// [EmailService.sendGuardianInvite] is the only caller — it wraps this
/// provider with the same recipient validation, rate limiting, retry, and
/// Firestore logging used by every other email type, so none of that
/// infrastructure had to be duplicated here.
class EmailJsProvider {
  EmailJsProvider._();

  static const String serviceId = 'service_p5my1u7';

  static const String templateId = 'template_gap8skh';
  static const String publicKey = '2QrOADVZ0eKZiIW33';

  static const _endpoint = 'https://api.emailjs.com/api/v1.0/email/send';

  static bool get isConfigured => serviceId.isNotEmpty;

  /// Sends the Guardian Invitation notification email. [appLink] is the
  /// generic `sawata://guardian-invites` deep link (see [AppConfig]) that
  /// just opens the app to the Guardian Invites screen — deliberately not
  /// invitation-specific, since the guardian reviews and Accepts/Rejects
  /// in-app rather than via anything in the email itself. Sent as the
  /// `invite_link` template variable because that's the name the EmailJS
  /// dashboard template (`template_gap8skh`) already expects.
  static Future<EmailResult> sendGuardianInvite({
    required String toEmail,
    required String guardianName,
    required String userName,
    required String appLink,
  }) async {
    if (!isConfigured) {
      debugPrint(
        '[EmailJsProvider] send() aborted: EmailJS service ID not '
        'configured. Set EmailJsProvider.serviceId in emailjs_provider.dart.',
      );
      return const EmailResult.failure(
        EmailErrorCode.notConfigured,
        'EmailJS is not configured. Set EmailJsProvider.serviceId in '
        'lib/services/email/emailjs_provider.dart.',
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'service_id': serviceId,
              'template_id': templateId,
              'user_id': publicKey,
              'template_params': {
                'email': toEmail,
                'guardian_name': guardianName,
                'user_name': userName,
                'invite_link': appLink,
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('[EmailJsProvider] send() succeeded to $toEmail.');
        return const EmailResult.success();
      }

      // 4xx (unknown service/template/public key, EmailJS account not
      // allowing non-browser requests, invalid params, etc.) is not
      // retryable. 5xx is treated as a transient transport error.
      final code = response.statusCode < 500
          ? EmailErrorCode.rejected
          : EmailErrorCode.transportError;
      debugPrint(
        '[EmailJsProvider] send() rejected by EmailJS for $toEmail: '
        'HTTP ${response.statusCode} — ${response.body}',
      );
      return EmailResult.failure(
        code,
        'HTTP ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      debugPrint('[EmailJsProvider] send() transport error: $e');
      return EmailResult.failure(EmailErrorCode.transportError, e.toString());
    }
  }
}
