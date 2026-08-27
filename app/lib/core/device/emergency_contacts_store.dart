import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class EmergencyContact {
  const EmergencyContact({required this.name, required this.phone});

  final String name;
  final String phone;

  String get displayName => name.trim().isEmpty ? phone : name.trim();

  EmergencyContact cleaned() =>
      EmergencyContact(name: name.trim(), phone: phone.trim());

  Map<String, String> toJson() => {'name': name.trim(), 'phone': phone.trim()};

  static EmergencyContact? fromJson(Object? value) {
    if (value is! Map) return null;
    final name = value['name'];
    final phone = value['phone'];
    if (phone is! String || phone.trim().isEmpty) return null;
    return EmergencyContact(
      name: name is String ? name.trim() : '',
      phone: phone.trim(),
    );
  }
}

class EmergencyContactsStore {
  static const _legacyKey = 'divie_emergency_contacts';
  static const _contactsKey = 'divie_emergency_contacts_v2';

  Future<List<EmergencyContact>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_contactsKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final contacts = decoded
              .map(EmergencyContact.fromJson)
              .whereType<EmergencyContact>()
              .take(5)
              .toList();
          if (contacts.isNotEmpty) return contacts;
        }
      } catch (_) {
        // Fall through to the legacy locally cached numbers.
      }
    }
    return (prefs.getStringList(_legacyKey) ?? const <String>[])
        .map((phone) => EmergencyContact(name: '', phone: phone.trim()))
        .where((contact) => contact.phone.isNotEmpty)
        .take(5)
        .toList();
  }

  Future<void> save(List<EmergencyContact> contacts) async {
    final cleaned = contacts
        .map((contact) => contact.cleaned())
        .where((contact) => contact.phone.isNotEmpty)
        .take(5)
        .toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _contactsKey,
      jsonEncode(cleaned.map((item) => item.toJson()).toList()),
    );
    await prefs.setStringList(
      _legacyKey,
      cleaned.map((contact) => contact.phone).toList(),
    );
  }
}
