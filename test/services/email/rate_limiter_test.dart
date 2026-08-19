import 'package:flutter_test/flutter_test.dart';
import 'package:sawata/services/email/rate_limiter.dart';

void main() {
  group('RateLimiter', () {
    final now = DateTime(2026, 1, 1, 12, 0, 0);

    test('not limited when there are no recent timestamps', () {
      const limiter = RateLimiter(limit: 5, window: Duration(hours: 1));
      expect(limiter.isLimited([], now), isFalse);
    });

    test('not limited when count is below the limit', () {
      const limiter = RateLimiter(limit: 5, window: Duration(hours: 1));
      final timestamps = List.generate(
        4,
        (i) => now.subtract(Duration(minutes: i * 5)),
      );
      expect(limiter.isLimited(timestamps, now), isFalse);
    });

    test('limited when count equals the limit', () {
      const limiter = RateLimiter(limit: 5, window: Duration(hours: 1));
      final timestamps = List.generate(
        5,
        (i) => now.subtract(Duration(minutes: i * 5)),
      );
      expect(limiter.isLimited(timestamps, now), isTrue);
    });

    test('limited when count exceeds the limit', () {
      const limiter = RateLimiter(limit: 5, window: Duration(hours: 1));
      final timestamps = List.generate(
        10,
        (i) => now.subtract(Duration(minutes: i * 2)),
      );
      expect(limiter.isLimited(timestamps, now), isTrue);
    });

    test('timestamps outside the window are not counted', () {
      const limiter = RateLimiter(limit: 3, window: Duration(hours: 1));
      final timestamps = [
        now.subtract(const Duration(minutes: 10)),
        now.subtract(const Duration(minutes: 20)),
        // These are outside the 1-hour window and shouldn't count.
        now.subtract(const Duration(hours: 2)),
        now.subtract(const Duration(hours: 5)),
      ];
      expect(limiter.isLimited(timestamps, now), isFalse);
    });

    test('timestamp exactly at the window boundary is excluded', () {
      const limiter = RateLimiter(limit: 1, window: Duration(hours: 1));
      final boundary = now.subtract(const Duration(hours: 1));
      // isAfter(cutoff) with cutoff == boundary means the boundary itself
      // is NOT counted (strictly after only).
      expect(limiter.isLimited([boundary], now), isFalse);
    });

    test('default constructor uses 5/hour', () {
      const limiter = RateLimiter();
      expect(limiter.limit, 5);
      expect(limiter.window, const Duration(hours: 1));
    });
  });
}
