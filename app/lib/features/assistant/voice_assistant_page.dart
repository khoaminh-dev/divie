import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/supabase_bootstrap.dart';
import '../../core/config/app_config.dart';
import '../../core/data/reminder_data_service.dart';
import '../../main.dart';
import '../reminders/notification_service.dart';
import '../reminders/reminder_command_parser.dart';
import '../reminders/reminder_model.dart';

class _AssistantRequestException implements Exception {
  const _AssistantRequestException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class VoiceAssistantPage extends StatefulWidget {
  const VoiceAssistantPage({super.key, this.embedded = false});

  /// The main screen opens the assistant as a focused panel instead of
  /// navigating people away from what they were doing. The full page remains
  /// available from Settings for longer conversations and history later on.
  final bool embedded;

  @override
  State<VoiceAssistantPage> createState() => _VoiceAssistantPageState();
}

class _VoiceAssistantPageState extends State<VoiceAssistantPage> {
  final _speech = SpeechToText();
  final _tts = FlutterTts();
  bool _ready = false;
  bool _listening = false;
  bool _sending = false;
  bool _submittedCurrentSession = false;
  String _transcript = '';
  String _answer = '';
  ReminderDraft? _pendingReminder;
  final List<Map<String, String>> _conversation = [];
  late final ReminderDataService _reminderService;

  @override
  void initState() {
    super.initState();
    _reminderService = ReminderDataService(
      client: SupabaseBootstrap.enabled ? Supabase.instance.client : null,
      allowLocalFallback: false,
    );
    _prepare();
  }

  Future<void> _prepare() async {
    final ready = await _speech.initialize();
    await _tts.setLanguage('vi-VN');
    await _tts.setSpeechRate(.48);
    if (mounted) setState(() => _ready = ready);
  }

  Future<void> _toggleListening() async {
    if (!_ready || _sending) return;
    if (_listening) {
      await _submitCurrentTranscript();
      return;
    }
    setState(() {
      _transcript = '';
      _answer = '';
      _listening = true;
      _submittedCurrentSession = false;
    });
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'vi_VN',
        partialResults: true,
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
      ),
      onResult: (result) {
        if (!mounted) return;
        setState(() => _transcript = result.recognizedWords);
        if (result.finalResult) {
          unawaited(_submitCurrentTranscript());
        }
      },
    );
  }

  Future<void> _submitCurrentTranscript() async {
    if (_submittedCurrentSession) return;
    final text = _transcript.trim();
    if (text.isEmpty) return;

    // speech_to_text may deliver both a final callback and a stop callback.
    // Mark the session before awaiting anything so only one request can leave
    // this screen for one spoken command.
    _submittedCurrentSession = true;
    await _speech.stop();
    if (mounted) setState(() => _listening = false);
    await _ask(text);
  }

  String _cleanAssistantText(String value) {
    var cleaned = value
        .replaceAll(
          RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'<think>[\s\S]*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'```[a-zA-Z0-9_-]*\s*'), '')
        .replaceAll('```', '')
        .replaceAll('**', '')
        .replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '• ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\*\*(.*?)\*\*', dotAll: true),
      (match) => match.group(1) ?? '',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'__(.*?)__', dotAll: true),
      (match) => match.group(1) ?? '',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'`([^`]*)`'),
      (match) => match.group(1) ?? '',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (match) => match.group(1) ?? '',
    );
    return cleaned
        .replaceAll(RegExp(r'[$#*_`{}\[\]|<>]'), '')
        .replaceAll(RegExp(r'\s+([,.!?;:])'), r'\1')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _extractAssistantText(Object? value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    if (value is List) {
      return value
          .map(_extractAssistantText)
          .where((item) => item.trim().isNotEmpty)
          .join('\n');
    }
    if (value is Map) {
      const preferredKeys = [
        'content',
        'answer',
        'reply',
        'text',
        'message',
        'output',
      ];
      for (final key in preferredKeys) {
        final extracted = _extractAssistantText(value[key]);
        if (extracted.trim().isNotEmpty) return extracted;
      }
      final nested = _extractAssistantText(value['data']);
      if (nested.trim().isNotEmpty) return nested;
      final choices = value['choices'];
      if (choices is List && choices.isNotEmpty) {
        final choiceText = _extractAssistantText(choices.first);
        if (choiceText.trim().isNotEmpty) return choiceText;
      }
    }
    return '';
  }

  String _extractErrorText(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is Map) {
      for (final key in ['message', 'error', 'detail']) {
        final message = _extractAssistantText(value[key]);
        if (message.trim().isNotEmpty) return message.trim();
      }
    }
    return '';
  }

  String _friendlyError(Object error) {
    if (error is _AssistantRequestException) {
      final status = error.statusCode;
      if (status == 401 || status == 403) {
        return 'Trợ lý chưa được cấp quyền. Bạn thử lại sau nhé.';
      }
      if (status == 429) {
        return 'Trợ lý đang bận. Bạn thử lại sau ít phút nhé.';
      }
      if (status != null && status >= 500) {
        return 'Máy chủ trợ lý đang bận. Bạn thử lại sau nhé.';
      }
    }
    if (error is TimeoutException) {
      return 'Kết nối trợ lý hơi chậm. Bạn thử lại nhé.';
    }
    return 'Chưa kết nối được trợ lý. Bạn thử lại nhé.';
  }

  String _speechText(String value) => value
      .replaceAll('•', ', ')
      .replaceAll(RegExp(r'[\r\n]+'), '. ')
      .replaceAll(RegExp(r'[$#*_`{}\[\]|<>]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<void> _speakSafely(String value) async {
    final text = _speechText(value);
    if (text.isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // Voice playback must not turn a successful API/reminder action into an error.
    }
  }

  Future<void> _ask(String text) async {
    setState(() => _sending = true);
    try {
      final draft = ReminderCommandParser.parseDraft(text);
      ReminderCommand? command;
      if (draft.isReminderIntent) {
        if (draft.time == null) {
          _pendingReminder = draft;
          const answer = 'Bạn muốn nhắc lúc mấy giờ?';
          if (mounted) setState(() => _answer = answer);
          await _speakSafely(answer);
          return;
        }
        _pendingReminder = null;
        command = ReminderCommand(name: draft.name, time: draft.time!);
      } else if (_pendingReminder != null) {
        final time = ReminderCommandParser.extractTime(text);
        if (time != null) {
          final pending = _pendingReminder!;
          _pendingReminder = null;
          command = ReminderCommand(name: pending.name, time: time);
        } else {
          _pendingReminder = null;
        }
      }
      if (command != null) {
        try {
          if (!SupabaseBootstrap.enabled ||
              Supabase.instance.client.auth.currentUser == null) {
            throw StateError('medicine_reminders_remote_unavailable');
          }
          final created = await _reminderService.create(
            MedicineReminder(
              id: newReminderId(),
              name: command.name,
              time: command.time,
            ),
          );
          final notificationReady = await NotificationService.instance
              .trySchedule(created);
          final answer = notificationReady
              ? 'Đã tạo nhắc thuốc “${created.name}” lúc ${created.time} mỗi ngày.'
              : 'Đã lưu nhắc thuốc “${created.name}” lúc ${created.time}. Máy chưa bật được thông báo, bạn kiểm tra quyền thông báo trong Cài đặt nhé.';
          if (mounted) setState(() => _answer = answer);
          await _speakSafely(answer);
        } catch (error, stackTrace) {
          debugPrint('DiVie reminder create failed: $error');
          debugPrintStack(stackTrace: stackTrace);
          final answer =
              error.toString().contains('medicine_reminders_remote_unavailable')
              ? 'Ứng dụng chưa kết nối tài khoản. Bạn đăng nhập lại rồi thử tạo lịch nhé.'
              : 'Chưa lưu được lịch nhắc thuốc. Bạn thử lại nhé.';
          if (mounted) setState(() => _answer = answer);
          await _speakSafely(answer);
        }
        // Reminder commands are handled locally. Do not send the same voice
        // command to Groq as a second request.
        return;
      }

      final headers = {'Content-Type': 'application/json'};
      if (SupabaseBootstrap.enabled) {
        final token = Supabase.instance.client.auth.currentSession?.accessToken;
        if (token != null) headers['Authorization'] = 'Bearer $token';
      }
      final history = _conversation.length > 6
          ? _conversation.sublist(_conversation.length - 6)
          : _conversation;
      final messages = <Map<String, String>>[
        {
          'role': 'system',
          'content':
              'Bạn là trợ lý DiVie cho người cao tuổi. Trả lời tiếng Việt ngắn, rõ, an toàn. Không tự tạo lịch nhắc thuốc và không hỏi lại nhiều câu; lệnh nhắc thuốc đã được ứng dụng xử lý riêng. Nếu cần làm rõ một việc khác, chỉ hỏi một câu ngắn.',
        },
        ...history,
        {'role': 'user', 'content': text},
      ];
      final response = await http
          .post(
            Uri.parse('${AppConfig.voiceBaseUrl}/api/ai/chat'),
            headers: headers,
            body: jsonEncode({
              'messages': messages,
              'temperature': .3,
              'maxCompletionTokens': 300,
            }),
          )
          .timeout(const Duration(seconds: 45));

      dynamic body;
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = response.body;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _AssistantRequestException(
          _extractErrorText(body),
          statusCode: response.statusCode,
        );
      }
      final answer = _cleanAssistantText(_extractAssistantText(body));
      if (answer.isEmpty) {
        throw const _AssistantRequestException('empty_response');
      }
      if (_looksLikeReminderConfirmation(answer)) {
        const safeAnswer =
            'Mình chưa ghi được lịch nhắc thuốc. Bạn nói lại: “Nhắc tôi uống thuốc lúc 16 giờ.”';
        if (mounted) setState(() => _answer = safeAnswer);
        await _speakSafely(safeAnswer);
        return;
      }
      if (!mounted) return;
      setState(() => _answer = answer);
      _conversation
        ..add({'role': 'user', 'content': text})
        ..add({'role': 'assistant', 'content': answer});
      if (_conversation.length > 8) {
        _conversation.removeRange(0, _conversation.length - 8);
      }
      await _speakSafely(answer);
    } catch (error) {
      final answer = _friendlyError(error);
      if (mounted) {
        setState(() => _answer = answer);
        await _speakSafely(answer);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _looksLikeReminderConfirmation(String value) {
    final text = value.toLowerCase();
    final claimsSaved =
        text.contains('đã tạo') ||
        text.contains('đã đặt') ||
        text.contains('đã lưu') ||
        text.contains('tạo thành công') ||
        text.contains('đặt thành công');
    final reminderTopic =
        text.contains('nhắc') ||
        text.contains('thuốc') ||
        text.contains('uống thuốc') ||
        text.contains('báo thức');
    return claimsSaved && reminderTopic;
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _buildFloatingAssistant(context);

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final content = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nói điều bạn cần',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: DivieColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ví dụ: “Nhắc tôi uống thuốc lúc 4 giờ chiều”.',
            style: TextStyle(color: DivieColors.muted, fontSize: 16),
          ),
          const SizedBox(height: 22),
          _VoiceBubble(
            label: 'Bạn nói',
            text: _transcript.isEmpty
                ? 'Chạm micro rồi nói điều bạn cần'
                : _transcript,
          ),
          const SizedBox(height: 12),
          _VoiceBubble(
            label: 'DiVie trả lời',
            text: _sending
                ? 'Đang xử lý…'
                : (_answer.isEmpty
                      ? 'DiVie sẽ làm ngay những việc đơn giản như nhắc thuốc, gọi hoặc nhắn cho người thân.'
                      : _answer),
          ),
          const SizedBox(height: 22),
          Center(
            child: FloatingActionButton.large(
              backgroundColor: _listening
                  ? DivieColors.danger
                  : DivieColors.teal,
              onPressed: _toggleListening,
              child: Icon(
                _listening ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              !_ready
                  ? 'Đang chuẩn bị micro…'
                  : (_listening ? 'Đang nghe… chạm lại để gửi' : 'Chạm để nói'),
              style: const TextStyle(
                color: DivieColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Trợ lý DiVie')),
      body: SafeArea(child: content),
    );
  }

  Widget _buildFloatingAssistant(BuildContext context) {
    final status = !_ready
        ? 'Đang chuẩn bị micro…'
        : _sending
        ? 'DiVie đang xử lý yêu cầu của bạn'
        : _listening
        ? 'DiVie đang lắng nghe…'
        : 'Chạm vào micro và nói điều bạn cần';
    final hasResult = _transcript.isNotEmpty || _answer.isNotEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        22,
        18,
        22,
        22 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0x1A18AAB3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: DivieColors.teal,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trợ lý DiVie',
                      style: TextStyle(
                        color: DivieColors.navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Nói tự nhiên, DiVie sẽ hỗ trợ ngay',
                      style: TextStyle(color: DivieColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Đóng trợ lý',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: DivieColors.navy),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _VoiceWave(listening: _listening, processing: _sending),
          const SizedBox(height: 10),
          Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: DivieColors.navy,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ví dụ: “Nhắc tôi uống thuốc lúc 4 giờ chiều”.',
            textAlign: TextAlign.center,
            style: TextStyle(color: DivieColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Center(
            child: FloatingActionButton.large(
              heroTag: 'assistant-floating-mic',
              backgroundColor: _listening
                  ? DivieColors.danger
                  : DivieColors.teal,
              onPressed: _sending ? null : _toggleListening,
              child: Icon(
                _listening ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
          ),
          if (hasResult) ...[
            const SizedBox(height: 18),
            if (_transcript.isNotEmpty)
              _AssistantResultCard(
                icon: Icons.record_voice_over_rounded,
                label: 'Bạn vừa nói',
                text: _transcript,
              ),
            if (_transcript.isNotEmpty && _answer.isNotEmpty)
              const SizedBox(height: 10),
            if (_answer.isNotEmpty)
              _AssistantResultCard(
                icon: Icons.auto_awesome_rounded,
                label: 'DiVie đã xử lý',
                text: _answer,
                emphasized: true,
              ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VoiceAssistantPage()),
              );
            },
            icon: const Icon(Icons.history_rounded),
            label: const Text('Mở trợ lý đầy đủ'),
          ),
        ],
      ),
    );
  }
}

class _AssistantResultCard extends StatelessWidget {
  const _AssistantResultCard({
    required this.icon,
    required this.label,
    required this.text,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: emphasized ? const Color(0xFFE2F8F7) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: emphasized ? const Color(0x6618AAB3) : const Color(0xFFE4ECF1),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: DivieColors.teal, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: DivieColors.teal,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: const TextStyle(
                  color: DivieColors.navy,
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _VoiceWave extends StatefulWidget {
  const _VoiceWave({required this.listening, required this.processing});

  final bool listening;
  final bool processing;

  @override
  State<_VoiceWave> createState() => _VoiceWaveState();
}

class _VoiceWaveState extends State<_VoiceWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.listening || widget.processing;
    final color = widget.listening ? DivieColors.teal : DivieColors.navy;
    return SizedBox(
      height: 72,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(11, (index) {
            final phase = _controller.value * math.pi * 2 + index * .72;
            final amount = active ? (math.sin(phase).abs() * .72 + .28) : .24;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 5,
              height: 14 + amount * 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: active ? .9 : .32),
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _VoiceBubble extends StatelessWidget {
  const _VoiceBubble({required this.label, required this.text});
  final String label;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: DivieColors.teal,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: const TextStyle(
            color: DivieColors.navy,
            fontSize: 17,
            height: 1.35,
          ),
        ),
      ],
    ),
  );
}
