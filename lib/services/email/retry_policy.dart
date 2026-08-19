import 'email_provider.dart';

/// Pure, transport-agnostic retry-with-backoff executor. Retries only on
/// [EmailErrorCode.transportError] (transient failures) — validation,
/// rate-limit, "not configured", and provider-rejected results are
/// returned immediately since retrying them can't succeed.
///
/// [delay] is injectable so unit tests can run without waiting on real
/// timers.
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 400),
    this.delay = Future.delayed,
  });

  final int maxAttempts;
  final Duration baseDelay;
  final Future<void> Function(Duration) delay;

  Duration delayForAttempt(int attempt) => baseDelay * attempt;

  /// Runs [attempt] up to [maxAttempts] times. [attempt] is called once
  /// per try and should perform exactly one send (no internal retry).
  Future<EmailResult> execute(Future<EmailResult> Function() attempt) async {
    EmailResult? last;
    for (var i = 1; i <= maxAttempts; i++) {
      final result = await attempt();
      if (result.success || result.errorCode != EmailErrorCode.transportError) {
        return result;
      }
      last = result;
      if (i < maxAttempts) {
        await delay(delayForAttempt(i));
      }
    }
    return last!;
  }
}
