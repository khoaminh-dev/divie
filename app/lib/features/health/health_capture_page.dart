import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/supabase_bootstrap.dart';
import '../../core/data/health_measurement_data_service.dart';
import 'health_insights_page.dart';
import 'ocr_service.dart';

class HealthCapturePage extends StatefulWidget {
  const HealthCapturePage({super.key, this.openCameraImmediately = true});

  /// Opening Health from the home screen should start the one useful action:
  /// take a picture of the monitor. A manual route can still opt out later.
  final bool openCameraImmediately;

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
  bool _cameraLaunched = false;
  String? _error;
  late final HealthMeasurementDataService _historyService;

  @override
  void initState() {
    super.initState();
    _historyService = HealthMeasurementDataService(
      client: SupabaseBootstrap.enabled ? Supabase.instance.client : null,
    );
    if (widget.openCameraImmediately) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openCamera(isInitialLaunch: true),
      );
    }
  }

  Future<void> _openCamera({bool isInitialLaunch = false}) async {
    if (isInitialLaunch && _cameraLaunched) return;
    if (isInitialLaunch) _cameraLaunched = true;
    await _pick(ImageSource.camera, continueAutomatically: true);
  }

  Future<void> _pick(
    ImageSource source, {
    bool continueAutomatically = true,
  }) async {
    try {
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
      if (continueAutomatically) await _scan(saveAndOpenInsights: true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = source == ImageSource.camera
              ? 'DiVie chưa mở được camera. Hãy cho phép quyền camera rồi thử lại.'
              : 'DiVie chưa đọc được ảnh đã chọn. Hãy thử lại nhé.',
        );
      }
    }
  }

  Future<void> _scan({bool saveAndOpenInsights = false}) async {
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
      if (result.systolic == null &&
          result.diastolic == null &&
          result.pulse == null) {
        throw StateError('empty_reading');
      }
      if (mounted) setState(() => _reading = result);
      if (saveAndOpenInsights) await _saveReading(openInsights: true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Không đọc được chỉ số từ ảnh. Hãy chụp rõ màn hình máy đo rồi thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveReading({bool openInsights = false}) async {
    final reading = _reading;
    if (reading == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _historyService.saveOcr(reading);
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
      if (openInsights) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HealthInsightsPage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu chỉ số vào lịch sử sức khỏe.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            'Chưa thể lưu chỉ số lúc này. Hãy kiểm tra kết nối rồi thử lại.';
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
            'Đọc chỉ số máy đo',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Chụp rõ màn hình máy đo. DiVie sẽ đọc, lưu và mở biểu đồ sức khỏe cho bạn.',
          ),
          const SizedBox(height: 20),
          if (_imageBytes == null && _busy)
            const _CaptureProgress(
              title: 'Đang mở camera',
              detail: 'Chụp rõ phần màn hình máy đo huyết áp.',
            ),
          if (_imageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.memory(
                _imageBytes!,
                height: 230,
                fit: BoxFit.contain,
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: _image == null ? 128 : 104,
            child: FilledButton.icon(
              onPressed: _busy ? null : _openCamera,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF087A84),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              icon: const Icon(Icons.camera_alt_rounded, size: 42),
              label: Text(_image == null ? 'Chụp ảnh máy đo' : 'Chụp lại ảnh'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _pick(ImageSource.gallery),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF087A84),
                side: const BorderSide(color: Color(0xFF087A84), width: 1.5),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              icon: const Icon(Icons.photo_library_rounded, size: 24),
              label: const Text('Chọn ảnh đã chụp'),
            ),
          ),
          const SizedBox(height: 12),
          if (_busy)
            const _CaptureProgress(
              title: 'Đang đọc và lưu chỉ số',
              detail: 'Sau đó DiVie sẽ mở biểu đồ sức khỏe.',
            )
          else if (_image != null)
            FilledButton.icon(
              onPressed: () => _scan(saveAndOpenInsights: true),
              icon: const Icon(Icons.document_scanner),
              label: const Text('Đọc ảnh này'),
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
        ],
      ),
    );
  }
}

class _CaptureProgress extends StatelessWidget {
  const _CaptureProgress({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(detail, style: const TextStyle(color: Color(0xFF668092))),
            ],
          ),
        ),
      ],
    ),
  );
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
