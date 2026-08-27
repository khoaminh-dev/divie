import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/supabase_bootstrap.dart';
import '../../core/data/health_measurement_data_service.dart';
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
      if (continueAutomatically) await _scan();
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
      if (result.systolic == null &&
          result.diastolic == null &&
          result.pulse == null) {
        throw StateError('empty_reading');
      }
      if (mounted) setState(() => _reading = result);
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

  Future<void> _saveReading(BloodPressureReading reading) async {
    if (_saving) return;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu chỉ số vào lịch sử sức khỏe.')),
      );
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
              title: 'Đang đọc chỉ số',
              detail: 'Bác hãy kiểm tra rồi xác nhận trước khi lưu.',
            )
          else if (_image != null)
            FilledButton.icon(
              onPressed: _scan,
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

class _ReadingCard extends StatefulWidget {
  const _ReadingCard({
    required this.reading,
    required this.saving,
    required this.onSave,
  });

  final BloodPressureReading reading;
  final bool saving;
  final ValueChanged<BloodPressureReading> onSave;

  @override
  State<_ReadingCard> createState() => _ReadingCardState();
}

class _ReadingCardState extends State<_ReadingCard> {
  late final TextEditingController _systolic;
  late final TextEditingController _diastolic;
  late final TextEditingController _pulse;
  String? _error;

  @override
  void initState() {
    super.initState();
    _systolic = TextEditingController(text: _value(widget.reading.systolic));
    _diastolic = TextEditingController(text: _value(widget.reading.diastolic));
    _pulse = TextEditingController(text: _value(widget.reading.pulse));
  }

  @override
  void dispose() {
    _systolic.dispose();
    _diastolic.dispose();
    _pulse.dispose();
    super.dispose();
  }

  String _value(int? value) => value?.toString() ?? '';

  void _confirm() {
    final systolic = int.tryParse(_systolic.text.trim());
    final diastolic = int.tryParse(_diastolic.text.trim());
    final pulseText = _pulse.text.trim();
    final pulse = pulseText.isEmpty ? null : int.tryParse(pulseText);
    final invalid =
        systolic == null ||
        diastolic == null ||
        systolic < 50 ||
        systolic > 260 ||
        diastolic < 30 ||
        diastolic > 180 ||
        systolic <= diastolic ||
        (pulseText.isNotEmpty && (pulse == null || pulse < 25 || pulse > 240));
    if (invalid) {
      setState(() {
        _error = 'Bác kiểm tra lại các số trên máy đo trước khi lưu.';
      });
      return;
    }
    widget.onSave(
      BloodPressureReading(
        systolic: systolic,
        diastolic: diastolic,
        pulse: pulse,
        confidence: widget.reading.confidence,
        rawText: widget.reading.rawText,
      ),
    );
  }

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
          const SizedBox(height: 6),
          const Text(
            'Kiểm tra với màn hình máy đo. Bác có thể sửa số trước khi lưu.',
            style: TextStyle(color: Color(0xFF668092)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ReadingField(
                  controller: _systolic,
                  label: 'Tâm thu',
                  suffix: 'mmHg',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReadingField(
                  controller: _diastolic,
                  label: 'Tâm trương',
                  suffix: 'mmHg',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ReadingField(
            controller: _pulse,
            label: 'Nhịp tim',
            suffix: 'lần/phút',
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (widget.reading.confidence != null) ...[
            const SizedBox(height: 10),
            Text(
              'Độ chắc chắn OCR: ${(widget.reading.confidence! * 100).round()}%',
              style: const TextStyle(color: Color(0xFF668092)),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: widget.saving ? null : _confirm,
            child: Text(widget.saving ? 'Đang lưu…' : 'Xác nhận lưu'),
          ),
        ],
      ),
    ),
  );
}

class _ReadingField extends StatelessWidget {
  const _ReadingField({
    required this.controller,
    required this.label,
    required this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
    decoration: InputDecoration(
      labelText: label,
      suffixText: suffix,
      filled: true,
      fillColor: const Color(0xFFF7FBFC),
      border: const OutlineInputBorder(),
    ),
  );
}
