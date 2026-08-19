import 'package:flutter_test/flutter_test.dart';
import 'package:sawata/services/email/email_provider.dart';
import 'package:sawata/services/email/retry_policy.dart';

void main() {
  group('RetryPolicy', () {
    // Avoid real timers in tests.
    Future<void> noDelay(Duration d) async {}

    test('returns success immediately without retrying', () async {
      var callCount = 0;
      final policy = RetryPolicy(delay: noDelay);

      final result = await policy.execute(() async {
        callCount++;
        return const EmailResult.success();
      });

      expect(result.success, isTrue);
      expect(callCount, 1);
    });

    test('retries on transportError and eventually succeeds', () async {
      var callCount = 0;
      final policy = RetryPolicy(maxAttempts: 3, delay: noDelay);

      final result = await policy.execute(() async {
        callCount++;
        if (callCount < 3) {
          return const EmailResult.failure(
            EmailErrorCode.transportError,
            'transient',
          );
        }
        return const EmailResult.success();
      });

      expect(result.success, isTrue);
      expect(callCount, 3);
    });

    test('gives up after maxAttempts and returns last failure', () async {
      var callCount = 0;
      final policy = RetryPolicy(maxAttempts: 3, delay: noDelay);

      final result = await policy.execute(() async {
        callCount++;
        return const EmailResult.failure(
          EmailErrorCode.transportError,
          'still failing',
        );
      });

      expect(result.success, isFalse);
      expect(result.errorCode, EmailErrorCode.transportError);
      expect(callCount, 3);
    });

    test('does not retry on non-transient errors (rejected)', () async {
      var callCount = 0;
      final policy = RetryPolicy(maxAttempts: 3, delay: noDelay);

      final result = await policy.execute(() async {
        callCount++;
        return const EmailResult.failure(EmailErrorCode.rejected, 'bad request');
      });

      expect(result.success, isFalse);
      expect(result.errorCode, EmailErrorCode.rejected);
      expect(callCount, 1);
    });

    test('does not retry on notConfigured', () async {
      var callCount = 0;
      final policy = RetryPolicy(maxAttempts: 3, delay: noDelay);

      final result = await policy.execute(() async {
        callCount++;
        return const EmailResult.failure(EmailErrorCode.notConfigured, 'no key');
      });

      expect(callCount, 1);
      expect(result.errorCode, EmailErrorCode.notConfigured);
    });

    test('delayForAttempt scales linearly with baseDelay', () {
      const policy = RetryPolicy(baseDelay: Duration(milliseconds: 400));
      expect(policy.delayForAttempt(1), const Duration(milliseconds: 400));
      expect(policy.delayForAttempt(2), const Duration(milliseconds: 800));
      expect(policy.delayForAttempt(3), const Duration(milliseconds: 1200));
    });

    test('invokes injected delay between retries the expected number of times', () async {
      final delays = <Duration>[];
      final policy = RetryPolicy(
        maxAttempts: 3,
        delay: (d) async {
          delays.add(d);
        },
      );

      await policy.execute(() async {
        return const EmailResult.failure(EmailErrorCode.transportError, 'x');
      });

      // Delay happens between attempts only: maxAttempts - 1 times.
      expect(delays.length, 2);
    });
  });
}
