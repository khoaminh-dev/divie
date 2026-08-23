import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/supabase_bootstrap.dart';
import '../../core/data/emergency_contacts_data_service.dart';
import '../../main.dart';

class EmergencyContactsPage extends StatefulWidget {
  const EmergencyContactsPage({super.key});

  @override
  State<EmergencyContactsPage> createState() => _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends State<EmergencyContactsPage> {
  late final EmergencyContactsDataService _service;
  final _controllers = List.generate(5, (_) => TextEditingController());
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _service = EmergencyContactsDataService(
      client: SupabaseBootstrap.enabled ? Supabase.instance.client : null,
    );
    _load();
  }

  Future<void> _load() async {
    try {
      final contacts = await _service.load();
      for (var index = 0; index < contacts.length && index < 5; index++) {
        _controllers[index].text = contacts[index];
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa tải được liên hệ khẩn cấp. Hãy thử lại sau.'),
          ),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.save(
        _controllers.map((controller) => controller.text).toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu danh sách liên hệ khẩn cấp.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chưa lưu được liên hệ. Hãy kiểm tra kết nối rồi thử lại.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DivieColors.background,
      appBar: AppBar(
        title: const Text('Liên hệ khẩn cấp'),
        foregroundColor: DivieColors.navy,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: DivieColors.teal),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                const Text(
                  'DiVie gọi số 1 trước. Nếu chưa liên lạc được, ứng dụng sẽ hiện các số tiếp theo để bạn gọi nhanh.',
                  style: TextStyle(color: DivieColors.muted, fontSize: 16),
                ),
                const SizedBox(height: 18),
                for (var index = 0; index < _controllers.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: _controllers[index],
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Số liên hệ ${index + 1}',
                        hintText: index == 0
                            ? 'Mặc định 115 nếu để trống'
                            : 'Không bắt buộc',
                        prefixIcon: const Icon(Icons.phone_rounded),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Đang lưu...' : 'Lưu danh sách'),
                  style: FilledButton.styleFrom(
                    backgroundColor: DivieColors.teal,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
