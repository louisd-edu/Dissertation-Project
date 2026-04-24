String? _asString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is List && value.isNotEmpty) {
    final first = value.first;
    return first == null ? null : first.toString();
  }
  return value.toString();
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is double) return value.round();

  final raw = value.toString().trim();
  if (raw.isEmpty) return fallback;

  final asInt = int.tryParse(raw);
  if (asInt != null) return asInt;

  final asDouble = double.tryParse(raw);
  if (asDouble != null) return asDouble.round();

  return fallback;
}

DateTime _asDateTime(dynamic value, {DateTime? fallback}) {
  if (value is DateTime) return value;

  final raw = _asString(value)?.trim();
  if (raw == null || raw.isEmpty) {
    return fallback ?? DateTime.now();
  }

  final parsed = DateTime.tryParse(raw);
  return parsed ?? (fallback ?? DateTime.now());
}

DateTime? _asNullableDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;

  final raw = _asString(value)?.trim();
  if (raw == null || raw.isEmpty) return null;

  return DateTime.tryParse(raw);
}

List<String> _parseFrequency(dynamic value) {
  if (value == null) return const [];

  final rawTokens = <String>[];

  if (value is List) {
    rawTokens.addAll(value.map((e) => e.toString()));
  } else {
    final raw = value.toString().trim();
    if (raw.isEmpty) return const [];
    final cleaned = raw
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('"', '')
        .replaceAll("'", '');
    rawTokens.addAll(cleaned.split(','));
  }

  final parsed = <String>[];
  final seen = <String>{};

  for (final token in rawTokens) {
    final normalized = token.trim().toLowerCase();
    if (normalized.isEmpty) continue;

    // Use one weekday format only.
    final canonical = normalized == 'sun' ? 'su' : normalized;
    if (!const {'mo', 'tu', 'we', 'th', 'fr', 'sa', 'su'}.contains(canonical)) {
      continue;
    }

    if (seen.add(canonical)) {
      parsed.add(canonical);
    }
  }

  return parsed;
}

enum ProfileRole {
  patient,
  doctor,
}

extension ProfileRoleX on ProfileRole {
  String get label => switch (this) {
        ProfileRole.patient => 'Patient',
        ProfileRole.doctor => 'Doctor',
      };
}

ProfileRole _profileRoleFromJson(dynamic value) {
  final raw = _asString(value)?.trim().toLowerCase();
  return switch (raw) {
    'doctor' => ProfileRole.doctor,
    _ => ProfileRole.patient,
  };
}

enum DoseStatus {
  taken,
  skipped,
  missed,
  pending,
}

extension DoseStatusX on DoseStatus {
  String get label => switch (this) {
        DoseStatus.taken => 'Taken',
        DoseStatus.skipped => 'Skipped',
        DoseStatus.missed => 'Missed',
        DoseStatus.pending => 'Pending',
      };

  bool get isFinal => this != DoseStatus.pending;
}

DoseStatus _doseStatusFromJson(dynamic value) {
  final raw = _asString(value)?.trim().toLowerCase();
  return switch (raw) {
    'taken' => DoseStatus.taken,
    'skipped' => DoseStatus.skipped,
    'missed' => DoseStatus.missed,
    'pending' => DoseStatus.pending,
    _ => DoseStatus.pending,
  };
}

class Profile {
  final String id;
  final ProfileRole role;
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
        id: _asString(json['id']) ?? '',
        role: _profileRoleFromJson(json['role']),
        name: _asString(json['name']) ?? '',
        surname: _asString(json['surname']) ?? '',
        avatarUrl: _asString(json['avatar_url']),
      );

  String get fullName => '$name $surname';
}

class Patient {
  final String id;
  final String? doctorId;
  final String? condition;

  Patient({required this.id, this.doctorId, this.condition});

  factory Patient.fromJson(Map<String, dynamic> json) => Patient(
        id: _asString(json['id']) ?? '',
        doctorId: _asString(json['doctor_id']),
        condition: _asString(json['condition']),
      );
}

class MedicationPlan {
  final String id;
  final String name;
  final String? planName;
  final int dosage;
  final String units;
  final List<String> frequency; // ['mo', 'tu', 'we', 'th', 'fr', 'sa', 'su']
  final String time;
  final DateTime startDate;
  final DateTime? endDate;
  final String patientId;
  final String? doctorId;

  MedicationPlan({
    required this.id,
    required this.name,
    this.planName,
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
        id: _asString(json['id']) ?? '',
        name: _asString(json['name']) ?? '',
        planName: _asString(json['plan_name']),
        dosage: _asInt(json['dosage']),
        units: _asString(json['units']) ?? '',
        frequency: _parseFrequency(json['frequency']),
        time: _asString(json['time']) ?? '08:00',
        startDate: _asDateTime(json['start_date']),
        endDate: _asNullableDateTime(json['end_date']),
        patientId: _asString(json['patient_id']) ?? '',
        doctorId: _asString(json['doctor_id']),
      );

  String get dosageLabel => '$dosage $units';

  Map<String, dynamic> toJson() => {
        'plan_name': planName,
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

class Dose {
  final String id;
  final DateTime? takenAt;
  final DateTime? scheduledFor;
  final DoseStatus status;
  final String? mediaUrl;
  final String planId;

  Dose({
    required this.id,
    this.takenAt,
    this.scheduledFor,
    required this.status,
    this.mediaUrl,
    required this.planId,
  });

  factory Dose.fromJson(Map<String, dynamic> json) => Dose(
        id: _asString(json['id']) ?? '',
        takenAt: json['taken_at'] != null
            ? DateTime.parse(_asString(json['taken_at'])!)
            : null,
        scheduledFor: json['scheduledFor'] != null
            ? DateTime.parse(_asString(json['scheduledFor'])!)
            : json['scheduled_for'] != null
                ? DateTime.parse(_asString(json['scheduled_for'])!)
                : null,
        status: _doseStatusFromJson(json['status']),
        mediaUrl: _asString(json['media_url']),
        planId: _asString(json['plan_id']) ?? '',
      );

  bool get isTaken => status == DoseStatus.taken;
  bool get isMissed => status == DoseStatus.missed;
  bool get isSkipped => status == DoseStatus.skipped;

  Map<String, dynamic> toJson() => {
        'taken_at': takenAt?.toIso8601String(),
        'scheduled_for': scheduledFor?.toIso8601String(),
        'status': status.name,
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
  DoseStatus get status => dose?.status ?? DoseStatus.pending;
}
