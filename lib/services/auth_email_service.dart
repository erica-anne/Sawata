import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around Firebase Authentication's built-in transactional
/// emails — email verification and password reset.
///
/// These use Firebase's own secure link generation/validation, which a
/// client-only Resend integration can't safely replicate (no backend to
/// issue/verify tokens). Use [EmailService] (lib/services/email_service.dart)
/// only for guardian notifications and optional security alerts —  never
/// for verification or the password-reset link itself.
class AuthEmailService {
  AuthEmailService._();

  /// Sends Firebase's built-in verification email to the currently signed
  /// in user. Throws [StateError] if no user is signed in, or a
  /// [FirebaseAuthException] on failure — callers should handle both.
  static Future<void> sendEmailVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('No signed-in user to send a verification email to.');
    }
    await user.sendEmailVerification();
  }

  /// Sends Firebase's built-in password-reset email to [email]. Throws a
  /// [FirebaseAuthException] on failure (e.g. `user-not-found`).
  static Future<void> sendPasswordResetEmail(String email) {
    return FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }
}
