import 'package:flutter/services.dart';

class AndroidLauncherService {
  static const _channel = MethodChannel('divie/device');

  static Future<bool> isHomeRoleHeld() async {
    try {
      return await _channel.invokeMethod<bool>('isHomeRoleHeld') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestHomeRole() async {
    try {
      return await _channel.invokeMethod<bool>('requestHomeRole') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openNotificationSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openNotificationSettings') ??
          false;
    } catch (_) {
      return false;
    }
  }
}
