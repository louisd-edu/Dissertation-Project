//Profile
class Profile {
  final String id;
  final String role; // 'patient', 'doctor'
  final String name;
  final String surname;
  final String? avatarUrl;

  Profile({
    required this.id,
    required this.role,
    required this.name,
    required this.surname,
    this.avatarUrl,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'],
        role: json['role'] ?? 'patient',
        name: json['name'] ?? '',
        surname: json['surname'] ?? '',
        avatarUrl: json['avatar_url'],
      );

  String get fullName => '$name $surname';
}

//Patient
class Patient {
  final String id;
  final String? doctorId;
  final String? condition;

  Patient({required this.id, this.doctorId, this.condition});

  factory Patient.fromJson(Map<String, dynamic> json) => Patient(
        id: json['id'],
        doctorId: json['doctor_id'],
        condition: json['condition'],
      );
}

//MedicationPlan
class MedicationPlan {
  final String id;
  final String name;
  final int dosage;
  final String units;
  final String frequency; // 'mo', 'tu', 'we', 'th', 'fr', 'sa', 'su'
  final String time;
  final DateTime startDate;
  final DateTime? endDate;
  final String patientId;
  final String? doctorId;

  MedicationPlan({
    required this.id,
    required this.name,
    required this.dosage,
    required this.units,
    required this.frequency,
    required this.time,
    required this.startDate,
    this.endDate,
    required this.patientId,
    this.doctorId,
  });

  factory MedicationPlan.fromJson(Map<String, dynamic> json) => MedicationPlan(
        id: json['id'],
        name: json['name'] ?? '',
        dosage: json['dosage'] ?? 0,
        units: json['units'] ?? '',
        frequency: json['frequency'] ?? '',
        time: json['time'] ?? '08:00',
        startDate: DateTime.parse(json['start_date'] ?? DateTime.now().toIso8601String()),
        endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
        patientId: json['patient_id'],
        doctorId: json['doctor_id'],
      );

  String get dosageLabel => '$dosage $units';

  Map<String, dynamic> toJson() => {
        'name': name,
        'dosage': dosage,
        'units': units,
        'frequency': frequency,
        'time': time,
        'start_date': startDate.toIso8601String().split('T').first,
        'end_date': endDate?.toIso8601String().split('T').first,
        'patient_id': patientId,
        'doctor_id': doctorId,
      };
}

//Dose
class Dose {
  final String id;
  final DateTime? takenAt;
  final String status; //'taken', 'missed', 'skipped', 'pending'
  final String? mediaUrl;
  final String planId;

  Dose({
    required this.id,
    this.takenAt,
    required this.status,
    this.mediaUrl,
    required this.planId,
  });

  factory Dose.fromJson(Map<String, dynamic> json) => Dose(
        id: json['id'],
        takenAt: json['taken_at'] != null ? DateTime.parse(json['taken_at']) : null,
        status: json['status'] ?? 'pending',
        mediaUrl: json['media_url'],
        planId: json['plan_id'],
      );

  bool get isTaken => status == 'taken';
  bool get isMissed => status == 'missed';
  bool get isSkipped => status == 'skipped';

  Map<String, dynamic> toJson() => {
        'taken_at': takenAt?.toIso8601String(),
        'status': status,
        'media_url': mediaUrl,
        'plan_id': planId,
      };
}

//
class ScheduledDose {
  final MedicationPlan plan;
  final Dose? dose;
  final DateTime scheduledTime;

  ScheduledDose({
    required this.plan,
    this.dose,
    required this.scheduledTime,
  });

  bool get isTaken => dose?.isTaken ?? false;
  bool get isMissed => dose?.isMissed ?? false;
  String get status => dose?.status ?? 'pending';
}