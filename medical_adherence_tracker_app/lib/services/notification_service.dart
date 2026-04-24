import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class MedicationReminder {
  final int notificationId;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final String payload;

  const MedicationReminder({
    required this.notificationId,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.payload,
  });
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _channelId = 'medication_reminders';
  static const String _channelName = 'Medication reminders';
  static const String _channelDescription =
      'Alerts when it is time to take medication';
  static const String _payloadPrefix = 'medication:';
  static const String _testPayload = 'test:notification';
  static const int _testNotificationId = 990001;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    tz.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {

    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin =
        _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    await initialize();

    bool granted = true;

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final androidResult = await androidPlugin?.requestNotificationsPermission();
    if (androidResult != null) {
      granted = granted && androidResult;
    }

    final iosPlugin =
        _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final iosResult = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (iosResult != null) {
      granted = granted && iosResult;
    }

    return granted;
  }

  Future<bool> hasNotificationPermission() async {
    if (kIsWeb) return false;
    await initialize();

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final androidEnabled = await androidPlugin?.areNotificationsEnabled();
    if (androidEnabled != null) {
      return androidEnabled;
    }

    final iosPlugin =
        _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final iosPermissions = await iosPlugin?.checkPermissions();
    if (iosPermissions != null) {
      return iosPermissions.isEnabled || iosPermissions.isProvisionalEnabled;
    }

    return true;
  }

  Future<void> syncMedicationReminders(List<MedicationReminder> reminders) async {
    if (kIsWeb) return;
    await initialize();
    if (!await hasNotificationPermission()) return;

    final pending = await _plugin.pendingNotificationRequests();
    final currentMedicationIds = pending
        .where((request) => request.payload?.startsWith(_payloadPrefix) ?? false)
        .map((request) => request.id)
        .toSet();

    final desiredIds = reminders.map((e) => e.notificationId).toSet();
    for (final id in currentMedicationIds.difference(desiredIds)) {
      await _plugin.cancel(id);
    }

    for (final reminder in reminders) {
      await _plugin.zonedSchedule(
        reminder.notificationId,
        reminder.title,
        reminder.body,
        tz.TZDateTime.from(reminder.scheduledAt, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: reminder.payload,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> clearMedicationReminders() async {
    if (kIsWeb) return;
    await initialize();

    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.payload?.startsWith(_payloadPrefix) ?? false) {
        await _plugin.cancel(request.id);
      }
    }
  }

  Future<bool> scheduleTestNotification({
    Duration delay = const Duration(seconds: 10),
  }) async {
    if (kIsWeb) return false;
    await initialize();
    await requestPermissions();
    if (!await hasNotificationPermission()) {
      return false;
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.cancel(_testNotificationId);
    final scheduledAt = tz.TZDateTime.now(tz.local).add(delay);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    bool canScheduleExact = false;
    if (androidPlugin != null) {
      await androidPlugin.requestExactAlarmsPermission();
      canScheduleExact = await androidPlugin.canScheduleExactNotifications() ?? false;
    }

    await _plugin.zonedSchedule(
      _testNotificationId,
      'Test reminder',
      'This is a test medication notification.',
      scheduledAt,
      details,
      payload: _testPayload,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: canScheduleExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );

    return true;
  }

  static String medicationPayloadFor(String key) => '$_payloadPrefix$key';
}
