import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static const Duration _requestTimeout = Duration(seconds: 15);
  static const Duration _authRequestTimeout = Duration(seconds: 45);
  static const Duration _authReachabilityTimeout = Duration(seconds: 6);

  final _client = Supabase.instance.client;
  String? _lastError;

  String? get lastError => _lastError;

  Future<T> _withTimeout<T>(Future<T> future) {
    return future.timeout(_requestTimeout);
  }

  // Auth
  Future<void> _ensureAuthHostReachable() async {
    final projectUrl = dotenv.maybeGet('PROJECT_URL')?.trim();
    if (projectUrl == null || projectUrl.isEmpty) {
      throw const SocketException('Missing PROJECT_URL configuration.');
    }

    final host = Uri.parse(projectUrl).host;
    if (host.isEmpty) {
      throw const SocketException('Invalid Supabase URL host.');
    }

    final addresses = await InternetAddress.lookup(host).timeout(
      _authReachabilityTimeout,
      onTimeout: () => throw const SocketException(
        'Supabase host lookup timed out. Device network path unavailable.',
      ),
    );
    if (addresses.isEmpty || addresses.first.rawAddress.isEmpty) {
      throw const SocketException('Cannot resolve Supabase host.');
    }
  }

  Future<AuthResponse> signIn(String email, String password) async {
    await _ensureAuthHostReachable();

    Future<AuthResponse> attempt() {
      return _client.auth
          .signInWithPassword(email: email, password: password)
          .timeout(_authRequestTimeout);
    }

    for (var i = 0; i < 3; i++) {
      try {
        return await attempt();
      } on TimeoutException {
        if (i == 2) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
    }

    throw TimeoutException('Sign-in timed out.');
  }

  Future<void> signOut() => _withTimeout(_client.auth.signOut());

  User? get currentUser => _client.auth.currentUser;

  //Profile
  Future<Profile?> getProfile(String userId) async {
    try {
      final data = await _withTimeout(_client
          .from('profile')
          .select()
          .eq('id', userId)
          .limit(1)
          .maybeSingle());
      if (data == null) return null;
      return Profile.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  //Patient
  Future<Patient?> getPatient(String userId) async {
    try {
      final data = await _withTimeout(_client
          .from('patient')
          .select()
          .eq('id', userId)
          .limit(1)
          .maybeSingle());
      if (data == null) return null;
      return Patient.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  //Medication Plans
  Future<List<MedicationPlan>> getMedicationPlans(String patientId) async {
    try {
      final data = await _withTimeout(_client
          .from('medication_plan')
          .select()
          .eq('patient_id', patientId)
          .order('time'));
      final rows = (data as List).cast<dynamic>();
      final plans = <MedicationPlan>[];
      for (final row in rows) {
        try {
          plans.add(MedicationPlan.fromJson(row as Map<String, dynamic>));
        } catch (_) {

        }
      }
      return plans;
    } catch (_) {
      return [];
    }
  }

  //Evidence Storage
  Future<String?> uploadEvidence(
    String patientId,
    String planId,
    DateTime scheduledFor,
    File file,
  ) async {
    _lastError = null;
    try {
      final extension = _evidenceExtension(file.path);
      final scheduledFolder = scheduledFor
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final storagePath =
          '$patientId/$planId/$scheduledFolder/evidence$extension';

      await _withTimeout(_client.storage.from('intake-media').upload(
            storagePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          ));

      return storagePath;
    } catch (error) {
      _lastError = 'uploadEvidence failed: $error';
      debugPrint(_lastError);
      return null;
    }
  }

  Future<String?> getEvidenceUrl(String path) async {
    if (path.isEmpty) return null;

    try {
      return await _withTimeout(
          _client.storage.from('intake-media').createSignedUrl(path, 3600));
    } catch (_) {
      return null;
    }
  }

  //Doses
  Future<List<Dose>> getDosesForPlan(String planId) async {
    _lastError = null;
    try {
      final data = await _withTimeout(_client
          .from('dose')
          .select()
          .eq('plan_id', planId)
          .order('scheduled_for', ascending: false));
      return (data as List).map((e) => Dose.fromJson(e)).toList();
    } catch (error) {
      _lastError = 'getDosesForPlan failed: $error';
      debugPrint(_lastError);
      return [];
    }
  }

  Future<List<Dose>> getDosesForPatient(String patientId,
      {DateTime? date}) async {
    _lastError = null;
    try {
      var query = _client
          .from('dose')
          .select('*, medication_plan!inner(patient_id)')
          .eq('medication_plan.patient_id', patientId);

      if (date != null) {
        final start = DateTime(date.year, date.month, date.day);
        final end = start.add(const Duration(days: 1));
        query = query
            .gte('scheduled_for', start.toIso8601String())
            .lt('scheduled_for', end.toIso8601String());
      }

      final data =
          await _withTimeout(query.order('scheduled_for', ascending: false));
      return (data as List).map((e) => Dose.fromJson(e)).toList();
    } catch (error) {
      _lastError = 'getDosesForPatient failed: $error';
      debugPrint(_lastError);
      return [];
    }
  }

  Future<List<Dose>> getDosesForPatientInRange(
    String patientId,
    DateTime start,
    DateTime end,
  ) async {
    _lastError = null;
    try {
      final data = await _withTimeout(_client
          .from('dose')
          .select('*, medication_plan!inner(patient_id)')
          .eq('medication_plan.patient_id', patientId)
          .gte('scheduled_for', start.toIso8601String())
          .lt('scheduled_for', end.toIso8601String())
          .order('scheduled_for', ascending: false));
      return (data as List).map((e) => Dose.fromJson(e)).toList();
    } catch (error) {
      _lastError = 'getDosesForPatientInRange failed: $error';
      debugPrint(_lastError);
      return [];
    }
  }

  Future<Dose?> logDose(Map<String, dynamic> data) async {
    _lastError = null;
    try {
      final result = await _withTimeout(
          _client.from('dose').insert(data).select().single());
      return Dose.fromJson(result);
    } catch (error) {
      _lastError = 'logDose failed: $error';
      debugPrint(_lastError);
      return null;
    }
  }

  Future<void> updateDose(String doseId, Map<String, dynamic> data) async {
    _lastError = null;
    try {
      await _withTimeout(_client.from('dose').update(data).eq('id', doseId));
    } catch (error) {
      _lastError = 'updateDose failed: $error';
      debugPrint(_lastError);
      rethrow;
    }
  }

  String _evidenceExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return '.png';
    if (lower.endsWith('.mp4')) return '.mp4';
    if (lower.endsWith('.mov')) return '.mov';
    if (lower.endsWith('.jpeg')) return '.jpeg';
    if (lower.endsWith('.jpg')) return '.jpg';
    return '.jpg';
  }

  //Stats
  Future<Map<String, int>> getWeeklyStats(String patientId) async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final stats = <String, int>{};

    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      final start = DateTime(day.year, day.month, day.day);
      final end = start.add(const Duration(days: 1));

      try {
        final taken = await _withTimeout(_client
            .from('dose')
            .select('id, medication_plan!inner(patient_id)')
            .eq('medication_plan.patient_id', patientId)
            .eq('status', 'taken')
            .gte('scheduled_for', start.toIso8601String())
            .lt('scheduled_for', end.toIso8601String()));

        stats['day_$i'] = (taken as List).length;
      } catch (_) {
        stats['day_$i'] = 0;
      }
    }

    return stats;
  }

  Future<int> getDailyStreak(String patientId) async {
    // count consecutive days with at least one taken dose
    int streak = 0;
    DateTime day = DateTime.now();

    for (int i = 0; i < 60; i++) {
      final start = DateTime(day.year, day.month, day.day);
      final end = start.add(const Duration(days: 1));

      try {
        final taken = await _withTimeout(_client
            .from('dose')
            .select('id, medication_plan!inner(patient_id)')
            .eq('medication_plan.patient_id', patientId)
            .eq('status', 'taken')
            .gte('scheduled_for', start.toIso8601String())
            .lt('scheduled_for', end.toIso8601String()));

        if ((taken as List).isEmpty) break;
        streak++;
        day = day.subtract(const Duration(days: 1));
      } catch (_) {
        break;
      }
    }

    return streak;
  }
}
