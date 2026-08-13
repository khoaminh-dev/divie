import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const apiBaseUrl = String.fromEnvironment(
    'DIVIE_API_BASE_URL',
    defaultValue: 'https://api.divie.site',
  );
  static const voiceBaseUrl = String.fromEnvironment(
    'DIVIE_VOICE_BASE_URL',
    defaultValue: 'https://chat.divie.site',
  );

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static void assertSafeConfiguration() {
    if (kReleaseMode && !hasSupabaseConfig) {
      throw StateError(
        'Thiếu SUPABASE_URL hoặc SUPABASE_ANON_KEY cho bản phát hành.',
      );
    }
  }
}
