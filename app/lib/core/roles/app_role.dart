import 'package:shared_preferences/shared_preferences.dart';

enum AppRole { family, elder }

extension AppRoleText on AppRole {
  String get label => this == AppRole.family ? 'Người thân' : 'Người cao tuổi';

  String get description => this == AppRole.family
      ? 'Cài đặt thuốc và theo dõi người thân.'
      : 'Xem lịch uống thuốc và xác nhận đã uống.';

  String get storageValue => this == AppRole.family ? 'family' : 'elder';

  static AppRole? fromStorage(String? value) {
    switch (value) {
      case 'family':
        return AppRole.family;
      case 'elder':
        return AppRole.elder;
      default:
        return null;
    }
  }
}

class AppRoleStore {
  static const _key = 'divie.active_role';

  Future<AppRole?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppRoleText.fromStorage(prefs.getString(_key));
  }

  Future<void> save(AppRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, role.storageValue);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
