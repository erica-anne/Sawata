import 'cloud_function_email_provider.dart';
import 'email_provider.dart';
import 'resend_email_provider.dart';

/// Which transport [EmailService] delegates actual sending to.
enum EmailTransport {
  /// Calls Resend directly from the client. Dev-only — see
  /// resend_email_provider.dart's file header for the API-key exposure
  /// caveat.
  resendClient,

  /// Calls a Firebase Cloud Function (not implemented until the project is
  /// on the Blaze plan — see cloud_function_email_provider.dart).
  cloudFunction,

  /// Kill-switch: no emails are sent, every call fails with
  /// [EmailErrorCode.notConfigured].
  disabled,
}

/// Single feature-flag switch controlling how [EmailService] sends email.
///
/// Flip [transport] to migrate transports without touching any UI or
/// call-site code — everything downstream only depends on the
/// [EmailProvider] interface.
class EmailConfig {
  EmailConfig._();

  /// TODO: flip to [EmailTransport.cloudFunction] once
  /// `CloudFunctionEmailProvider` is implemented and the project is on the
  /// Blaze plan. Flip to [EmailTransport.disabled] to kill-switch outbound
  /// email entirely (e.g. for a build variant or during an incident).
  static const EmailTransport transport = EmailTransport.resendClient;

  static EmailProvider buildProvider() {
    switch (transport) {
      case EmailTransport.resendClient:
        return const ResendEmailProvider();
      case EmailTransport.cloudFunction:
        return const CloudFunctionEmailProvider();
      case EmailTransport.disabled:
        return const NoopEmailProvider();
    }
  }
}
