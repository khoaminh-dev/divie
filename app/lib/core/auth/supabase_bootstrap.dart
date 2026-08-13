import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

abstract final class SupabaseBootstrap {
  static bool enabled = false;
  static Object? initializationError;

  static Future<void> initialize() async {
    if (!AppConfig.hasSupabaseConfig) {
      return;
    }

    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
      );
      enabled = true;
    } catch (error) {
      initializationError = error;
    }
  }
}
