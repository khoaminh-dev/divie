import 'package:supabase_flutter/supabase_flutter.dart';

class AccountProfile {
  const AccountProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
}

/// Loads the signed-in account identity. Demo names are never returned.
class AccountProfileService {
  AccountProfileService(this.client);

  final SupabaseClient client;

  /// Makes sure every authenticated account can appear in the real contacts
  /// list and can be used as a chat participant.
  Future<void> ensureCurrentProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return;

    Map<String, dynamic>? existing;
    try {
      existing = await client
          .from('profiles')
          .select('full_name, email, phone_number')
          .eq('id', user.id)
          .maybeSingle();
    } on PostgrestException {
      // A profile policy may temporarily prevent reading the row. The auth
      // session is still valid, so do not block sign-in for this best effort.
    }

    final email = _first([user.email, _string(existing?['email'])]);
    final fullName = _first([
      _string(existing?['full_name']),
      _string(user.userMetadata?['full_name']),
      _string(user.userMetadata?['name']),
      _nameFromEmail(email),
    ]);
    final phone = _first([
      _string(existing?['phone_number']),
      user.phone,
      _string(user.userMetadata?['phone_number']),
      _string(user.userMetadata?['phone']),
    ]);

    try {
      await client.from('profiles').upsert({
        'id': user.id,
        'full_name': fullName,
        'email': email,
        if (phone != 'Người dùng DiVie') 'phone_number': phone,
      }, onConflict: 'id');
    } on PostgrestException {
      // Keep the app usable even when profile RLS is still being configured.
    }
  }

  Future<AccountProfile> loadCurrent() async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Phiên đăng nhập không tồn tại.');

    Map<String, dynamic>? profile;
    try {
      profile = await client
          .from('profiles')
          .select('id, full_name, email, phone_number')
          .eq('id', user.id)
          .maybeSingle();
    } on PostgrestException {
      profile = null;
    }

    final email = _first([user.email, _string(profile?['email'])]);
    final name = _first([
      _string(profile?['full_name']),
      _string(user.userMetadata?['full_name']),
      _string(user.userMetadata?['name']),
      _nameFromEmail(email),
    ]);

    return AccountProfile(
      id: user.id,
      name: name,
      email: email,
      phone: _first([
        _string(profile?['phone_number']),
        user.phone,
        _string(user.userMetadata?['phone_number']),
        _string(user.userMetadata?['phone']),
      ]),
    );
  }

  static String _first(Iterable<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return 'Người dùng DiVie';
  }

  static String _string(Object? value) => value is String ? value.trim() : '';

  static String _nameFromEmail(String email) {
    final value = email.split('@').first.trim();
    return value.isEmpty ? 'Người dùng DiVie' : value;
  }
}
