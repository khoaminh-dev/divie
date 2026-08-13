import 'package:flutter/material.dart';

import '../../core/device/emergency_contacts_store.dart';
import '../../main.dart';

class EmergencyContactsPage extends StatefulWidget {
  const EmergencyContactsPage({super.key});

  @override
  State<EmergencyContactsPage> createState() => _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends State<EmergencyContactsPage> {
  final _store = EmergencyContactsStore();
  final _controllers = List.generate(5, (_) => TextEditingController());
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final contacts = await _store.load();
    for (var index = 0; index < contacts.length && index < 5; index++) {
      _controllers[index].text = contacts[index];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _store.save(_controllers.map((controller) => controller.text).toList());
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu danh sách liên hệ khẩn cấp.')),
    );
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
          ? const Center(child: CircularProgressIndicator(color: DivieColors.teal))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                const Text(
                  'Khi bấm Khẩn cấp, DiVie sẽ gọi lần lượt từ số 1 đến số 5.',
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
                        hintText: index == 0 ? 'Mặc định 115 nếu để trống' : 'Không bắt buộc',
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ],
            ),
    );
  }
}
