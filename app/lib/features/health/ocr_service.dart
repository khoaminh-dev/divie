import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/supabase_bootstrap.dart';
import '../../core/config/app_config.dart';

class BloodPressureReading {
  const BloodPressureReading({
    this.systolic,
    this.diastolic,
    this.pulse,
    this.confidence,
    this.rawText = '',
  });
  final int? systolic;
  final int? diastolic;
  final int? pulse;
  final double? confidence;
  final String rawText;
}

class OcrService {
  Future<BloodPressureReading> scanBloodPressure({
    required String base64Image,
    required String mimeType,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (SupabaseBootstrap.enabled) {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    final response = await http
        .post(
          Uri.parse('${AppConfig.voiceBaseUrl}/ocr/blood-pressure'),
          headers: headers,
          body: jsonEncode({'imageBase64': base64Image, 'mimeType': mimeType}),
        )
        .timeout(const Duration(seconds: 75));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message'] ?? 'Không thể đọc ảnh lúc này.');
    }
    final measurement = body['measurement'] as Map<String, dynamic>?;
    if (measurement == null) {
      throw Exception('Backend chưa trả về kết quả OCR.');
    }
    return BloodPressureReading(
      systolic: (measurement['systolic'] as num?)?.toInt(),
      diastolic: (measurement['diastolic'] as num?)?.toInt(),
      pulse: (measurement['pulse'] as num?)?.toInt(),
      confidence: (measurement['confidence'] as num?)?.toDouble(),
      rawText: measurement['rawText'] as String? ?? '',
    );
  }
}
