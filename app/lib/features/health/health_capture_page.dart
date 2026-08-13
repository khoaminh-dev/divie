import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/app_config.dart';
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
  String? _error;

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
            _ReadingCard(reading: _reading!),
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
  const _ReadingCard({required this.reading});
  final BloodPressureReading reading;
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
            onPressed: () => Navigator.pop(context, reading),
            child: const Text('Xác nhận lưu'),
          ),
        ],
      ),
    ),
  );
}
