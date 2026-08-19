import 'email_provider.dart';

/// Placeholder for the production transport: a Firebase Cloud Function
/// (`https.onCall`) that holds the Resend/other provider API key in
/// Secret Manager and sends server-side.
///
/// NOT YET IMPLEMENTED — this project is on the Firebase free (Spark) plan,
/// which doesn't support Cloud Functions. Once upgraded to Blaze:
///
/// 1. Add a `functions/` directory with an `https.onCall` function, e.g.
///    `sendEmail(type, toEmail, subject, html)`, that reads the provider
///    API key from Secret Manager and calls the provider server-side.
/// 2. Add the `cloud_functions` package to pubspec.yaml.
/// 3. Implement [send] below using
///    `FirebaseFunctions.instance.httpsCallable('sendEmail').call({...})`,
///    mapping the callable's response/errors to [EmailResult].
/// 4. Flip `EmailConfig.transport` to `EmailTransport.cloudFunction` in
///    email_config.dart — no other file in the app needs to change, since
///    [EmailService] only depends on the [EmailProvider] interface.
class CloudFunctionEmailProvider implements EmailProvider {
  const CloudFunctionEmailProvider();

  @override
  Future<EmailResult> send({
    required String toEmail,
    required String subject,
    required String html,
  }) async {
    return const EmailResult.failure(
      EmailErrorCode.notConfigured,
      'CloudFunctionEmailProvider is not implemented yet. Upgrade to the '
      'Blaze plan and implement it (see class doc comment), then switch '
      'EmailConfig.transport to EmailTransport.cloudFunction.',
    );
  }
}

/// A transport that always fails without attempting any network I/O.
/// Used when `EmailConfig.transport == EmailTransport.disabled` — e.g. to
/// kill-switch outbound email in an environment/build without touching
/// call sites.
class NoopEmailProvider implements EmailProvider {
  const NoopEmailProvider();

  @override
  Future<EmailResult> send({
    required String toEmail,
    required String subject,
    required String html,
  }) async {
    return const EmailResult.failure(
      EmailErrorCode.notConfigured,
      'Email sending is disabled (EmailConfig.transport == '
      'EmailTransport.disabled).',
    );
  }
}
