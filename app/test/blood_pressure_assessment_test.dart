import 'package:divie_app/features/health/blood_pressure_assessment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BloodPressureAssessment', () {
    test('marks a normal reading green-compatible', () {
      final assessment = BloodPressureAssessment.evaluate(
        systolic: 118,
        diastolic: 78,
      );

      expect(assessment.level, BloodPressureLevel.normal);
      expect(assessment.isNormal, isTrue);
      expect(assessment.isAbnormal, isFalse);
    });

    test('marks an elevated reading as needing attention', () {
      final assessment = BloodPressureAssessment.evaluate(
        systolic: 128,
        diastolic: 78,
      );

      expect(assessment.level, BloodPressureLevel.elevated);
      expect(assessment.isAbnormal, isTrue);
    });

    test('marks high and low readings as abnormal', () {
      expect(
        BloodPressureAssessment.evaluate(systolic: 145, diastolic: 92).level,
        BloodPressureLevel.high,
      );
      expect(
        BloodPressureAssessment.evaluate(systolic: 88, diastolic: 58).level,
        BloodPressureLevel.low,
      );
    });

    test('prioritizes the critical alert level', () {
      final assessment = BloodPressureAssessment.evaluate(
        systolic: 182,
        diastolic: 121,
      );

      expect(assessment.level, BloodPressureLevel.critical);
      expect(assessment.isCritical, isTrue);
    });

    test('flags resting pulse outside the monitoring range', () {
      expect(BloodPressureAssessment.isPulseAbnormal(59), isTrue);
      expect(BloodPressureAssessment.isPulseAbnormal(101), isTrue);
      expect(BloodPressureAssessment.isPulseAbnormal(70), isFalse);
    });

    test('groups heart rate into healthy, attention and danger levels', () {
      expect(HeartRateAssessment.evaluate(72).level, HeartRateLevel.healthy);
      expect(HeartRateAssessment.evaluate(55).level, HeartRateLevel.attention);
      expect(HeartRateAssessment.evaluate(110).level, HeartRateLevel.attention);
      expect(HeartRateAssessment.evaluate(45).level, HeartRateLevel.danger);
      expect(HeartRateAssessment.evaluate(125).level, HeartRateLevel.danger);
    });
  });
}
