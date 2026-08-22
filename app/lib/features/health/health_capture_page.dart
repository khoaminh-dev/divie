import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/auth/supabase_bootstrap.dart';
import '../../core/data/health_measurement_data_service.dart';
import 'health_insights_page.dart';
import 'ocr_service.dart';

class HealthCapturePage extends StatefulWidget {
  const HealthCapturePage({super.key});
  @override
  State<HealthCapturePage> createState() => _HealthCapturePageState();
}

class _HealthCapturePageState extends State<HealthCapturePage> {
  final _picker = ImagePicker();
  XFile? _image;
  Uint8List? _imageBytes;
  BloodPressureReading? _reading;
  bool _busy = false;
  bool _saving = false;
  String? _error;
  late final HealthMeasurementDataService _historyService;
  List<HealthMeasurementHistoryItem> _history = [];

  @override
  void initState() {
    super.initState();
    _historyService = HealthMeasurementDataService(
      client: SupabaseBootstrap.enabled ? Supabase.instance.client : null,
    );
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _historyService.load();
      if (mounted) setState(() => _history = history);
    } catch (_) {
      // OCR remains usable even if the history table is not available yet.
    }
  }

  Future<void> _pick(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (image == null) return;
    setState(() {
      _image = image;
      _imageBytes = null;
      _reading = null;
      _error = null;
    });
    final bytes = await image.readAsBytes();
    if (mounted) setState(() => _imageBytes = bytes);
  }

  Future<void> _scan() async {
    final image = _image;
    if (image == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await OcrService().scanBloodPressure(
        base64Image: base64Encode(await image.readAsBytes()),
        mimeType: image.mimeType ?? 'image/jpeg',
      );
      if (mounted) setState(() => _reading = result);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveReading() async {
    final reading = _reading;
    if (reading == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await _historyService.saveOcr(reading);
      if (!mounted) return;
      setState(() {
        _history = [saved, ..._history].take(20).toList();
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu chỉ số vào lịch sử sức khỏe.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            'Không lưu được lịch sử: ${error.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1FAFA),
      appBar: AppBar(
        title: const Text('Sức khỏe'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Đọc chỉ số từ ảnh',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Chụp rõ màn hình máy đo. Kết quả chỉ để ghi nhận, bạn cần kiểm tra và xác nhận trước khi lưu.',
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HealthInsightsPage()),
            ),
            icon: const Icon(Icons.insights_rounded),
            label: const Text('Xem biểu đồ & xu hướng'),
          ),
          const SizedBox(height: 12),
          if (_imageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.memory(
                _imageBytes!,
                height: 230,
                fit: BoxFit.contain,
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Chụp ảnh'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Chọn ảnh'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _image == null || _busy ? null : _scan,
            icon: const Icon(Icons.document_scanner),
            label: Text(_busy ? 'Đang đọc ảnh…' : 'Đọc chỉ số'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (_reading != null) ...[
            const SizedBox(height: 20),
            _ReadingCard(
              reading: _reading!,
              saving: _saving,
              onSave: _saveReading,
            ),
          ],
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 26),
            const Text(
              'Lịch sử gần đây',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ..._history.map(_HistoryTile.new),
          ],
          const SizedBox(height: 14),
          Text(
            'API OCR: ${AppConfig.voiceBaseUrl}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({
    required this.reading,
    required this.saving,
    required this.onSave,
  });
  final BloodPressureReading reading;
  final bool saving;
  final VoidCallback onSave;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Kết quả đọc được · hãy xác nhận',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          Text(
            'Huyết áp: ${reading.systolic ?? '—'} / ${reading.diastolic ?? '—'} mmHg',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          Text('Nhịp tim: ${reading.pulse ?? '—'} lần/phút'),
          if (reading.confidence != null)
            Text('Độ chắc chắn OCR: ${(reading.confidence! * 100).round()}%'),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: saving ? null : onSave,
            child: Text(saving ? 'Đang lưu…' : 'Xác nhận lưu'),
          ),
        ],
      ),
    ),
  );
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile(this.item);

  final HealthMeasurementHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final date = item.measuredAt.toLocal();
    final stamp =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.favorite_rounded, color: Color(0xFF12A9B5)),
        title: Text('${item.systolic ?? '—'} / ${item.diastolic ?? '—'} mmHg'),
        subtitle: Text('Nhịp tim ${item.pulse ?? '—'} · $stamp'),
      ),
    );
  }
}
