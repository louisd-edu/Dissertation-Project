// Unit tests model classes and enums
import 'package:flutter_test/flutter_test.dart';
import 'package:veridose/models/models.dart';

void main() {
  // Profiles

  group('Profile.fromJson', () {
    test('parses patient role, name, and nullable avatar', () {
      final p = Profile.fromJson({
        'id': 'pat-uuid-001',
        'role': 'patient',
        'name': 'Patient',
        'surname': 'One',
        'avatar_url': null,
      });
      expect(p.id, 'pat-uuid-001');
      expect(p.role, ProfileRole.patient);
      expect(p.name, 'Patient');
      expect(p.surname, 'One');
      expect(p.avatarUrl, isNull);
    });

    test('parses doctor role and avatar URL', () {
      final p = Profile.fromJson({
        'id': 'doc-uuid-001',
        'role': 'doctor',
        'name': 'Test',
        'surname': 'Doctor',
        'avatar_url': 'https://example.com/avatar.png',
      });
      expect(p.role, ProfileRole.doctor);
      expect(p.avatarUrl, 'https://example.com/avatar.png');
    });

    test('defaults to patient role for unknown value', () {
      final p = Profile.fromJson({
        'id': 'pat-uuid-002',
        'role': 'admin',
        'name': 'Patient',
        'surname': 'Two',
        'avatar_url': null,
      });
      expect(p.role, ProfileRole.patient);
    });
  });

  group('Profile.fullName', () {
    test('concatenates name and surname with a space', () {
      final p = Profile(
        id: 'pat-uuid-001',
        role: ProfileRole.patient,
        name: 'Patient',
        surname: 'One',
      );
      expect(p.fullName, 'Patient One');
    });
  });

  group('ProfileRole.label', () {
    test('returns correct display strings', () {
      expect(ProfileRole.patient.label, 'Patient');
      expect(ProfileRole.doctor.label, 'Doctor');
    });
  });

  // MedicationPlan

  group('MedicationPlan.fromJson', () {
    Map<String, dynamic> base() => {
          'id': 'plan-1',
          'name': 'Metformin',
          'plan_name': 'Morning Metformin',
          'dosage': 500,
          'units': 'mg',
          'frequency': ['mo', 'tu', 'we', 'th', 'fr'],
          'time': '08:00',
          'start_date': '2026-01-01',
          'end_date': '2026-12-31',
          'patient_id': 'p1',
          'doctor_id': 'd1',
        };

    test('parses all standard fields', () {
      final plan = MedicationPlan.fromJson(base());
      expect(plan.id, 'plan-1');
      expect(plan.name, 'Metformin');
      expect(plan.planName, 'Morning Metformin');
      expect(plan.dosage, 500);
      expect(plan.units, 'mg');
      expect(plan.frequency, ['mo', 'tu', 'we', 'th', 'fr']);
      expect(plan.time, '08:00');
      expect(plan.patientId, 'p1');
      expect(plan.doctorId, 'd1');
      expect(plan.endDate, isNotNull);
    });

    test('accepts null end_date (ongoing plan)', () {
      final json = base()..remove('end_date');
      expect(MedicationPlan.fromJson(json).endDate, isNull);
    });

    test('filters out non-weekday tokens (e.g. "daily", "weekly")', () {
      final json = base()..['frequency'] = ['daily', 'weekly', 'mo'];
      expect(MedicationPlan.fromJson(json).frequency, ['mo']);
    });

    test('deduplicates frequency tokens', () {
      final json = base()..['frequency'] = ['mo', 'mo', 'tu'];
      expect(MedicationPlan.fromJson(json).frequency, ['mo', 'tu']);
    });

    test('parses all seven weekday tokens for a daily schedule', () {
      final json = base()
        ..['frequency'] = ['mo', 'tu', 'we', 'th', 'fr', 'sa', 'su'];
      expect(MedicationPlan.fromJson(json).frequency, hasLength(7));
    });
  });

  group('MedicationPlan.dosageLabel', () {
    test('formats as "<dosage> <units>"', () {
      final plan = MedicationPlan(
        id: '1',
        name: 'Aspirin',
        dosage: 100,
        units: 'mg',
        frequency: ['mo'],
        time: '08:00',
        startDate: DateTime(2026, 1, 1),
        patientId: 'p1',
      );
      expect(plan.dosageLabel, '100 mg');
    });
  });

  // Dose 

  group('Dose.fromJson', () {
    test('parses taken status and takenAt timestamp', () {
      final dose = Dose.fromJson({
        'id': 'd1',
        'status': 'taken',
        'plan_id': 'p1',
        'taken_at': '2026-04-20T08:05:00.000',
        'scheduled_for': '2026-04-20T08:00:00.000',
        'media_url': null,
      });
      expect(dose.status, DoseStatus.taken);
      expect(dose.isTaken, isTrue);
      expect(dose.isMissed, isFalse);
      expect(dose.isSkipped, isFalse);
      expect(dose.takenAt, isNotNull);
    });

    test('parses missed status', () {
      final dose = Dose.fromJson({
        'id': 'd2',
        'status': 'missed',
        'plan_id': 'p1',
        'taken_at': null,
        'scheduled_for': '2026-04-20T08:00:00.000',
        'media_url': null,
      });
      expect(dose.status, DoseStatus.missed);
      expect(dose.isMissed, isTrue);
    });

    test('parses skipped status', () {
      final dose = Dose.fromJson({
        'id': 'd3',
        'status': 'skipped',
        'plan_id': 'p1',
        'taken_at': null,
        'scheduled_for': null,
        'media_url': null,
      });
      expect(dose.status, DoseStatus.skipped);
      expect(dose.isSkipped, isTrue);
    });

    test('defaults to pending for unknown status value', () {
      final dose = Dose.fromJson({
        'id': 'd4',
        'status': 'unknown',
        'plan_id': 'p1',
        'taken_at': null,
        'scheduled_for': null,
        'media_url': null,
      });
      expect(dose.status, DoseStatus.pending);
    });
  });

  // DoseStatus

  group('DoseStatus.isFinal', () {
    test('is true for taken, skipped, and missed', () {
      expect(DoseStatus.taken.isFinal, isTrue);
      expect(DoseStatus.skipped.isFinal, isTrue);
      expect(DoseStatus.missed.isFinal, isTrue);
    });

    test('is false for pending', () {
      expect(DoseStatus.pending.isFinal, isFalse);
    });
  });

  group('DoseStatus.label', () {
    test('returns the correct display string for each status', () {
      expect(DoseStatus.taken.label, 'Taken');
      expect(DoseStatus.missed.label, 'Missed');
      expect(DoseStatus.pending.label, 'Pending');
      expect(DoseStatus.skipped.label, 'Skipped');
    });
  });

  // ScheduledDose

  group('ScheduledDose', () {
    final plan = MedicationPlan(
      id: 'p1',
      name: 'Med',
      dosage: 10,
      units: 'mg',
      frequency: ['mo'],
      time: '08:00',
      startDate: DateTime(2026, 1, 1),
      patientId: 'pat1',
    );
    final scheduled = DateTime(2026, 4, 21, 8);

    test('status is pending and isTaken/isMissed are false when no dose logged', () {
      final sd = ScheduledDose(plan: plan, dose: null, scheduledTime: scheduled);
      expect(sd.status, DoseStatus.pending);
      expect(sd.isTaken, isFalse);
      expect(sd.isMissed, isFalse);
    });

    test('status delegates to the logged dose when taken', () {
      final dose = Dose(id: 'd1', status: DoseStatus.taken, planId: 'p1');
      final sd = ScheduledDose(plan: plan, dose: dose, scheduledTime: scheduled);
      expect(sd.status, DoseStatus.taken);
      expect(sd.isTaken, isTrue);
    });

    test('isMissed is true when the logged dose is missed', () {
      final dose = Dose(id: 'd2', status: DoseStatus.missed, planId: 'p1');
      final sd = ScheduledDose(plan: plan, dose: dose, scheduledTime: scheduled);
      expect(sd.isMissed, isTrue);
    });
  });
}
