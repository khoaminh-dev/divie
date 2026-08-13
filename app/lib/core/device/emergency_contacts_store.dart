import 'package:shared_preferences/shared_preferences.dart';

class EmergencyContactsStore {
  static const _key = 'divie_emergency_contacts';

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? <String>[];
  }

  Future<void> save(List<String> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      contacts.map((value) => value.trim()).where((value) => value.isNotEmpty).take(5).toList(),
    );
  }
}
