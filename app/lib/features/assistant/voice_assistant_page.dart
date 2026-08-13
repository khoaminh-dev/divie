import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/supabase_bootstrap.dart';
import '../../core/config/app_config.dart';
import '../../main.dart';

class VoiceAssistantPage extends StatefulWidget {
  const VoiceAssistantPage({super.key});

  @override
  State<VoiceAssistantPage> createState() => _VoiceAssistantPageState();
}

class _VoiceAssistantPageState extends State<VoiceAssistantPage> {
  final _speech = SpeechToText();
  final _tts = FlutterTts();
  bool _ready = false;
  bool _listening = false;
  bool _sending = false;
  String _transcript = '';
  String _answer = '';

  @override
  void initState() {
    super.initState();
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
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      if (_transcript.trim().isNotEmpty) await _ask(_transcript.trim());
      return;
    }
    setState(() {
      _transcript = '';
      _answer = '';
      _listening = true;
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
          _speech.stop();
          setState(() => _listening = false);
          if (_transcript.trim().isNotEmpty) _ask(_transcript.trim());
        }
      },
    );
  }

  Future<void> _ask(String text) async {
    setState(() => _sending = true);
    try {
      final headers = {'Content-Type': 'application/json'};
      if (SupabaseBootstrap.enabled) {
        final token = Supabase.instance.client.auth.currentSession?.accessToken;
        if (token != null) headers['Authorization'] = 'Bearer $token';
      }
      final response = await http.post(
        Uri.parse('${AppConfig.voiceBaseUrl}/api/ai/chat'),
        headers: headers,
        body: jsonEncode({
          'messages': [
            {'role': 'system', 'content': 'Bạn là trợ lý DiVie cho người cao tuổi. Trả lời tiếng Việt ngắn, rõ, an toàn. Nếu người dùng yêu cầu nhắc thuốc, hãy xác nhận tên thuốc và thời gian cần thiết.'},
            {'role': 'user', 'content': text},
          ],
          'temperature': .3,
          'maxCompletionTokens': 300,
        }),
      ).timeout(const Duration(seconds: 45));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(body['message'] ?? body['error'] ?? 'Không gọi được trợ lý lúc này.');
      }
      final answer = (body['content'] ?? body['data']?['content'] ?? '').toString().trim();
      if (answer.isEmpty) throw Exception('Trợ lý chưa trả về nội dung.');
      if (!mounted) return;
      setState(() => _answer = answer);
      await _tts.speak(answer);
    } catch (error) {
      if (mounted) setState(() => _answer = 'Chưa kết nối được trợ lý: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trợ lý DiVie')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Nói điều bạn cần', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: DivieColors.navy)),
            const SizedBox(height: 8),
            const Text('Ví dụ: “Nhắc tôi uống thuốc lúc 4 giờ chiều”.', style: TextStyle(color: DivieColors.muted, fontSize: 16)),
            const SizedBox(height: 28),
            _VoiceBubble(label: 'Bạn nói', text: _transcript.isEmpty ? 'Bấm micro để bắt đầu' : _transcript),
            const SizedBox(height: 14),
            _VoiceBubble(label: 'DiVie trả lời', text: _sending ? 'Đang suy nghĩ…' : (_answer.isEmpty ? 'Chưa có câu trả lời' : _answer)),
            const Spacer(),
            Center(
              child: FloatingActionButton.large(
                backgroundColor: _listening ? DivieColors.danger : DivieColors.teal,
                onPressed: _toggleListening,
                child: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 36),
              ),
            ),
            const SizedBox(height: 12),
            Center(child: Text(!_ready ? 'Đang xin quyền micro…' : (_listening ? 'Đang nghe…' : 'Chạm để nói'), style: const TextStyle(color: DivieColors.muted, fontWeight: FontWeight.w700))),
          ],
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
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: DivieColors.teal, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Text(text, style: const TextStyle(color: DivieColors.navy, fontSize: 17, height: 1.35)),
    ]),
  );
}
