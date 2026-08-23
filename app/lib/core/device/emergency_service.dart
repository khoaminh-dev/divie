import 'package:url_launcher/url_launcher.dart';

class EmergencyService {
  static Future<void> callNumber(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Không thể mở ứng dụng gọi điện.');
    }
  }
}
