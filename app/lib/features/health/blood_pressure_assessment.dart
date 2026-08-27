enum BloodPressureLevel { unavailable, normal, elevated, high, critical, low }

class BloodPressureAssessment {
  const BloodPressureAssessment({
    required this.level,
    required this.title,
    required this.message,
    required this.iconName,
  });

  final BloodPressureLevel level;
  final String title;
  final String message;
  final String iconName;

  bool get isNormal => level == BloodPressureLevel.normal;
  bool get isAbnormal =>
      level != BloodPressureLevel.normal &&
      level != BloodPressureLevel.unavailable;
  bool get isCritical => level == BloodPressureLevel.critical;

  static BloodPressureAssessment evaluate({int? systolic, int? diastolic}) {
    if (systolic == null && diastolic == null) {
      return const BloodPressureAssessment(
        level: BloodPressureLevel.unavailable,
        title: 'Chưa đủ chỉ số huyết áp',
        message:
            'Hãy chụp hoặc nhập đủ chỉ số tâm thu và tâm trương để DiVie đánh giá.',
        iconName: 'help',
      );
    }

    if ((systolic ?? 0) >= 180 || (diastolic ?? 0) >= 120) {
      return const BloodPressureAssessment(
        level: BloodPressureLevel.critical,
        title: 'Huyết áp rất cao',
        message:
            'Bác hãy ngồi yên, đo lại sau 1 phút. Nếu vẫn cao hoặc có đau ngực, khó thở, yếu liệt, nhìn mờ hay nói khó, hãy gọi hỗ trợ y tế ngay.',
        iconName: 'priority_high',
      );
    }

    if ((systolic != null && systolic < 90) ||
        (diastolic != null && diastolic < 60)) {
      return const BloodPressureAssessment(
        level: BloodPressureLevel.low,
        title: 'Huyết áp thấp cần chú ý',
        message:
            'Bác nên ngồi hoặc nằm xuống, tránh đứng dậy đột ngột và đo lại sau khi nghỉ. Hãy nhờ người thân hoặc nhân viên y tế nếu chóng mặt, mệt nhiều hoặc chỉ số lặp lại.',
        iconName: 'south',
      );
    }

    if ((systolic ?? 0) >= 140 || (diastolic ?? 0) >= 90) {
      return const BloodPressureAssessment(
        level: BloodPressureLevel.high,
        title: 'Huyết áp cao cần theo dõi',
        message:
            'Bác hãy nghỉ yên 5 phút rồi đo lại đúng tư thế. Nếu nhiều lần vẫn cao, hãy liên hệ người thân hoặc nhân viên y tế để được tư vấn.',
        iconName: 'north',
      );
    }

    if ((systolic ?? 0) >= 120 || (diastolic ?? 0) >= 80) {
      return const BloodPressureAssessment(
        level: BloodPressureLevel.elevated,
        title: 'Chỉ số cần theo dõi',
        message:
            'Chỉ số chưa ở mức lý tưởng. Bác nên nghỉ yên 5 phút, đo lại đúng tư thế và theo dõi các lần đo tiếp theo.',
        iconName: 'north_east',
      );
    }

    return const BloodPressureAssessment(
      level: BloodPressureLevel.normal,
      title: 'Huyết áp trong mức theo dõi bình thường',
      message:
          'Bác tiếp tục duy trì giờ đo đều đặn và lưu lại kết quả để theo dõi xu hướng.',
      iconName: 'check',
    );
  }

  static bool isPulseAbnormal(int? pulse) =>
      pulse != null && (pulse < 60 || pulse > 100);
}
