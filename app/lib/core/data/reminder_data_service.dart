import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/reminders/reminder_model.dart';
import '../../features/reminders/reminder_store.dart';

class ReminderDataService {
  ReminderDataService({this.client, this.allowLocalFallback = true});

  final SupabaseClient? client;
  final bool allowLocalFallback;
  final ReminderStore _local = ReminderStore();
  bool _localMigrationAttempted = false;

  bool get isRemote => client != null && client!.auth.currentUser != null;

  Future<List<MedicineReminder>> load() async {
    if (!isRemote) {
      if (!allowLocalFallback) {
        throw StateError('medicine_reminders_remote_unavailable');
      }
      return _local.load();
    }

    await _migrateLocalReminders();
    final rows = await client!
        .from('medicine_reminders')
        .select('id,name,time,note,enabled')
        .eq('account_id', client!.auth.currentUser!.id)
        .order('time');
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(MedicineReminder.fromJson)
        .toList();
  }

  Future<MedicineReminder> create(MedicineReminder item) async {
    if (!isRemote) {
      if (!allowLocalFallback) {
        throw StateError('medicine_reminders_remote_unavailable');
      }
      final current = await _local.load();
      await _local.save([...current, item]);
      return item;
    }
    final row = await client!
        .from('medicine_reminders')
        .insert({
          'account_id': client!.auth.currentUser!.id,
          'name': item.name,
          'time': item.time,
          'note': item.note,
          'enabled': item.enabled,
        })
        .select('id,name,time,note,enabled')
        .single();
    return MedicineReminder.fromJson(row);
  }

  Future<void> update(MedicineReminder item) async {
    if (!isRemote) {
      if (!allowLocalFallback) {
        throw StateError('medicine_reminders_remote_unavailable');
      }
      final current = await _local.load();
      await _local.save(
        current.map((value) => value.id == item.id ? item : value).toList(),
      );
      return;
    }
    await client!
        .from('medicine_reminders')
        .update({
          'name': item.name,
          'time': item.time,
          'note': item.note,
          'enabled': item.enabled,
        })
        .eq('id', item.id)
        .eq('account_id', client!.auth.currentUser!.id);
  }

  Future<void> delete(MedicineReminder item) async {
    if (!isRemote) {
      if (!allowLocalFallback) {
        throw StateError('medicine_reminders_remote_unavailable');
      }
      final current = await _local.load();
      await _local.save(current.where((value) => value.id != item.id).toList());
      return;
    }
    await client!
        .from('medicine_reminders')
        .delete()
        .eq('id', item.id)
        .eq('account_id', client!.auth.currentUser!.id);
  }

  Future<Map<int, String>> loadStatuses(DateTime day) async {
    final date = _dateValue(day);
    if (!isRemote) {
      if (!allowLocalFallback) {
        throw StateError('medicine_reminders_remote_unavailable');
      }
      final prefs = await SharedPreferences.getInstance();
      final result = <int, String>{};
      for (final item in await _local.load()) {
        final value = prefs.getString(_statusKey(item.id, date));
        if (value != null) result[item.id] = value;
      }
      return result;
    }
    final rows = await client!
        .from('medicine_reminder_events')
        .select('reminder_id,status')
        .eq('account_id', client!.auth.currentUser!.id)
        .eq('scheduled_on', date);
    return <int, String>{
      for (final row in (rows as List).whereType<Map<String, dynamic>>())
        (row['reminder_id'] as num).toInt(): row['status'] as String,
    };
  }

  Future<void> recordStatus({
    required MedicineReminder reminder,
    required DateTime day,
    required String status,
  }) async {
    final date = _dateValue(day);
    if (!isRemote) {
      if (!allowLocalFallback) {
        throw StateError('medicine_reminders_remote_unavailable');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_statusKey(reminder.id, date), status);
      return;
    }
    await client!.from('medicine_reminder_events').upsert({
      'account_id': client!.auth.currentUser!.id,
      'reminder_id': reminder.id,
      'scheduled_on': date,
      'status': status,
      'taken_at': status == 'taken'
          ? DateTime.now().toUtc().toIso8601String()
          : null,
    }, onConflict: 'account_id,reminder_id,scheduled_on');
  }

  static String _dateValue(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static String _statusKey(int reminderId, String date) =>
      'divie.reminder_status.$date.$reminderId';

  Future<void> _migrateLocalReminders() async {
    if (_localMigrationAttempted || !isRemote) return;
    _localMigrationAttempted = true;

    final localItems = await _local.load();
    if (localItems.isEmpty) return;

    try {
      final remoteRows = await client!
          .from('medicine_reminders')
          .select('name,time,note,enabled')
          .eq('account_id', client!.auth.currentUser!.id);
      final existingKeys = (remoteRows as List)
          .whereType<Map<String, dynamic>>()
          .map(_reminderKey)
          .toSet();
      final pending = localItems
          .where((item) => !existingKeys.contains(_reminderKey(item)))
          .map(
            (item) => {
              'account_id': client!.auth.currentUser!.id,
              'name': item.name,
              'time': item.time,
              'note': item.note,
              'enabled': item.enabled,
            },
          )
          .toList();

      if (pending.isNotEmpty) {
        await client!.from('medicine_reminders').insert(pending);
      }
      await _local.save([]);
    } catch (error) {
      // Keep local data if the one-time migration cannot reach Supabase.
      // The next successful load will retry it.
      _localMigrationAttempted = false;
      debugPrint('DiVie reminder local migration skipped: $error');
    }
  }

  static String _reminderKey(Object value) {
    if (value is MedicineReminder) {
      return '${value.name.trim().toLowerCase()}|${value.time}|${value.note.trim().toLowerCase()}|${value.enabled}';
    }
    final row = value as Map<String, dynamic>;
    return '${(row['name'] as String? ?? '').trim().toLowerCase()}|${row['time'] as String? ?? ''}|${(row['note'] as String? ?? '').trim().toLowerCase()}|${row['enabled'] as bool? ?? true}';
  }
}
