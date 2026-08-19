/// Pure, dependency-free rate-limiting logic — no Firestore/network calls,
/// so it's trivially unit-testable. [EmailService] is responsible for
/// fetching the recent send timestamps (from Firestore `email_logs`) and
/// handing them to [isLimited].
class RateLimiter {
  const RateLimiter({
    this.limit = 5,
    this.window = const Duration(hours: 1),
  });

  /// Max sends allowed within [window].
  final int limit;

  /// Sliding time window over which [limit] is enforced.
  final Duration window;

  /// Returns true if [limit] or more of [recentSendTimestamps] fall within
  /// [window] of [now].
  bool isLimited(List<DateTime> recentSendTimestamps, DateTime now) {
    final cutoff = now.subtract(window);
    final countInWindow =
        recentSendTimestamps.where((t) => t.isAfter(cutoff)).length;
    return countInWindow >= limit;
  }
}
