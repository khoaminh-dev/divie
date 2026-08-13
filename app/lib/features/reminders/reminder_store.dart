import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'reminder_model.dart';

class ReminderStore {
  static const _key = 'divie.medicine_reminders';

  Future<List<MedicineReminder>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(MedicineReminder.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<MedicineReminder> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(reminders.map((item) => item.toJson()).toList()),
    );
  }
}
