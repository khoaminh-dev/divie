import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_model.dart';

class ReminderNotificationStatus {
  const ReminderNotificationStatus({
    required this.notificationsEnabled,
    required this.exactAlarmsAllowed,
    required this.reminderChannelEnabled,
    required this.pendingCount,
  });

  final bool notificationsEnabled;
  final bool exactAlarmsAllowed;
  final bool reminderChannelEnabled;
  final int pendingCount;

  bool get isReady => notificationsEnabled && reminderChannelEnabled;
}

class NotificationService {
  NotificationService._();

  // Android locks a channel's sound settings after its first creation. A new
  // ID restores the audible alarm channel for devices that had the old one
  // muted or created without the correct audio usage.
  static const _channelId = 'medicine_reminders_alarm_v4';
  static const _channelName = 'Nhắc thuốc';
  static const _channelDescription = 'Thông báo nhắc uống thuốc có chuông';

  static final instance = NotificationService._();
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _initialization;

  AndroidNotificationChannel get _channel => AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDescription,
    importance: Importance.max,
    playSound: true,
    sound: const RawResourceAndroidNotificationSound('divie_alarm'),
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 500, 260, 750]),
    audioAttributesUsage: AudioAttributesUsage.alarm,
  );

  NotificationDetails get _notificationDetails => NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('divie_alarm'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 260, 750]),
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
    ),
    iOS: const DarwinNotificationDetails(),
  );

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    // Android notifications need a dedicated drawable icon. The adaptive
    // launcher icon is not a valid small-notification icon on newer Android
    // versions, which prevented notification initialization on real devices.
    const android = AndroidInitializationSettings('ic_notification');
    const darwin = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
    );
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.createNotificationChannel(_channel);
  }

  Future<void> schedule(MedicineReminder reminder) async {
    await initialize();
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
    final scheduleMode = await _scheduleMode(androidPlugin);
    await _plugin.zonedSchedule(
      _notificationId(reminder.id),
      'Đến giờ uống thuốc',
      reminder.note.isEmpty
          ? reminder.name
          : '${reminder.name} · ${reminder.note}',
      next,
      _notificationDetails,
      androidScheduleMode: scheduleMode,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'medicine:${reminder.id}',
    );
  }

  /// A notification permission/device problem must not make a saved reminder
  /// look like it failed to create.
  Future<bool> trySchedule(MedicineReminder reminder) async {
    try {
      if (!await _ensureNotificationsEnabled()) return false;
      await schedule(reminder);
      return true;
    } catch (error, stackTrace) {
      debugPrint('DiVie notification schedule failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> showTestNotification() async {
    try {
      if (!await _ensureNotificationsEnabled()) return false;
      await _plugin.show(
        2147483646,
        'DiVie đã bật nhắc thuốc',
        'Đây là thông báo kiểm tra trên điện thoại này.',
        _notificationDetails,
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint('DiVie notification test failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  /// Schedules one additional reminder without changing the daily reminder.
  /// This is used when the elder taps "Để sau" for today's dose.
  Future<tz.TZDateTime?> snooze(MedicineReminder reminder) async {
    try {
      if (!await _ensureNotificationsEnabled()) return null;
      await _plugin.cancel(_snoozeNotificationId(reminder.id));
      final scheduledAt = tz.TZDateTime.now(
        tz.local,
      ).add(const Duration(minutes: 10));
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await _plugin.zonedSchedule(
        _snoozeNotificationId(reminder.id),
        'Nhắc lại uống thuốc',
        reminder.note.isEmpty
            ? reminder.name
            : '${reminder.name} · ${reminder.note}',
        scheduledAt,
        _notificationDetails,
        androidScheduleMode: await _scheduleMode(androidPlugin),
        payload: 'medicine:snooze:${reminder.id}',
      );
      return scheduledAt;
    } catch (error, stackTrace) {
      debugPrint('DiVie reminder snooze failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<bool> _ensureNotificationsEnabled() async {
    await initialize();
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return true;

    var enabled = await androidPlugin.areNotificationsEnabled();
    if (enabled == false) {
      await androidPlugin.requestNotificationsPermission();
      enabled = await androidPlugin.areNotificationsEnabled();
    }
    if (enabled == false) return false;
    try {
      final channels = await androidPlugin.getNotificationChannels();
      final channel = channels
          ?.where((item) => item.id == _channelId)
          .firstOrNull;
      return channel?.importance != Importance.none;
    } catch (_) {
      return true;
    }
  }

  Future<bool> requestExactAlarmPermission() async {
    await initialize();
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return true;
    try {
      final allowed = await androidPlugin.canScheduleExactNotifications();
      if (allowed != false) return true;
      await androidPlugin.requestExactAlarmsPermission();
      return await androidPlugin.canScheduleExactNotifications() == true;
    } catch (_) {
      return false;
    }
  }

  Future<ReminderNotificationStatus> status() async {
    await initialize();
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) {
      return ReminderNotificationStatus(
        notificationsEnabled: true,
        exactAlarmsAllowed: true,
        reminderChannelEnabled: true,
        pendingCount: (await _plugin.pendingNotificationRequests()).length,
      );
    }
    final notificationsEnabled =
        await androidPlugin.areNotificationsEnabled() != false;
    final exactAlarmsAllowed =
        await androidPlugin.canScheduleExactNotifications() != false;
    var reminderChannelEnabled = true;
    try {
      final channels = await androidPlugin.getNotificationChannels();
      final channel = channels
          ?.where((item) => item.id == _channelId)
          .firstOrNull;
      reminderChannelEnabled = channel?.importance != Importance.none;
    } catch (_) {
      // Channel checks are unavailable on a few Android versions.
    }
    return ReminderNotificationStatus(
      notificationsEnabled: notificationsEnabled,
      exactAlarmsAllowed: exactAlarmsAllowed,
      reminderChannelEnabled: reminderChannelEnabled,
      pendingCount: (await _plugin.pendingNotificationRequests()).length,
    );
  }

  Future<tz.TZDateTime?> scheduleTestAfterOneMinute() async {
    try {
      if (!await _ensureNotificationsEnabled()) return null;
      await cancel(_testNotificationId);
      final scheduledAt = tz.TZDateTime.now(
        tz.local,
      ).add(const Duration(minutes: 1));
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await _plugin.zonedSchedule(
        _testNotificationId,
        'DiVie đang kiểm tra nhắc thuốc',
        'Nếu bác nghe được chuông này, nhắc thuốc đã hoạt động.',
        scheduledAt,
        _notificationDetails,
        androidScheduleMode: await _scheduleMode(androidPlugin),
        payload: 'medicine:test',
      );
      return scheduledAt;
    } catch (error, stackTrace) {
      debugPrint('DiVie scheduled notification test failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<AndroidScheduleMode> _scheduleMode(
    AndroidFlutterLocalNotificationsPlugin? androidPlugin,
  ) async {
    try {
      if (await androidPlugin?.canScheduleExactNotifications() == true) {
        return AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (_) {
      // Devices without the exact-alarm API still receive an idle-safe alarm.
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> cancel(int id) => _plugin.cancel(_notificationId(id));

  Future<void> cancelSnooze(int id) =>
      _plugin.cancel(_snoozeNotificationId(id));

  Future<void> cancelAll() => _plugin.cancelAll();

  static const _testNotificationId = 2147483645;

  // Android notification IDs are 32-bit integers. Remote rows normally use a
  // small sequence, while offline/voice-created reminders use millisecond
  // timestamps, so normalize both sources to one safe ID space.
  int _notificationId(int id) {
    final normalized = id.abs().remainder(2147483647);
    return normalized == 0 ? 1 : normalized;
  }

  int _snoozeNotificationId(int id) {
    final normalized = id.abs().remainder(1073741823);
    return 1073741824 + normalized;
  }
}
