class ReminderCommand {
  const ReminderCommand({required this.name, required this.time});

  final String name;
  final String time;
}

class ReminderDraft {
  const ReminderDraft({
    required this.isReminderIntent,
    required this.name,
    this.time,
  });

  final bool isReminderIntent;
  final String name;
  final String? time;
}

/// Parses the small, predictable subset of Vietnamese voice commands that
/// should create a reminder. General conversation remains handled by Groq.
class ReminderCommandParser {
  static ReminderDraft parseDraft(String input) {
    final text = _normalize(input);
    final isReminderIntent = _hasReminderIntent(text);
    final time = extractTime(text);
    final name = _extractName(text);
    return ReminderDraft(
      isReminderIntent: isReminderIntent,
      name: name,
      time: time,
    );
  }

  static ReminderCommand? tryParse(String input) {
    final draft = parseDraft(input);
    if (!draft.isReminderIntent || draft.time == null) return null;
    return ReminderCommand(name: draft.name, time: draft.time!);
  }

  static String? extractTime(String input) {
    final text = _normalize(input);
    final number =
        r'(?:\d{1,2}|một|mot|hai|ba|bốn|bon|năm|nam|sáu|sau|'
        r'bảy|bay|tám|tam|chín|chin|mười|muoi)';
    final timeMatch = RegExp(
      '(?:\\b(?:lúc|luc|vào|vao|khoảng|khoang)\\b\\s*)?'
      '($number)'
      r'(?:\s*(?::|giờ|gio|h|g)\s*(\d{1,2})?)?'
      r'(?:\s*(sáng|sang|trưa|trua|chiều|chieu|tối|toi|đêm|dem))?',
    ).firstMatch(text);
    if (timeMatch == null) return null;

    var hour = _parseNumber(timeMatch.group(1));
    final minute = int.tryParse(timeMatch.group(2) ?? '') ?? 0;
    if (hour == null || hour > 23 || minute > 59) return null;
    final period = timeMatch.group(3);
    if (period == 'chiều' ||
        period == 'chieu' ||
        period == 'tối' ||
        period == 'toi' ||
        period == 'đêm' ||
        period == 'dem') {
      if (hour < 12) hour += 12;
    } else if ((period == 'trưa' || period == 'trua') && hour < 11) {
      hour += 12;
    }
    if (hour > 23) return null;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static bool _hasReminderIntent(String text) {
    const markers = [
      'nhắc',
      'nhac',
      'đặt lịch',
      'dat lich',
      'báo thức',
      'bao thuc',
      'hẹn giờ',
      'hen gio',
    ];
    if (markers.any(text.contains)) {
      return true;
    }
    return RegExp(r'\buống thuốc\b|\buong thuoc\b').hasMatch(text) &&
        RegExp(
          r'\b(lúc|luc|vào|vao|giờ|gio|h|g|sáng|sang|chiều|chieu|tối|toi)\b',
        ).hasMatch(text);
  }

  static String _extractName(String text) {
    final timeMatch = extractTime(text) == null
        ? null
        : RegExp(
            r'(?:\b(?:lúc|luc|vào|vao|khoảng|khoang)\b\s*)?'
            r'(?:\d{1,2}|một|mot|hai|ba|bốn|bon|năm|nam|sáu|sau|bảy|bay|tám|tam|chín|chin|mười|muoi)',
          ).firstMatch(text);
    var name = timeMatch == null ? text : text.substring(0, timeMatch.start);
    name = name
        .replaceAll(
          RegExp(
            r'(^|\s)(nhắc|nhac|đặt|dat|lịch|lich|báo|bao|thức|thuc|'
            r'tôi|toi|mình|minh|ông|ong|bà|ba|cô|co|chú|chu|anh|chị|chi|'
            r'uống|uong|dùng|dung|cho|giúp|giup|vào|vao|lúc|luc|khoảng|khoang)(?=\s|$)',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (name.isEmpty ||
        name == 'thuốc' ||
        name == 'thuoc' ||
        name == 'uống thuốc' ||
        name == 'uong thuoc') {
      return 'Uống thuốc';
    }
    if (!name.toLowerCase().contains('thuốc') &&
        !name.toLowerCase().contains('thuoc') &&
        !name.toLowerCase().contains('viên') &&
        !name.toLowerCase().contains('vien')) {
      return 'Uống thuốc · $name';
    }
    return name[0].toUpperCase() + name.substring(1);
  }

  static int? _parseNumber(String? value) {
    if (value == null) return null;
    final numeric = int.tryParse(value);
    if (numeric != null) return numeric;
    const words = {
      'một': 1,
      'mot': 1,
      'hai': 2,
      'ba': 3,
      'bốn': 4,
      'bon': 4,
      'năm': 5,
      'nam': 5,
      'sáu': 6,
      'sau': 6,
      'bảy': 7,
      'bay': 7,
      'tám': 8,
      'tam': 8,
      'chín': 9,
      'chin': 9,
      'mười': 10,
      'muoi': 10,
    };
    return words[value];
  }

  static String _normalize(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('nhắc nhở', 'nhắc')
      .trim();
}
