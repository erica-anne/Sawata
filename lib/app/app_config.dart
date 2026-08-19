/// Centralized, non-secret app configuration — URLs, support contact, etc.
/// that were previously hardcoded as string literals scattered across UI
/// and service files. Change values here instead of hunting through the
/// codebase.
///
/// NOTE: this is for plain config values only. Secrets (API keys) live in
/// their own provider files with explicit dev-only exposure warnings — see
/// lib/services/email/resend_email_provider.dart.
class AppConfig {
  AppConfig._();

  /// Scheme + host for the "open Sawatâ to my Guardian Requests" deep link
  /// (`sawata://guardian-invites`), sent as the `invite_link` EmailJS
  /// template variable and handled on the Android side by the
  /// intent-filter on `MainActivity` (see AndroidManifest.xml) plus
  /// [DeepLinkService].
  ///
  /// Deliberately generic, not invitation-specific: it just opens the
  /// existing Guardian Invites screen so the guardian can review and
  /// Accept/Reject in-app — see [DeepLinkService] for why (the email no
  /// longer references a specific `invites/{id}` doc at all).
  ///
  /// This is a custom URI scheme, NOT a verified Android App Link — that
  /// would require owning a real HTTPS domain to host a signed Digital
  /// Asset Links file, which this project doesn't have. See the
  /// AndroidManifest.xml comment on this intent-filter for what that
  /// tradeoff means in practice.
  static const String guardianInvitesScheme = 'sawata';
  static const String guardianInvitesHost = 'guardian-invites';
  static const String guardianInvitesLink =
      '$guardianInvitesScheme://$guardianInvitesHost';

  /// Support inbox shown in the footer of outbound emails.
  static const String supportEmail = 'support@sawata.app';
}
