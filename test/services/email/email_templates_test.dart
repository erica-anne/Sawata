import 'package:flutter_test/flutter_test.dart';
import 'package:sawata/services/email/email_templates.dart';
import 'package:sawata/services/email/security_event.dart';

void main() {
  group('EmailTemplates', () {
    test('guardianAccepted includes guardian name and acceptance date', () {
      final acceptedAt = DateTime(2026, 1, 2, 14, 0);
      final html = EmailTemplates.guardianAccepted(
        toName: 'Sam',
        guardianName: 'Taylor',
        acceptedAt: acceptedAt,
      );

      expect(html, contains('Taylor'));
      expect(html, contains('Sam'));
      expect(html, contains('January 2, 2026'));
    });

    test('guardianRejected includes guardian name', () {
      final html = EmailTemplates.guardianRejected(
        toName: 'Sam',
        guardianName: 'Taylor',
      );
      expect(html, contains('Taylor'));
      expect(html, contains('declined'));
    });

    test('passwordResetAlert includes device and IP when provided', () {
      final requestedAt = DateTime(2026, 5, 1, 8, 15);
      final html = EmailTemplates.passwordResetAlert(
        toName: 'Riley',
        requestedAt: requestedAt,
        device: 'android 14',
        ipAddress: '203.0.113.5',
      );

      expect(html, contains('Riley'));
      expect(html, contains('android 14'));
      expect(html, contains('203.0.113.5'));
      expect(html, contains('May 1, 2026'));
    });

    test('passwordResetAlert falls back to "Unknown" when device/IP missing', () {
      final html = EmailTemplates.passwordResetAlert(
        toName: 'Riley',
        requestedAt: DateTime(2026, 5, 1, 8, 15),
      );
      expect(html, contains('Unknown'));
    });

    test('securityAlert renders event label, severity, and recommended action', () {
      final timestamp = DateTime(2026, 6, 1, 10, 0);
      final html = EmailTemplates.securityAlert(
        userName: 'Casey',
        event: SecurityEventType.multipleGamblingAttempts,
        timestamp: timestamp,
        deviceName: 'ios 17',
      );

      final info = securityEventCatalog[SecurityEventType.multipleGamblingAttempts]!;
      expect(html, contains('Casey'));
      expect(html, contains(info.label));
      expect(html, contains(info.recommendedAction));
      expect(html, contains('HIGH'));
      expect(html, contains('ios 17'));
    });

    test('securityAlert reflects correct severity per event type', () {
      final critical = EmailTemplates.securityAlert(
        userName: 'Casey',
        event: SecurityEventType.uninstallAttempt,
        timestamp: DateTime(2026, 1, 1),
      );
      expect(critical, contains('CRITICAL'));

      final medium = EmailTemplates.securityAlert(
        userName: 'Casey',
        event: SecurityEventType.protectionDisabledManually,
        timestamp: DateTime(2026, 1, 1),
      );
      expect(medium, contains('MEDIUM'));
    });

    test('weeklyGuardianReport includes streak, attempts, and uptime', () {
      final html = EmailTemplates.weeklyGuardianReport(
        guardianName: 'Morgan',
        userName: 'Jamie',
        streakDays: 12,
        blockedAttempts: 4,
        protectionUptimePct: 98.6,
      );

      expect(html, contains('Morgan'));
      expect(html, contains('Jamie'));
      expect(html, contains('12 days'));
      expect(html, contains('4'));
      expect(html, contains('99%')); // toStringAsFixed(0) rounds 98.6 -> 99
    });

    test('all templates produce well-formed, non-empty HTML documents', () {
      final htmls = [
        EmailTemplates.guardianAccepted(
          toName: 'A',
          guardianName: 'B',
          acceptedAt: DateTime(2026, 1, 1),
        ),
        EmailTemplates.guardianRejected(toName: 'A', guardianName: 'B'),
        EmailTemplates.passwordResetAlert(
          toName: 'A',
          requestedAt: DateTime(2026, 1, 1),
        ),
        EmailTemplates.securityAlert(
          userName: 'A',
          event: SecurityEventType.guardianRemoved,
          timestamp: DateTime(2026, 1, 1),
        ),
        EmailTemplates.weeklyGuardianReport(
          guardianName: 'A',
          userName: 'B',
          streakDays: 1,
          blockedAttempts: 0,
          protectionUptimePct: 100,
        ),
      ];

      for (final html in htmls) {
        expect(html, isNotEmpty);
        expect(html, contains('<html'));
        expect(html, contains('</html>'));
        expect(html, contains('Sawatâ'));
      }
    });
  });
}
