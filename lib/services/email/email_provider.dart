/// Typed error codes for email send failures. Callers should branch on
/// this instead of parsing exception messages.
enum EmailErrorCode {
  /// The recipient address failed basic format validation.
  invalidRecipient,

  /// The active [EmailProvider] has no valid credentials / is disabled via
  /// [EmailConfig] (see lib/services/email/email_config.dart).
  notConfigured,

  /// Too many emails of this type were already sent to this recipient
  /// within the rate-limit window.
  rateLimited,

  /// A transient transport-level failure (network error, 5xx from the
  /// provider). Safe to retry.
  transportError,

  /// The provider explicitly rejected the request (e.g. 4xx — bad
  /// payload, invalid API key, invalid "from" address). Not retryable.
  rejected,

  /// Anything else.
  unknown,
}

/// Result of a single email-send attempt. Every [EmailProvider] and
/// [EmailService] method returns this instead of a bare `bool`/thrown
/// exception, so callers can branch on [errorCode] without string-parsing.
class EmailResult {
  const EmailResult.success()
      : success = true,
        errorCode = null,
        errorMessage = null;

  const EmailResult.failure(this.errorCode, [this.errorMessage])
      : success = false;

  final bool success;
  final EmailErrorCode? errorCode;
  final String? errorMessage;

  @override
  String toString() => success
      ? 'EmailResult.success()'
      : 'EmailResult.failure($errorCode, $errorMessage)';
}

/// Abstraction over "how a single email actually gets delivered".
///
/// [EmailService] (lib/services/email_service.dart) owns validation, rate
/// limiting, retry, and Firestore logging — it never talks HTTP directly.
/// It delegates the one thing that differs between transports (sending one
/// already-rendered HTML email) to whichever [EmailProvider] is configured
/// in `EmailConfig.transport`. This is what makes swapping the dev-only
/// client-side [ResendEmailProvider] for a production `CloudFunctionEmailProvider`
/// (once the project is on the Firebase Blaze plan) a one-line change with
/// zero UI/call-site impact.
abstract class EmailProvider {
  /// Sends a single email. Implementations should NOT retry internally —
  /// retry policy lives in [EmailService] so it's transport-agnostic and
  /// unit-testable in isolation.
  Future<EmailResult> send({
    required String toEmail,
    required String subject,
    required String html,
  });
}
