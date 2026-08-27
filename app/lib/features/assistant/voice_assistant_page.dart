import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/supabase_bootstrap.dart';
import '../../core/config/app_config.dart';
import '../../core/data/app_data_service.dart';
import '../../core/data/reminder_data_service.dart';
import '../../core/device/emergency_service.dart';
import '../../core/roles/app_role.dart';
import '../../main.dart';
import '../chat/live_chat_pages.dart';
import '../reminders/notification_service.dart';
import '../reminders/reminder_command_parser.dart';
import '../reminders/reminder_model.dart';
import '../reminders/reminders_page.dart';
import '../health/health_capture_page.dart';
import '../health/health_insights_page.dart';

class _AssistantRequestException implements Exception {
  const _AssistantRequestException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

enum _HealthVoiceAction { capture, insights }

class _VoiceIntent {
  const _VoiceIntent({
    required this.action,
    this.screen,
    this.contactName,
    this.message,
    this.reply,
  });

  final String action;
  final String? screen;
  final String? contactName;
  final String? message;
  final String? reply;

  factory _VoiceIntent.fromJson(Map<String, dynamic> json) => _VoiceIntent(
    action: json['action'] as String? ?? 'conversation',
    screen: json['screen'] as String?,
    contactName: json['contactName'] as String?,
    message: json['message'] as String?,
    reply: json['reply'] as String?,
  );
}

class _PendingVoiceMessage {
  const _PendingVoiceMessage({this.recipient, this.content});

  final ContactRecord? recipient;
  final String? content;

  _PendingVoiceMessage copyWith({ContactRecord? recipient, String? content}) =>
      _PendingVoiceMessage(
        recipient: recipient ?? this.recipient,
        content: content ?? this.content,
      );
}

class VoiceAssistantPage extends StatefulWidget {
  const VoiceAssistantPage({super.key, this.embedded = false, this.onNavigate});

  /// The main screen opens the assistant as a focused panel instead of
  /// navigating people away from what they were doing. The full page remains
  /// available from Settings for longer conversations and history later on.
  final bool embedded;

  /// Lets the floating assistant switch the shell tab after it closes.
  final ValueChanged<int>? onNavigate;

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
  double _speechConfidence = 0;
  String _transcript = '';
  String _answer = '';
  ReminderDraft? _pendingReminder;
  _PendingVoiceMessage? _pendingMessage;
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
    await _tts.awaitSpeakCompletion(true);
    if (!mounted) return;
    setState(() => _ready = ready);
    if (ready && widget.embedded) unawaited(_toggleListening());
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
      _speechConfidence = 0;
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
        setState(() {
          _transcript = result.recognizedWords;
          if (result.finalResult) _speechConfidence = result.confidence;
        });
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
    debugPrint('DiVie voice transcript: $text (confidence=$_speechConfidence)');
    if (!_isUsableVoiceTranscript(text)) {
      debugPrint(
        'DiVie voice transcript rejected: confidence=$_speechConfidence.',
      );
      await _setCallAnswer('Con chưa nghe rõ. Bác nói lại giúp con nhé.');
      return;
    }
    await _ask(text);
  }

  bool _isUsableVoiceTranscript(String value) {
    final normalized = _normalizedText(value);
    final words = normalized
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();
    if (normalized.length < 3 ||
        words.length < 2 ||
        !RegExp(r'[a-z0-9]').hasMatch(normalized)) {
      return false;
    }

    // Do not act on a phrase that the recognizer stopped in the middle of.
    // In particular, a trailing connector means the intended person or action
    // has not yet been captured.
    if (RegExp(r'\b(?:cho|cua|voi|va|la|thi|roi)$').hasMatch(normalized)) {
      return false;
    }

    // Some Android recognition services report 0 when they do not expose a
    // confidence score. Only reject a score when one is actually available.
    return _speechConfidence <= 0 || _speechConfidence >= .45;
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
        return 'Trợ lý chưa được cấp quyền. Bác thử lại sau giúp con nhé.';
      }
      if (status == 429) {
        return 'Trợ lý đang bận. Bác thử lại sau ít phút nhé.';
      }
      if (status != null && status >= 500) {
        return 'Máy chủ trợ lý đang bận. Bác thử lại sau giúp con nhé.';
      }
    }
    if (error is TimeoutException) {
      return 'Kết nối trợ lý hơi chậm. Bác thử lại giúp con nhé.';
    }
    return 'Chưa kết nối được trợ lý. Bác thử lại giúp con nhé.';
  }

  String _speechText(String value) => value
      .replaceAll('•', ', ')
      .replaceAll(RegExp(r'[\r\n]+'), '. ')
      .replaceAll(RegExp(r'[$#*_`{}\[\]|<>]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<void> _speakSafely(String value) async {
    final text = _speechText(_enforceVoiceAddress(value));
    if (text.isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // Voice playback must not turn a successful API/reminder action into an error.
    }
  }

  String _enforceVoiceAddress(String value) => value
      .replaceAll('Mình', 'Con')
      .replaceAll('mình', 'con')
      .replaceAll('Tôi', 'Con')
      .replaceAll('tôi', 'con')
      .replaceAll('Bạn', 'Bác')
      .replaceAll('bạn', 'bác')
      .replaceAll('Ông/bà', 'Bác')
      .replaceAll('ông/bà', 'bác');

  Future<void> _ask(String text) async {
    setState(() => _sending = true);
    try {
      if (_pendingMessage != null) {
        await _continueMessageDraft(text);
        return;
      }
      final callTarget = _callTargetFor(text);
      if (callTarget != null) {
        await _handleVoiceCall(callTarget);
        return;
      }
      if (_looksLikeCallIntent(text)) {
        debugPrint('DiVie voice call intent had no usable contact name.');
        await _setCallAnswer(
          'Con chưa nghe rõ tên người cần gọi. Bác nói lại tên đúng như trong danh bạ nhé.',
        );
        return;
      }
      final healthAction = _healthActionFor(text);
      if (healthAction != null) {
        await _openHealthAction(healthAction);
        return;
      }
      final draft = ReminderCommandParser.parseDraft(text);
      ReminderCommand? command;
      if (draft.isReminderIntent) {
        if (draft.time == null) {
          _pendingReminder = draft;
          const answer = 'Bác muốn con nhắc lúc mấy giờ ạ?';
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
              ? 'Con đã tạo nhắc thuốc “${created.name}” lúc ${created.time} mỗi ngày.'
              : 'Con đã lưu nhắc thuốc “${created.name}” lúc ${created.time}. Máy chưa bật được thông báo, bác kiểm tra quyền thông báo trong Cài đặt nhé.';
          if (mounted) setState(() => _answer = answer);
          await _speakSafely(answer);
        } catch (error, stackTrace) {
          debugPrint('DiVie reminder create failed: $error');
          debugPrintStack(stackTrace: stackTrace);
          final answer =
              error.toString().contains('medicine_reminders_remote_unavailable')
              ? 'Ứng dụng chưa kết nối tài khoản. Bác đăng nhập lại rồi thử tạo lịch nhé.'
              : 'Con chưa lưu được lịch nhắc thuốc. Bác thử lại nhé.';
          if (mounted) setState(() => _answer = answer);
          await _speakSafely(answer);
        }
        // Reminder commands are handled locally. Do not send the same voice
        // command to Groq as a second request.
        return;
      }

      if (await _tryRunAgentIntent(text)) return;

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
              'Bạn là trợ lý DiVie cho người cao tuổi. Luôn xưng “con” và gọi người dùng là “bác”, không dùng mình, tôi, bạn, ông/bà hay bất kỳ cách xưng hô nào khác. Trả lời tiếng Việt ngắn, rõ, an toàn. Nếu câu nói của bác không rõ hoặc có vẻ bị nhận diện sai, chỉ nói: “Con chưa nghe rõ. Bác nói lại giúp con nhé.” Với yêu cầu nhắc thuốc, nếu người dùng chưa nói rõ giờ thì chỉ hỏi giờ cần nhắc; không nói rằng ứng dụng không thể tạo lịch. Không tự nhận đã mở camera hoặc biểu đồ sức khỏe khi chưa có xác nhận từ ứng dụng. Nếu cần làm rõ một việc khác, chỉ hỏi một câu ngắn.',
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
            'Con chưa ghi được lịch nhắc thuốc. Bác nói lại: “Nhắc con uống thuốc lúc 16 giờ.”';
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

  Future<bool> _tryRunAgentIntent(String transcript) async {
    try {
      final intent = await _requestVoiceIntent(transcript);
      switch (intent.action) {
        case 'open_screen':
          final screen = intent.screen;
          if (screen == null || screen.isEmpty) return false;
          await _openToolScreen(screen);
          return true;
        case 'call_contact':
          final name = intent.contactName;
          if (name == null || name.isEmpty) {
            await _setCallAnswer(
              'Bác muốn con gọi cho ai? Bác nói tên đúng như trong danh bạ nhé.',
            );
          } else {
            await _handleVoiceCall(name);
          }
          return true;
        case 'compose_message':
          await _beginMessageDraft(
            contactName: intent.contactName,
            content: intent.message,
          );
          return true;
        case 'create_reminder':
          await _setCallAnswer(
            intent.reply ??
                'Bác nói rõ tên thuốc và giờ cần nhắc giúp con nhé.',
          );
          return true;
        case 'conversation':
          return false;
        default:
          return false;
      }
    } catch (error) {
      debugPrint('DiVie voice intent routing failed: $error');
      // Conversational assistance remains available if the router is
      // temporarily unavailable during a backend rollout.
      return false;
    }
  }

  Future<_VoiceIntent> _requestVoiceIntent(String transcript) async {
    final headers = {'Content-Type': 'application/json'};
    if (SupabaseBootstrap.enabled) {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    final response = await http
        .post(
          Uri.parse('${AppConfig.voiceBaseUrl}/api/ai/intent'),
          headers: headers,
          body: jsonEncode({'transcript': transcript}),
        )
        .timeout(const Duration(seconds: 20));
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _AssistantRequestException(
        _extractErrorText(decoded),
        statusCode: response.statusCode,
      );
    }
    if (decoded is! Map || decoded['intent'] is! Map) {
      throw const _AssistantRequestException('invalid_intent_response');
    }
    return _VoiceIntent.fromJson(
      Map<String, dynamic>.from(decoded['intent'] as Map),
    );
  }

  Future<void> _openToolScreen(String screen) async {
    switch (screen) {
      case 'health_capture':
        await _openHealthAction(_HealthVoiceAction.capture);
        return;
      case 'health_insights':
        await _openHealthAction(_HealthVoiceAction.insights);
        return;
      case 'reminders':
        await _announceAndOpen(
          'Con mở lịch nhắc thuốc cho bác nhé.',
          const RemindersPage(role: AppRole.elder),
        );
        return;
      case 'messages':
        await _openShellTab(
          index: 1,
          answer: 'Con mở Tin nhắn cho bác nhé.',
          fallback: const LiveMessagesPage(),
        );
        return;
      case 'contacts':
        await _openShellTab(
          index: 3,
          answer: 'Con mở Danh bạ cho bác nhé.',
          fallback: const LiveContactsPage(),
        );
        return;
      case 'settings':
        await _openShellTab(index: 4, answer: 'Con mở Cài đặt cho bác nhé.');
        return;
    }
    await _setCallAnswer(
      'Con chưa hiểu màn hình bác muốn mở. Bác nói lại nhé.',
    );
  }

  Future<void> _openShellTab({
    required int index,
    required String answer,
    Widget? fallback,
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (mounted) setState(() => _answer = answer);
    await _speakSafely(answer);
    if (widget.embedded) {
      await navigator.maybePop();
    }
    final onNavigate = widget.onNavigate;
    if (onNavigate != null) {
      onNavigate(index);
      return;
    }
    if (fallback != null && mounted) {
      await navigator.push(MaterialPageRoute(builder: (_) => fallback));
    }
  }

  Future<void> _announceAndOpen(String answer, Widget page) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (mounted) setState(() => _answer = answer);
    await _speakSafely(answer);
    if (widget.embedded) await navigator.maybePop();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await navigator.push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _beginMessageDraft({
    required String? contactName,
    required String? content,
  }) async {
    final name = contactName?.trim() ?? '';
    if (name.isEmpty) {
      _pendingMessage = const _PendingVoiceMessage();
      await _setCallAnswer('Bác muốn nhắn tin cho ai ạ?');
      return;
    }
    if (!SupabaseBootstrap.enabled ||
        Supabase.instance.client.auth.currentUser == null) {
      await _setCallAnswer(
        'Bác đăng nhập tài khoản DiVie rồi con mới gửi được tin nhắn nhé.',
      );
      return;
    }
    final recipient = await _findDiVieContact(name);
    if (recipient == null) return;
    final message = content?.trim() ?? '';
    if (message.isEmpty) {
      _pendingMessage = _PendingVoiceMessage(recipient: recipient);
      await _setCallAnswer('Bác muốn nhắn gì cho ${recipient.name} ạ?');
      return;
    }
    _pendingMessage = _PendingVoiceMessage(
      recipient: recipient,
      content: message,
    );
    await _askForMessageConfirmation(recipient, message);
  }

  Future<ContactRecord?> _findDiVieContact(String requestedName) async {
    final target = _normalizedText(requestedName);
    final contacts = await AppDataService(
      Supabase.instance.client,
    ).loadContacts();
    final matches = contacts
        .where((contact) {
          final name = _normalizedText(contact.name);
          return name == target ||
              name.contains(target) ||
              target.contains(name);
        })
        .toList(growable: false);
    if (matches.isEmpty) {
      _pendingMessage = null;
      await _setCallAnswer(
        'Con không tìm thấy “$requestedName” trong danh bạ DiVie. Bác nói đúng tên người nhận giúp con nhé.',
      );
      return null;
    }
    if (matches.length > 1) {
      _pendingMessage = null;
      await _setCallAnswer(
        'Con tìm thấy nhiều người tên “$requestedName”. Bác nói tên đầy đủ hơn giúp con nhé.',
      );
      return null;
    }
    return matches.single;
  }

  Future<void> _continueMessageDraft(String transcript) async {
    final draft = _pendingMessage;
    if (draft == null) return;
    final normalized = _normalizedText(transcript);
    if (_isVoiceCancellation(normalized)) {
      _pendingMessage = null;
      await _setCallAnswer('Con đã hủy soạn tin nhắn nhé.');
      return;
    }
    if (draft.recipient == null) {
      await _beginMessageDraft(contactName: transcript, content: null);
      return;
    }
    if (draft.content == null || draft.content!.trim().isEmpty) {
      _pendingMessage = draft.copyWith(content: transcript.trim());
      await _askForMessageConfirmation(draft.recipient!, transcript.trim());
      return;
    }
    if (!_isVoiceConfirmation(normalized)) {
      await _setCallAnswer('Bác nói “gửi đi” để con gửi, hoặc nói “hủy” nhé.');
      return;
    }
    final recipient = draft.recipient!;
    final content = draft.content!.trim();
    try {
      final service = AppDataService(Supabase.instance.client);
      final roomId = await service.createOrGetDirectChat(recipient.id);
      await service.sendMessage(roomId, content);
      _pendingMessage = null;
      await _setCallAnswer(
        'Con đã gửi tin cho ${recipient.name} rồi ạ. Con mở cuộc trò chuyện cho bác nhé.',
      );
      await _openMessageThread(recipient);
    } catch (error) {
      debugPrint('DiVie voice message send failed: $error');
      await _setCallAnswer('Con chưa gửi được tin. Bác thử lại giúp con nhé.');
    }
  }

  Future<void> _askForMessageConfirmation(
    ContactRecord recipient,
    String content,
  ) => _setCallAnswer(
    'Bác muốn gửi cho ${recipient.name}: “$content”. Bác nói “gửi đi” để xác nhận nhé.',
  );

  bool _isVoiceConfirmation(String value) => RegExp(
    r'\b(?:gui di|gui|dong y|xac nhan|duoc|ok|oke|duoc roi)\b',
  ).hasMatch(value);

  bool _isVoiceCancellation(String value) =>
      RegExp(r'\b(?:huy|khong gui|thoi|bo qua)\b').hasMatch(value);

  Future<void> _openMessageThread(ContactRecord recipient) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (widget.embedded) await navigator.maybePop();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => LiveMessagesPage(
          initialRecipientId: recipient.id,
          initialRecipientName: recipient.name,
        ),
      ),
    );
  }

  _HealthVoiceAction? _healthActionFor(String value) {
    final text = _normalizedText(value);
    final mentionsHealth =
        text.contains('huyet ap') ||
        text.contains('suc khoe') ||
        text.contains('chi so') ||
        text.contains('may do');
    if (text.contains('bieu do') ||
        text.contains('xu huong') ||
        text.contains('lich su suc khoe')) {
      return _HealthVoiceAction.insights;
    }
    if (mentionsHealth &&
        (text.contains('chup') ||
            text.contains('doc') ||
            text.contains('do huyet ap'))) {
      return _HealthVoiceAction.capture;
    }
    return null;
  }

  String? _callTargetFor(String value) {
    final match = RegExp(
      r'(?:^|\s)(?:goi(?: dien)?|lien lac(?: voi)?)\s+(?:cho\s+)?(.+?)$',
    ).firstMatch(_normalizedText(value));
    if (match == null) return null;

    final target = (match.group(1) ?? '')
        .replaceFirst(
          RegExp(r'(?:\s+(?:cua toi|cua minh|nhe|di|voi|nha|duoc khong))+$'),
          '',
        )
        .trim();
    if (target.isEmpty || target == 'toi' || target == 'minh') return null;
    return target;
  }

  bool _looksLikeCallIntent(String value) =>
      RegExp(r'\b(?:goi|lien lac)\b').hasMatch(_normalizedText(value));

  Future<void> _handleVoiceCall(String target) async {
    try {
      final permitted = await FlutterContacts.requestPermission(readonly: true);
      if (!permitted) {
        debugPrint('DiVie voice call lookup: contacts permission denied.');
        await _setCallAnswer(
          'Con cần được cho phép đọc danh bạ để tìm “$target”.',
        );
        return;
      }

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        sorted: true,
        deduplicateProperties: true,
      );
      final matches = contacts
          .where(
            (contact) =>
                _normalizedText(contact.displayName) == target ||
                _normalizedText(contact.displayName).contains(target),
          )
          .toList();
      debugPrint(
        'DiVie voice call lookup: target="$target", matches=${matches.length}.',
      );
      if (matches.isEmpty) {
        await _setCallAnswer(
          'Con chưa tìm thấy “$target” trong danh bạ điện thoại nên chưa thể mở cuộc gọi.',
        );
        return;
      }

      final exactMatches = matches
          .where((contact) => _normalizedText(contact.displayName) == target)
          .toList();
      final candidates = exactMatches.isNotEmpty ? exactMatches : matches;
      if (candidates.length > 1) {
        await _setCallAnswer(
          'Con tìm thấy nhiều người tên “$target”. Bác hãy đặt tên rõ hơn trong danh bạ rồi thử lại nhé.',
        );
        return;
      }

      final contact = candidates.single;
      final phone = contact.phones
          .map((item) => item.number.trim())
          .firstWhere((number) => number.isNotEmpty, orElse: () => '');
      if (phone.isEmpty) {
        debugPrint(
          'DiVie voice call lookup: matched contact has no phone number.',
        );
        await _setCallAnswer(
          'Con đã tìm thấy ${contact.displayName}, nhưng danh bạ chưa có số điện thoại.',
        );
        return;
      }

      final answer = 'Con mở cuộc gọi đến ${contact.displayName} nhé.';
      if (mounted) setState(() => _answer = answer);
      unawaited(_speakSafely(answer));
      await EmergencyService.callNumber(phone);
      debugPrint('DiVie voice call lookup: dialer opened.');
    } catch (error, stackTrace) {
      debugPrint('DiVie voice call lookup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _setCallAnswer(
        'Con chưa mở được cuộc gọi. Bác kiểm tra lại danh bạ rồi thử lại nhé.',
      );
    }
  }

  Future<void> _setCallAnswer(String answer) async {
    if (mounted) setState(() => _answer = answer);
    await _speakSafely(answer);
  }

  String _normalizedText(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
      .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
      .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
      .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
      .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
      .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
      .replaceAll('đ', 'd')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<void> _openHealthAction(_HealthVoiceAction action) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final answer = action == _HealthVoiceAction.capture
        ? 'Con mở camera để chụp máy đo huyết áp nhé.'
        : 'Con mở biểu đồ sức khỏe cho bác nhé.';
    if (mounted) setState(() => _answer = answer);
    await _speakSafely(answer);
    if (widget.embedded) await navigator.maybePop();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => action == _HealthVoiceAction.capture
            ? const HealthCapturePage()
            : const HealthInsightsPage(),
      ),
    );
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
            'Ví dụ: “Nhắc con uống thuốc lúc 4 giờ chiều”.',
            style: TextStyle(color: DivieColors.muted, fontSize: 16),
          ),
          const SizedBox(height: 22),
          _VoiceBubble(
            label: 'Bác nói',
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_listening && _transcript.isNotEmpty) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                _transcript,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: DivieColors.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          _VoiceWave(listening: _listening, processing: _sending),
          const SizedBox(height: 26),
          FloatingActionButton.large(
            heroTag: 'assistant-floating-mic',
            backgroundColor: _listening ? DivieColors.danger : DivieColors.teal,
            onPressed: _sending ? null : _toggleListening,
            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 38),
          ),
          const SizedBox(height: 10),
          Text(
            _sending
                ? 'DiVie đang xử lý'
                : (_listening
                      ? 'Đang nghe, chạm lại để dừng'
                      : 'Chạm vào micro để bật mic'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: DivieColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
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
