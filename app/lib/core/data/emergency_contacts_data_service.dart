import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../device/emergency_contacts_store.dart';

/// Keeps emergency contacts on the signed-in account and caches them locally
/// so the emergency screen is still usable while the device is offline.
class EmergencyContactsDataService {
  EmergencyContactsDataService({this.client});

  final SupabaseClient? client;
  final EmergencyContactsStore _local = EmergencyContactsStore();

  bool get isRemote => client != null && client!.auth.currentUser != null;

  Future<List<String>> load() async {
    final cached = await _local.load();
    if (!isRemote) return cached;

    try {
      final userId = client!.auth.currentUser!.id;
      final row = await client!
          .from('divie_emergency_contacts')
          .select('numbers')
          .eq('account_id', userId)
          .maybeSingle();
      final numbers =
          (row?['numbers'] as List?)
              ?.whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .take(5)
              .toList() ??
          <String>[];

      // One-time migration for contacts that were entered before account sync
      // was available.
      if (numbers.isEmpty && cached.isNotEmpty) {
        await save(cached);
        return cached;
      }
      return numbers;
    } catch (_) {
      // Keep the emergency screen usable if the device temporarily loses the
      // network or the migration has not been applied on the backend yet.
      return cached;
    }
  }

  Future<void> save(List<String> contacts) async {
    final cleaned = contacts
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .take(5)
        .toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('divie_emergency_contacts', cleaned);

    if (!isRemote) return;
    await client!.from('divie_emergency_contacts').upsert({
      'account_id': client!.auth.currentUser!.id,
      'numbers': cleaned,
    }, onConflict: 'account_id');
  }
}
