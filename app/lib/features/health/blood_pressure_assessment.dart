enum BloodPressureLevel { unavailable, normal, elevated, high, critical, low }

enum HeartRateLevel { unavailable, healthy, attention, danger }

class HeartRateAssessment {
  const HeartRateAssessment({
    required this.level,
    required this.title,
    required this.message,
  });

  final HeartRateLevel level;
  final String title;
  final String message;

  bool get isHealthy => level == HeartRateLevel.healthy;
  bool get needsAttention =>
      level == HeartRateLevel.attention || level == HeartRateLevel.danger;
  bool get isDanger => level == HeartRateLevel.danger;

  static HeartRateAssessment evaluate(int? pulse) {
    if (pulse == null) {
      return const HeartRateAssessment(
        level: HeartRateLevel.unavailable,
        title: 'Chưa có nhịp tim',
        message: 'DiVie chưa đọc được nhịp tim từ lần đo này.',
      );
    }
    if (pulse < 50 || pulse > 120) {
      return const HeartRateAssessment(
        level: HeartRateLevel.danger,
        title: 'Nhịp tim cần chú ý ngay',
        message:
            'Bác hãy ngồi nghỉ và đo lại khi cơ thể thư giãn. Nếu kèm đau ngực, khó thở, choáng hoặc ngất, hãy nhờ hỗ trợ y tế ngay.',
      );
    }
    if (pulse < 60 || pulse > 100) {
      return const HeartRateAssessment(
        level: HeartRateLevel.attention,
        title: 'Nhịp tim cần theo dõi',
        message:
            'Bác nên nghỉ vài phút rồi đo lại. Nếu chỉ số lặp lại hoặc thấy không khỏe, hãy trao đổi với người thân hoặc nhân viên y tế.',
      );
    }
    return const HeartRateAssessment(
      level: HeartRateLevel.healthy,
      title: 'Nhịp tim trong mức khỏe',
      message:
          'Nhịp tim ở lần đo này nằm trong khoảng theo dõi 60–100 lần/phút.',
    );
  }
}

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
      HeartRateAssessment.evaluate(pulse).needsAttention;
}
