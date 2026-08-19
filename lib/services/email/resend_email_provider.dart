import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'email_provider.dart';

/// ============================================================================
/// ⚠️  TEMPORARY DEVELOPMENT-ONLY IMPLEMENTATION — API KEY EXPOSURE NOTICE ⚠️
/// ============================================================================
/// This provider calls the Resend REST API (https://resend.com) directly
/// from the compiled Flutter client, because this project currently runs on
/// the Firebase **free (Spark)** plan (no Cloud Functions / Secret Manager
/// available).
///
/// [apiKey] is supplied at build/run time via `--dart-define=RESEND_API_KEY=...`
/// (see the run command in the PR/chat that introduced this) rather than
/// hardcoded, so it never has to be committed to source control. It is still
/// compiled into the app binary and can be extracted by anyone who
/// decompiles the APK/IPA — don't use a Resend key with production-sending
/// privileges you can't afford to have abused.
///
/// This is the ONLY location in the codebase where the Resend API key is
/// referenced. When migrating to Blaze:
///   1. Move the key to Firebase Secret Manager + a Cloud Function that
///      calls Resend server-side.
///   2. Implement `CloudFunctionEmailProvider` (see
///      cloud_function_email_provider.dart) to call that function via
///      `cloud_functions` `httpsCallable`.
///   3. Flip `EmailConfig.transport` to `EmailTransport.cloudFunction`.
///   4. Delete this file (or strip [apiKey] out of it) — no other file
///      needs to change.
/// ============================================================================
class ResendEmailProvider implements EmailProvider {
  const ResendEmailProvider();

  /// Read from `--dart-define=RESEND_API_KEY=your_key` at build/run time.
  /// Empty (and therefore [isConfigured] == false) when not supplied — no
  /// placeholder string to remember to swap out.
  static const String apiKey = String.fromEnvironment('RESEND_API_KEY');

  /// Sandbox sender — only deliverable to the Resend account's own signup
  /// email until a domain is verified. See resend_email_provider.dart's
  /// TODO above once ready to move off sandbox.
  static const String fromAddress = 'Sawatâ <onboarding@resend.dev>';

  static const _endpoint = 'https://api.resend.com/emails';

  static bool get isConfigured => apiKey.isNotEmpty;

  @override
  Future<EmailResult> send({
    required String toEmail,
    required String subject,
    required String html,
  }) async {
    if (!isConfigured) {
      debugPrint(
        '[ResendEmailProvider] send() aborted: RESEND_API_KEY not supplied. '
        'Run with --dart-define=RESEND_API_KEY=your_key.',
      );
      return const EmailResult.failure(
        EmailErrorCode.notConfigured,
        'Resend is not configured. Run the app with '
        '--dart-define=RESEND_API_KEY=your_key.',
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'from': fromAddress,
              'to': [toEmail],
              'subject': subject,
              'html': html,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint(
          '[ResendEmailProvider] send() succeeded '
          '(HTTP ${response.statusCode}) to $toEmail.',
        );
        return const EmailResult.success();
      }

      // 4xx (bad request, invalid key, invalid "from", unverified
      // recipient in sandbox mode, etc.) is not retryable. 5xx is treated
      // as a transient transport error.
      final code = response.statusCode < 500
          ? EmailErrorCode.rejected
          : EmailErrorCode.transportError;
      debugPrint(
        '[ResendEmailProvider] send() rejected by Resend for $toEmail: '
        'HTTP ${response.statusCode} — ${response.body}',
      );
      return EmailResult.failure(
        code,
        'HTTP ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      debugPrint('[ResendEmailProvider] send() transport error: $e');
      return EmailResult.failure(EmailErrorCode.transportError, e.toString());
    }
  }
}
