import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';

class AppState extends ChangeNotifier {
  final _service = SupabaseService();
  final _notificationService = NotificationService.instance;
  Profile? _profile;
  Patient? _patient;
  List<MedicationPlan> _plans = [];
  List<ScheduledDose> _todaySchedule = [];
  Map<String, int> _weeklyStats = {};
  Map<String, int> _weeklyDoseBreakdown = {
    'taken': 0,
    'skipped': 0,
    'missed': 0,
    'pending': 0,
    'expected': 0,
  };
  String? _lastDoseError;
  int _dailyStreak = 0;
  int _weeksCompleted = 0;
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();
  Timer? _scheduleRefreshTimer;

  static const int _reminderLookaheadDays = 7;
  static const Duration _reminderBeforeOffset = Duration(hours: -1);
  static const Duration _reminderOnTimeOffset = Duration.zero;
  static const Duration _reminderAfterOffset = Duration(hours: 2);

  Profile? get profile => _profile;
  Patient? get patient => _patient;
  List<MedicationPlan> get plans => _plans;
  List<ScheduledDose> get todaySchedule => _todaySchedule;
  Map<String, int> get weeklyStats => _weeklyStats;
  Map<String, int> get weeklyDoseBreakdown => _weeklyDoseBreakdown;
  String? get lastDoseError => _lastDoseError;
  int get dailyStreak => _dailyStreak;
  int get weeksCompleted => _weeksCompleted;
  bool get isLoading => _isLoading;
  DateTime get selectedDate => _selectedDate;

  void reset() {
    _scheduleRefreshTimer?.cancel();
    _scheduleRefreshTimer = null;
    _profile = null;
    _patient = null;
    _plans = [];
    _todaySchedule = [];
    _weeklyStats = {};
    _weeklyDoseBreakdown = {
      'taken': 0,
      'skipped': 0,
      'missed': 0,
      'pending': 0,
      'expected': 0,
    };
    _lastDoseError = null;
    _dailyStreak = 0;
    _weeksCompleted = 0;
    _isLoading = false;
    unawaited(_notificationService.clearMedicationReminders());
    notifyListeners();
  }

  void _startScheduleRefreshTimer() {
    _scheduleRefreshTimer?.cancel();
    _scheduleRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_patient != null) unawaited(loadTodaySchedule());
    });
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
    loadTodaySchedule();
  }

  Future<bool> loadAll({String? userId}) async {
    final resolvedUserId = userId ?? _service.currentUser?.id;
    if (resolvedUserId == null) {
      reset();
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final profileFuture = _service.getProfile(resolvedUserId);
      final patientFuture = _service.getPatient(resolvedUserId);
      _profile = await profileFuture;
      _patient = await patientFuture;

      if (_patient == null) {
        _plans = [];
        _todaySchedule = [];
        _weeklyStats = {};
        _weeklyDoseBreakdown = {
          'taken': 0,
          'skipped': 0,
          'missed': 0,
          'pending': 0,
          'expected': 0,
        };
        _dailyStreak = 0;
        _weeksCompleted = 0;
        unawaited(_notificationService.clearMedicationReminders());
        return false;
      }

      _plans = await _service.getMedicationPlans(_patient!.id);
      _todaySchedule = [];
      notifyListeners();

      unawaited(loadTodaySchedule());
      unawaited(loadStats());
      unawaited(_syncMedicationReminders());
      _startScheduleRefreshTimer();

      return _profile != null && _patient != null;
    } catch (_) {
      _plans = [];
      _todaySchedule = [];
      _weeklyStats = {};
      _weeklyDoseBreakdown = {
        'taken': 0,
        'skipped': 0,
        'missed': 0,
        'pending': 0,
        'expected': 0,
      };
      _lastDoseError = null;
      _dailyStreak = 0;
      _weeksCompleted = 0;
      unawaited(_notificationService.clearMedicationReminders());
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPlans({bool syncReminders = true}) async {
    if (_patient == null) {
      unawaited(_notificationService.clearMedicationReminders());
      return;
    }

    _plans = await _service.getMedicationPlans(_patient!.id);
    if (syncReminders) {
      await _syncMedicationReminders();
    }
    await loadTodaySchedule();
  }

  Future<void> loadTodaySchedule() async {
    if (_patient == null) return;

    final schedule = <ScheduledDose>[];
    final now = DateTime.now();
    final todayOnly = _dateOnly(now);
    final selectedDateOnly = _dateOnly(_selectedDate);

    final doses =
        await _service.getDosesForPatient(_patient!.id, date: selectedDateOnly);
    final dosesByPlan = _indexDosesByPlanForDay(doses);

    for (final plan in _plans) {
      if (!_isPlanScheduledForDate(plan, selectedDateOnly)) continue;

      final scheduledTime = _scheduledDateTime(plan, selectedDateOnly);
      final existingDose = dosesByPlan[plan.id];
      final effectiveDose = _effectiveDoseForSchedule(
        existingDose,
        scheduledTime,
        selectedDateOnly,
        todayOnly,
        now,
      );

      Dose? displayDose = effectiveDose;

      if (effectiveDose != null &&
          effectiveDose.status == DoseStatus.missed &&
          (existingDose == null || existingDose.status == DoseStatus.pending)) {
        final persistedDose = await _persistMissedDose(
          planId: plan.id,
          scheduledFor: scheduledTime,
        );
        displayDose = persistedDose ?? effectiveDose;
      }

      schedule.add(
        ScheduledDose(
          plan: plan,
          dose: displayDose,
          scheduledTime: scheduledTime,
        ),
      );
    }

    schedule.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    _todaySchedule = schedule;
    notifyListeners();
  }

  Future<void> loadStats() async {
    if (_patient == null) return;

    final now = DateTime.now();
    final todayOnly = _dateOnly(now);
    final startOfCurrentWeek =
        todayOnly.subtract(Duration(days: todayOnly.weekday - 1));
    final endOfCurrentWeek = startOfCurrentWeek.add(const Duration(days: 6));

    final dailyStreakStart = todayOnly.subtract(const Duration(days: 364));
    final weekWindowStart =
        startOfCurrentWeek.subtract(const Duration(days: 51 * 7));
    final earliestDate = dailyStreakStart.isBefore(weekWindowStart)
        ? dailyStreakStart
        : weekWindowStart;

    final rangeDoses = await _service.getDosesForPatientInRange(
      _patient!.id,
      earliestDate,
      endOfCurrentWeek.add(const Duration(days: 1)),
    );
    final doseIndex = _indexDosesByPlanAndDay(rangeDoses);

    _weeklyDoseBreakdown = _getDoseStatsForRangeFromIndex(
      startOfCurrentWeek,
      endOfCurrentWeek,
      doseIndex,
      now,
    );
    _weeklyStats = Map<String, int>.from(_weeklyDoseBreakdown);

    int streak = 0;
    for (int i = 0; i < 365; i++) {
      final day = todayOnly.subtract(Duration(days: i));
      final dayStats = _getDoseStatsForRangeFromIndex(day, day, doseIndex, now);
      if ((dayStats['skipped'] ?? 0) == 0 && (dayStats['missed'] ?? 0) == 0) {
        streak++;
      } else {
        break;
      }
    }
    _dailyStreak = streak;

    int completedWeeks = 0;
    for (int week = 0; week < 52; week++) {
      final weekStart = startOfCurrentWeek.subtract(Duration(days: week * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final weekStats =
          _getDoseStatsForRangeFromIndex(weekStart, weekEnd, doseIndex, now);
      if ((weekStats['skipped'] ?? 0) == 0 && (weekStats['missed'] ?? 0) == 0) {
        completedWeeks++;
      } else {
        break;
      }
    }
    _weeksCompleted = completedWeeks;

    notifyListeners();
  }

  Future<bool> logDose(
    String planId,
    DoseStatus status, {
    required DateTime scheduledFor,
    File? evidenceFile,
    String? mediaUrl,
    DateTime? takenAt,
  }) async {
    _lastDoseError = null;

    try {
      if (_patient == null || !_plans.any((p) => p.id == planId)) return false;

      String? resolvedMediaUrl = mediaUrl;
      if (evidenceFile != null && status == DoseStatus.taken) {
        final uploadedPath = await _service.uploadEvidence(
          _patient!.id,
          planId,
          scheduledFor,
          evidenceFile,
        );
        resolvedMediaUrl = uploadedPath ?? mediaUrl;
      }

      final payload = {
        'plan_id': planId,
        'status': status.name,
        'scheduled_for': scheduledFor.toIso8601String(),
        'taken_at': (status == DoseStatus.taken || status == DoseStatus.skipped)
            ? (takenAt ?? DateTime.now()).toIso8601String()
            : null,
        'media_url': resolvedMediaUrl,
      };

      final dose = await _service.logDose(payload);
      if (dose == null) {
        final updatedExisting = await _updateExistingDoseForSlot(
          planId: planId,
          scheduledFor: scheduledFor,
          status: status,
          takenAt: takenAt,
          mediaUrl: resolvedMediaUrl,
        );
        if (!updatedExisting) {
          _lastDoseError = _service.lastError ??
              'Dose save failed. Supabase did not return an insertable row.';
          return false;
        }
      }

      await loadTodaySchedule();
      await loadStats();
      await _syncMedicationReminders();
      return true;
    } catch (error) {
      _lastDoseError = _service.lastError ?? error.toString();
      return false;
    }
  }

  Future<Dose?> _persistMissedDose({
    required String planId,
    required DateTime scheduledFor,
  }) async {
    if (_patient == null) return null;

    try {
      final inserted = await _service.logDose({
        'plan_id': planId,
        'status': DoseStatus.missed.name,
        'scheduled_for': scheduledFor.toIso8601String(),
        'taken_at': scheduledFor.toIso8601String(),
        'media_url': null,
      });
      if (inserted != null) return inserted;

      final updated = await _updateExistingDoseForSlot(
        planId: planId,
        scheduledFor: scheduledFor,
        status: DoseStatus.missed,
        takenAt: scheduledFor,
        mediaUrl: null,
      );
      if (!updated) return null;

      return await _findDoseForSlot(planId, scheduledFor);
    } catch (error) {
      _lastDoseError = _service.lastError ?? error.toString();
      return null;
    }
  }

  Future<bool> updateDose(
    String doseId,
    DoseStatus status, {
    DateTime? takenAt,
    File? evidenceFile,
    String? mediaUrl,
    required String planId,
    required DateTime scheduledFor,
  }) async {
    try {
      if (_patient == null) return false;

      String? resolvedMediaUrl = mediaUrl;
      if (evidenceFile != null && status == DoseStatus.taken) {
        final uploadedPath = await _service.uploadEvidence(
          _patient!.id,
          planId,
          scheduledFor,
          evidenceFile,
        );
        resolvedMediaUrl = uploadedPath ?? mediaUrl;
      }

      await _service.updateDose(doseId, {
        'status': status.name,
        'taken_at': (status == DoseStatus.taken || status == DoseStatus.skipped)
            ? (takenAt ?? DateTime.now()).toIso8601String()
            : null,
        if (resolvedMediaUrl != null) 'media_url': resolvedMediaUrl,
      });

      await loadTodaySchedule();
      await loadStats();
      await _syncMedicationReminders();
      return true;
    } catch (error) {
      _lastDoseError = _service.lastError ?? error.toString();
      final updatedExisting = await _updateExistingDoseForSlot(
        planId: planId,
        scheduledFor: scheduledFor,
        status: status,
        takenAt: takenAt,
        mediaUrl: mediaUrl,
      );
      if (updatedExisting) {
        await loadTodaySchedule();
        await loadStats();
        await _syncMedicationReminders();
        return true;
      }
      return false;
    }
  }

  Future<Dose?> _findDoseForSlot(String planId, DateTime scheduledFor) async {
    if (_patient == null) return null;

    final dayStart = _dateOnly(scheduledFor);
    final doses =
        await _service.getDosesForPatient(_patient!.id, date: dayStart);
    for (final dose in doses) {
      if (dose.planId != planId) continue;
      final slot = dose.scheduledFor;
      if (slot == null) continue;
      if (_isSameMinute(slot, scheduledFor)) {
        return dose;
      }
    }
    return null;
  }

  Future<bool> _updateExistingDoseForSlot({
    required String planId,
    required DateTime scheduledFor,
    required DoseStatus status,
    DateTime? takenAt,
    String? mediaUrl,
  }) async {
    try {
      final existing = await _findDoseForSlot(planId, scheduledFor);
      if (existing == null || existing.id.isEmpty) return false;

      await _service.updateDose(existing.id, {
        'status': status.name,
        'taken_at': (status == DoseStatus.taken || status == DoseStatus.skipped)
            ? (takenAt ?? DateTime.now()).toIso8601String()
            : null,
        if (mediaUrl != null) 'media_url': mediaUrl,
      });
      return true;
    } catch (error) {
      _lastDoseError = _service.lastError ?? error.toString();
      return false;
    }
  }

  Future<void> _syncMedicationReminders() async {
    if (_patient == null || _plans.isEmpty) {
      await _notificationService.clearMedicationReminders();
      return;
    }

    final now = DateTime.now();
    final startDay = _dateOnly(now);
    final endExclusive = startDay.add(Duration(days: _reminderLookaheadDays));

    final doses = await _service.getDosesForPatientInRange(
      _patient!.id,
      startDay,
      endExclusive,
    );
    final doseIndex = _indexDosesByPlanAndDay(doses);

    final reminders = <MedicationReminder>[];

    var day = startDay;
    while (day.isBefore(endExclusive)) {
      for (final plan in _plans) {
        if (!_isPlanScheduledForDate(plan, day)) continue;

        final scheduledTime = _scheduledDateTime(plan, day);
        final key = _planDayKey(plan.id, day);
        final dose = doseIndex[key];
        if (dose != null && dose.status != DoseStatus.pending) {
          continue;
        }

        _addMedicationReminder(
          reminders: reminders,
          plan: plan,
          scheduledTime: scheduledTime,
          offset: _reminderBeforeOffset,
          now: now,
          title: 'Medication reminder',
          body: 'Take ${plan.name} (${plan.dosageLabel}) in one hour.',
          payloadKey: key,
        );
        _addMedicationReminder(
          reminders: reminders,
          plan: plan,
          scheduledTime: scheduledTime,
          offset: _reminderOnTimeOffset,
          now: now,
          title: 'Medication reminder',
          body: 'It is time to take ${plan.name} (${plan.dosageLabel}).',
          payloadKey: key,
        );
        _addMedicationReminder(
          reminders: reminders,
          plan: plan,
          scheduledTime: scheduledTime,
          offset: _reminderAfterOffset,
          now: now,
          title: 'Medication reminder',
          body:
              'You are one hour past ${plan.name} (${plan.dosageLabel}). Please take it now before it is missed.',
          payloadKey: key,
        );
      }

      day = day.add(const Duration(days: 1));
    }

    await _notificationService.syncMedicationReminders(reminders);
  }

  void _addMedicationReminder({
    required List<MedicationReminder> reminders,
    required MedicationPlan plan,
    required DateTime scheduledTime,
    required Duration offset,
    required DateTime now,
    required String title,
    required String body,
    required String payloadKey,
  }) {
    final reminderTime = scheduledTime.add(offset);
    if (!reminderTime.isAfter(now)) return;

    final reminderId = _reminderNotificationId(
      plan.id,
      scheduledTime,
      offset.inMinutes,
    );
    reminders.add(
      MedicationReminder(
        notificationId: reminderId,
        title: title,
        body: body,
        scheduledAt: reminderTime,
        payload: NotificationService.medicationPayloadFor(payloadKey),
      ),
    );
  }

  int _reminderNotificationId(
    String planId,
    DateTime scheduledTime,
    int offsetMinutes,
  ) {
    return Object.hash(
          planId,
          scheduledTime.toIso8601String(),
          offsetMinutes,
        ) &
        0x7fffffff;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _scheduledDateTime(MedicationPlan plan, DateTime day) {
    final parts = plan.time.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  Dose? _effectiveDoseForSchedule(
    Dose? dose,
    DateTime scheduledTime,
    DateTime selectedDate,
    DateTime todayOnly,
    DateTime now,
  ) {
    if (dose != null && dose.status != DoseStatus.pending) return dose;

    final missedThreshold = scheduledTime.add(const Duration(hours: 2));
    final isPastDay = selectedDate.isBefore(todayOnly);
    final isToday = _isSameDay(selectedDate, todayOnly);
    final shouldBeMissed =
        isPastDay || (isToday && !now.isBefore(missedThreshold));

    if (!shouldBeMissed) return dose;

    return Dose(
      id: dose?.id ?? '',
      takenAt: dose?.takenAt ?? scheduledTime,
      scheduledFor: scheduledTime,
      status: DoseStatus.missed,
      mediaUrl: dose?.mediaUrl,
      planId: dose?.planId ?? '',
    );
  }

  Map<String, Dose> _indexDosesByPlanForDay(List<Dose> doses) {
    final result = <String, Dose>{};
    for (final dose in doses) {
      final existing = result[dose.planId];
      if (existing == null || _shouldReplaceDose(existing, dose)) {
        result[dose.planId] = dose;
      }
    }
    return result;
  }

  Map<String, Dose> _indexDosesByPlanAndDay(List<Dose> doses) {
    final result = <String, Dose>{};
    for (final dose in doses) {
      final scheduledDay =
          dose.scheduledFor != null ? _dateOnly(dose.scheduledFor!) : null;
      if (scheduledDay == null) continue;
      final key = _planDayKey(dose.planId, scheduledDay);
      final existing = result[key];
      if (existing == null || _shouldReplaceDose(existing, dose)) {
        result[key] = dose;
      }
    }
    return result;
  }

  bool _shouldReplaceDose(Dose current, Dose candidate) {
    final currentPriority = _dosePriority(current.status);
    final candidatePriority = _dosePriority(candidate.status);
    if (candidatePriority != currentPriority) {
      return candidatePriority > currentPriority;
    }

    final currentTime = current.takenAt ??
        current.scheduledFor ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final candidateTime = candidate.takenAt ??
        candidate.scheduledFor ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return candidateTime.isAfter(currentTime);
  }

  int _dosePriority(DoseStatus status) {
    switch (status) {
      case DoseStatus.taken:
        return 3;
      case DoseStatus.skipped:
        return 2;
      case DoseStatus.missed:
        return 1;
      default:
        return 0;
    }
  }

  Map<String, int> _getDoseStatsForRangeFromIndex(
    DateTime startDate,
    DateTime endDate,
    Map<String, Dose> doseIndex,
    DateTime now,
  ) {
    int taken = 0;
    int skipped = 0;
    int missed = 0;
    int pending = 0;
    int expected = 0;

    final todayOnly = _dateOnly(now);
    var day = _dateOnly(startDate);
    final end = _dateOnly(endDate);

    while (!day.isAfter(end)) {
      for (final plan in _plans) {
        if (!_isPlanScheduledForDate(plan, day)) continue;

        expected++;
        final scheduledTime = _scheduledDateTime(plan, day);
        final key = _planDayKey(plan.id, day);
        final dose = doseIndex[key];

        if (dose != null && dose.status != DoseStatus.pending) {
          if (dose.status == DoseStatus.taken) {
            taken++;
          } else if (dose.status == DoseStatus.skipped) {
            skipped++;
          } else if (dose.status == DoseStatus.missed) {
            missed++;
          }
          continue;
        }

        final missedThreshold = scheduledTime.add(const Duration(hours: 2));
        final isPastDay = day.isBefore(todayOnly);
        final isToday = _isSameDay(day, todayOnly);
        if (isPastDay || (isToday && !now.isBefore(missedThreshold))) {
          missed++;
        } else {
          pending++;
        }
      }

      day = day.add(const Duration(days: 1));
    }

    return {
      'taken': taken,
      'skipped': skipped,
      'missed': missed,
      'pending': pending,
      'expected': expected,
    };
  }

  String _planDayKey(String planId, DateTime day) {
    final normalized = _dateOnly(day);
    final mm = normalized.month.toString().padLeft(2, '0');
    final dd = normalized.day.toString().padLeft(2, '0');
    return '$planId:${normalized.year}-$mm-$dd';
  }

  bool _isPlanScheduledForDate(MedicationPlan plan, DateTime selectedDate) {
    final start = _dateOnly(plan.startDate);
    final end = plan.endDate == null ? null : _dateOnly(plan.endDate!);

    if (selectedDate.isBefore(start)) return false;
    if (end != null && selectedDate.isAfter(end)) return false;

    return plan.frequency.contains(_weekdayToken(selectedDate.weekday));
  }

  String _weekdayToken(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'mo';
      case DateTime.tuesday:
        return 'tu';
      case DateTime.wednesday:
        return 'we';
      case DateTime.thursday:
        return 'th';
      case DateTime.friday:
        return 'fr';
      case DateTime.saturday:
        return 'sa';
      case DateTime.sunday:
        return 'su';
      default:
        return '';
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSameMinute(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day &&
        a.hour == b.hour &&
        a.minute == b.minute;
  }
}
