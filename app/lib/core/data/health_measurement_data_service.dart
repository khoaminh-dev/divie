import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/health/ocr_service.dart';

class HealthMeasurementHistoryItem {
  const HealthMeasurementHistoryItem({
    required this.id,
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    required this.source,
    required this.measuredAt,
    this.confidence,
  });

  final String id;
  final int? systolic;
  final int? diastolic;
  final int? pulse;
  final String source;
  final DateTime measuredAt;
  final double? confidence;

  factory HealthMeasurementHistoryItem.fromRow(Map<String, dynamic> row) {
    final payload = row['raw_payload'];
    final rawPayload = payload is Map
        ? Map<String, dynamic>.from(payload)
        : const <String, dynamic>{};
    return HealthMeasurementHistoryItem(
      id: row['id']?.toString() ?? '',
      systolic: (row['systolic_bp'] as num?)?.toInt(),
      diastolic: (row['diastolic_bp'] as num?)?.toInt(),
      pulse: (row['heart_rate'] as num?)?.toInt(),
      source: row['source'] as String? ?? 'manual',
      measuredAt:
          (DateTime.tryParse(row['measured_at'] as String? ?? '') ??
                  DateTime.now())
              .toLocal(),
      confidence: (rawPayload['confidence'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toLocalJson() => {
    'id': id,
    'systolic': systolic,
    'diastolic': diastolic,
    'pulse': pulse,
    'source': source,
    'measuredAt': measuredAt.toIso8601String(),
    'confidence': confidence,
  };

  factory HealthMeasurementHistoryItem.fromLocalJson(
    Map<String, dynamic> json,
  ) => HealthMeasurementHistoryItem(
    id: json['id'] as String? ?? '',
    systolic: (json['systolic'] as num?)?.toInt(),
    diastolic: (json['diastolic'] as num?)?.toInt(),
    pulse: (json['pulse'] as num?)?.toInt(),
    source: json['source'] as String? ?? 'manual',
    measuredAt:
        (DateTime.tryParse(json['measuredAt'] as String? ?? '') ??
                DateTime.now())
            .toLocal(),
    confidence: (json['confidence'] as num?)?.toDouble(),
  );
}

class HealthMeasurementDataService {
  HealthMeasurementDataService({this.client, this.ownerId});

  static const _localKey = 'divie.health_measurement_history';

  final SupabaseClient? client;
  final String? ownerId;

  bool get isRemote => client?.auth.currentUser != null;

  String get _ownerId => ownerId?.trim().isNotEmpty == true
      ? ownerId!.trim()
      : client!.auth.currentUser!.id;

  Future<List<HealthMeasurementHistoryItem>> load({int limit = 20}) async {
    if (!isRemote) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_localKey) ?? const <String>[];
      return raw
          .map((item) => jsonDecode(item))
          .whereType<Map<String, dynamic>>()
          .map(HealthMeasurementHistoryItem.fromLocalJson)
          .take(limit)
          .toList();
    }

    final rows = await client!
        .from('health_measurement_sessions')
        .select(
          'id,systolic_bp,diastolic_bp,heart_rate,source,raw_payload,measured_at',
        )
        .eq('user_id', _ownerId)
        .order('measured_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(HealthMeasurementHistoryItem.fromRow)
        .toList();
  }

  Future<HealthMeasurementHistoryItem> saveOcr(
    BloodPressureReading reading,
  ) async {
    // Store one unambiguous timestamp in the database, then show it in the
    // device's local timezone. This prevents a reading from appearing under a
    // wrong hour when the app is reopened on another device.
    final measuredAt = DateTime.now().toUtc();
    final rawPayload = {
      'confidence': reading.confidence,
      'rawText': reading.rawText,
    };

    if (isRemote) {
      final row = await client!
          .from('health_measurement_sessions')
          .insert({
            'user_id': _ownerId,
            'systolic_bp': reading.systolic,
            'diastolic_bp': reading.diastolic,
            'heart_rate': reading.pulse,
            'source': 'ocr',
            'raw_payload': rawPayload,
            'measured_at': measuredAt.toIso8601String(),
          })
          .select(
            'id,systolic_bp,diastolic_bp,heart_rate,source,raw_payload,measured_at',
          )
          .single();
      return HealthMeasurementHistoryItem.fromRow(row);
    }

    final item = HealthMeasurementHistoryItem(
      id: 'local-${measuredAt.microsecondsSinceEpoch}',
      systolic: reading.systolic,
      diastolic: reading.diastolic,
      pulse: reading.pulse,
      source: 'ocr',
      measuredAt: measuredAt,
      confidence: reading.confidence,
    );
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_localKey) ?? const <String>[];
    await prefs.setStringList(
      _localKey,
      [jsonEncode(item.toLocalJson()), ...current].take(50).toList(),
    );
    return item;
  }
}
