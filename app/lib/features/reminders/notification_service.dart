import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_model.dart';

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();
  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
    );
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'medicine_reminders',
        'Nhắc thuốc',
        description: 'Thông báo nhắc uống thuốc',
        importance: Importance.max,
      ),
    );
  }

  Future<void> schedule(MedicineReminder reminder) async {
    await cancel(reminder.id);
    if (!reminder.enabled) return;
    final parts = reminder.time.split(':');
    final hour = int.tryParse(parts.first) ?? 8;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    var scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      final canScheduleExactly = await androidPlugin
          ?.canScheduleExactNotifications();
      if (canScheduleExactly == false) {
        await androidPlugin?.requestExactAlarmsPermission();
      }
      if (await androidPlugin?.canScheduleExactNotifications() == true) {
        scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (_) {
      // Android versions that do not expose this permission still receive an
      // inexact reminder instead of failing to create the medicine schedule.
    }
    await _plugin.zonedSchedule(
      _notificationId(reminder.id),
      'Đến giờ uống thuốc',
      reminder.note.isEmpty
          ? reminder.name
          : '${reminder.name} · ${reminder.note}',
      next,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medicine_reminders',
          'Nhắc thuốc',
          channelDescription: 'Thông báo nhắc uống thuốc',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: scheduleMode,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'medicine:${reminder.id}',
    );
  }

  /// A notification permission/device problem must not make a saved reminder
  /// look like it failed to create.
  Future<bool> trySchedule(MedicineReminder reminder) async {
    try {
      await schedule(reminder);
      return true;
    } catch (error, stackTrace) {
      debugPrint('DiVie notification schedule failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> cancel(int id) => _plugin.cancel(_notificationId(id));

  Future<void> cancelAll() => _plugin.cancelAll();

  // Android notification IDs are 32-bit integers. Remote rows normally use a
  // small sequence, while offline/voice-created reminders use millisecond
  // timestamps, so normalize both sources to one safe ID space.
  int _notificationId(int id) {
    final normalized = id.abs().remainder(2147483647);
    return normalized == 0 ? 1 : normalized;
  }
}
