import 'package:flutter_test/flutter_test.dart';

import 'package:divie_app/features/reminders/reminder_command_parser.dart';

void main() {
  group('ReminderCommandParser', () {
    test('parses a natural Vietnamese afternoon command', () {
      final command = ReminderCommandParser.tryParse(
        'Nhắc ông uống thuốc vào lúc 4 giờ chiều',
      );

      expect(command, isNotNull);
      expect(command!.name, 'Uống thuốc');
      expect(command.time, '16:00');
    });

    test('parses unaccented voice recognition and g notation', () {
      final command = ReminderCommandParser.tryParse(
        'nhac toi uong thuoc luc 7g30 sang',
      );

      expect(command, isNotNull);
      expect(command!.name, 'Uống thuốc');
      expect(command.time, '07:30');
    });

    test('parses a twenty-four-hour time', () {
      final command = ReminderCommandParser.tryParse('Nhắc thuốc 20:15');

      expect(command, isNotNull);
      expect(command!.time, '20:15');
    });

    test('parses a set-reminder phrase without the word nhắc', () {
      final command = ReminderCommandParser.tryParse(
        'Đặt lịch uống thuốc lúc 4 giờ chiều',
      );

      expect(command, isNotNull);
      expect(command!.name, 'Uống thuốc');
      expect(command.time, '16:00');
    });

    test('handles a speech-to-text typo in a create-reminder command', () {
      final command = ReminderCommandParser.tryParse(
        'Tạo lịch nhát thuốc cho tôi vào lúc 12:43',
      );

      expect(command, isNotNull);
      expect(command!.name, 'Uống thuốc');
      expect(command.time, '12:43');
    });

    test('keeps a reminder intent when the time is missing', () {
      final draft = ReminderCommandParser.parseDraft('Đặt lịch uống thuốc');

      expect(draft.isReminderIntent, isTrue);
      expect(draft.name, 'Uống thuốc');
      expect(draft.time, isNull);
    });

    test('parses Vietnamese number words', () {
      final command = ReminderCommandParser.tryParse(
        'Báo thức uống thuốc lúc bốn giờ chiều',
      );

      expect(command, isNotNull);
      expect(command!.time, '16:00');
    });

    test('extracts a follow-up time without reminder keywords', () {
      expect(ReminderCommandParser.extractTime('4 giờ chiều'), '16:00');
    });

    test('does not treat ordinary conversation as a reminder', () {
      expect(
        ReminderCommandParser.tryParse('Hôm nay thời tiết thế nào?'),
        isNull,
      );
    });
  });
}
