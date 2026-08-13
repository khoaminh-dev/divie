import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../roles/app_role.dart';

class DeviceRegistrationService {
  DeviceRegistrationService({this.client});

  final SupabaseClient? client;

  static const _deviceIdKey = 'divie.device_id';

  bool get isReady => client?.auth.currentUser != null;

  Future<void> syncRole(AppRole role) async {
    if (!isReady) return;

    final user = client!.auth.currentUser!;
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await _deviceId(prefs);

    await client!.from('divie_account_devices').upsert(
      {
        'account_id': user.id,
        'device_id': deviceId,
        'role': role.storageValue == 'family' ? 'caregiver' : 'elder',
        'platform': 'android',
        'is_active': true,
        'app_version': '1.0.0',
      },
      onConflict: 'account_id,device_id',
    );
  }

  Future<String> _deviceId(SharedPreferences prefs) async {
    final saved = prefs.getString(_deviceIdKey);
    if (saved != null && saved.isNotEmpty) return saved;

    final random = Random.secure();
    final value = List<String>.generate(
      24,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    final deviceId = 'android-$value';
    await prefs.setString(_deviceIdKey, deviceId);
    return deviceId;
  }
}
