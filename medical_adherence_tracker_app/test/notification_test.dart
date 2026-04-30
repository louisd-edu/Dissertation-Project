// Unit tests notification data models and payload
import 'package:flutter_test/flutter_test.dart';
import 'package:veridose/services/notification_service.dart';

void main() {
  // MedicationReminder data class

  group('MedicationReminder', () {
    final scheduledAt = DateTime(2026, 4, 21, 8, 0);

    test('stores all fields passed to the constructor', () {
      const payload = 'medication:plan-uuid-001:2026-04-21';
      final reminder = MedicationReminder(
        notificationId: 1001,
        title: 'Medication reminder',
        body: 'It is time to take Metformin (500 mg).',
        scheduledAt: scheduledAt,
        payload: payload,
      );

      expect(reminder.notificationId, 1001);
      expect(reminder.title, 'Medication reminder');
      expect(reminder.body, 'It is time to take Metformin (500 mg).');
      expect(reminder.scheduledAt, scheduledAt);
      expect(reminder.payload, payload);
    });

    test('two reminders with different IDs are not equal references', () {
      final r1 = MedicationReminder(
        notificationId: 1,
        title: 'T',
        body: 'B',
        scheduledAt: scheduledAt,
        payload: 'medication:p1',
      );
      final r2 = MedicationReminder(
        notificationId: 2,
        title: 'T',
        body: 'B',
        scheduledAt: scheduledAt,
        payload: 'medication:p2',
      );
      expect(r1.notificationId, isNot(r2.notificationId));
    });

    test('one-hour-before reminder body mentions medication name', () {
      final reminder = MedicationReminder(
        notificationId: 2001,
        title: 'Medication reminder',
        body: 'Take Salbutamol (100 mcg) in one hour.',
        scheduledAt: scheduledAt.subtract(const Duration(hours: 1)),
        payload: 'medication:plan-uuid-002:2026-04-21',
      );
      expect(reminder.body, contains('Salbutamol'));
      expect(reminder.body, contains('one hour'));
    });

    test('on-time reminder body says "It is time to take"', () {
      final reminder = MedicationReminder(
        notificationId: 2002,
        title: 'Medication reminder',
        body: 'It is time to take Salbutamol (100 mcg).',
        scheduledAt: scheduledAt,
        payload: 'medication:plan-uuid-002:2026-04-21',
      );
      expect(reminder.body, contains('It is time to take'));
    });

    test('one-hour-after reminder body contains "one hour past"', () {
      final reminder = MedicationReminder(
        notificationId: 2003,
        title: 'Medication reminder',
        body:
            'You are one hour past Salbutamol (100 mcg). Please take it now before it is missed.',
        scheduledAt: scheduledAt.add(const Duration(hours: 1)),
        payload: 'medication:plan-uuid-002:2026-04-21',
      );
      expect(reminder.body, contains('one hour past'));
    });
  });

  // NotificationService.medicationPayloadFor

  group('NotificationService.medicationPayloadFor', () {
    test('returns a string prefixed with "medication:"', () {
      final payload = NotificationService.medicationPayloadFor(
          'plan-uuid-001:2026-04-21');
      expect(payload, startsWith('medication:'));
    });

    test('payload contains the plan-day key', () {
      const key = 'plan-uuid-001:2026-04-21';
      final payload = NotificationService.medicationPayloadFor(key);
      expect(payload, contains(key));
    });

    test('different keys produce different payloads', () {
      final a = NotificationService.medicationPayloadFor('plan-1:2026-04-21');
      final b = NotificationService.medicationPayloadFor('plan-2:2026-04-21');
      expect(a, isNot(b));
    });
  });
}
