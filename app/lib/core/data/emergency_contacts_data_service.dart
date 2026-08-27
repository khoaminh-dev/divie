import 'package:supabase_flutter/supabase_flutter.dart';

import '../device/emergency_contacts_store.dart';

/// Keeps emergency contacts on the signed-in account and caches them locally
/// so the emergency screen is still usable while the device is offline.
class EmergencyContactsDataService {
  EmergencyContactsDataService({this.client});

  final SupabaseClient? client;
  final EmergencyContactsStore _local = EmergencyContactsStore();

  bool get isRemote => client != null && client!.auth.currentUser != null;

  Future<List<EmergencyContact>> load() async {
    final cached = await _local.load();
    if (!isRemote) return cached;

    try {
      final userId = client!.auth.currentUser!.id;
      final row = await client!
          .from('divie_emergency_contacts')
          .select('contacts, numbers')
          .eq('account_id', userId)
          .maybeSingle();
      final contacts = _contactsFromRow(row);

      // One-time migration for contacts that were entered before account sync
      // was available.
      if (contacts.isEmpty && cached.isNotEmpty) {
        await save(cached);
        return cached;
      }
      return contacts;
    } catch (_) {
      // Keep the emergency screen usable if the device temporarily loses the
      // network or the migration has not been applied on the backend yet.
      return cached;
    }
  }

  Future<void> save(List<EmergencyContact> contacts) async {
    final cleaned = contacts
        .map((contact) => contact.cleaned())
        .where((contact) => contact.phone.isNotEmpty)
        .take(5)
        .toList();
    await _local.save(cleaned);

    if (!isRemote) return;
    await client!.from('divie_emergency_contacts').upsert({
      'account_id': client!.auth.currentUser!.id,
      'contacts': cleaned.map((contact) => contact.toJson()).toList(),
      'numbers': cleaned.map((contact) => contact.phone).toList(),
    }, onConflict: 'account_id');
  }

  List<EmergencyContact> _contactsFromRow(Map<String, dynamic>? row) {
    final structured =
        (row?['contacts'] as List?)
            ?.map(EmergencyContact.fromJson)
            .whereType<EmergencyContact>()
            .take(5)
            .toList() ??
        const <EmergencyContact>[];
    if (structured.isNotEmpty) return structured;
    return (row?['numbers'] as List?)
            ?.whereType<String>()
            .map((phone) => EmergencyContact(name: '', phone: phone.trim()))
            .where((contact) => contact.phone.isNotEmpty)
            .take(5)
            .toList() ??
        const <EmergencyContact>[];
  }
}
