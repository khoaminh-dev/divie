import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/supabase_bootstrap.dart';
import '../../core/data/emergency_contacts_data_service.dart';
import '../../core/device/emergency_contacts_store.dart';
import '../../main.dart';

class EmergencyContactsPage extends StatefulWidget {
  const EmergencyContactsPage({super.key});

  @override
  State<EmergencyContactsPage> createState() => _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends State<EmergencyContactsPage> {
  late final EmergencyContactsDataService _service;
  List<EmergencyContact> _contacts = <EmergencyContact>[];
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
      if (mounted) setState(() => _contacts = contacts);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa tải được liên hệ khẩn cấp. Hãy thử lại sau.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save({bool showSuccess = false}) async {
    setState(() => _saving = true);
    try {
      await _service.save(_contacts);
      if (!mounted || !showSuccess) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã lưu liên hệ khẩn cấp.')));
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

  Future<void> _editContact({int? index}) async {
    final initial = index == null ? null : _contacts[index];
    final result = await showDialog<EmergencyContact>(
      context: context,
      builder: (dialogContext) => _EmergencyContactDialog(initial: initial),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _contacts = [..._contacts, result];
      } else {
        _contacts = [
          for (var i = 0; i < _contacts.length; i++)
            if (i == index) result else _contacts[i],
        ];
      }
    });
    await _save(showSuccess: true);
  }

  Future<void> _deleteContact(int index) async {
    final contact = _contacts[index];
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa liên hệ?'),
        content: Text(
          'Xóa ${contact.displayName} khỏi danh sách liên hệ khẩn cấp?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: DivieColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (remove != true || !mounted) return;
    setState(() => _contacts = [..._contacts]..removeAt(index));
    await _save(showSuccess: true);
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
                  'DiVie gọi liên hệ đầu tiên trước. Bạn có thể đặt tên để dễ nhận biết người cần gọi.',
                  style: TextStyle(color: DivieColors.muted, fontSize: 16),
                ),
                const SizedBox(height: 18),
                if (_contacts.isEmpty)
                  const _EmptyContactsNotice()
                else
                  for (var index = 0; index < _contacts.length; index++) ...[
                    _EmergencyContactRow(
                      order: index + 1,
                      contact: _contacts[index],
                      enabled: !_saving,
                      onEdit: () => _editContact(index: index),
                      onDelete: () => _deleteContact(index),
                    ),
                    const SizedBox(height: 10),
                  ],
                if (_contacts.length < 5) ...[
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _editContact,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Thêm liên hệ khẩn cấp'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DivieColors.teal,
                      minimumSize: const Size.fromHeight(54),
                      side: const BorderSide(color: DivieColors.teal),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Text(
                  'Tối đa 5 liên hệ. Số đầu tiên là số DiVie ưu tiên gọi khi khẩn cấp.',
                  style: TextStyle(color: DivieColors.muted, fontSize: 13),
                ),
              ],
            ),
    );
  }
}

class _EmergencyContactRow extends StatelessWidget {
  const _EmergencyContactRow({
    required this.order,
    required this.contact,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  final int order;
  final EmergencyContact contact;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: ListTile(
      contentPadding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFFFE6E3),
        child: Text(
          '$order',
          style: const TextStyle(color: DivieColors.danger),
        ),
      ),
      title: Text(
        contact.name.trim().isEmpty ? 'Chưa đặt tên' : contact.name,
        style: const TextStyle(
          color: DivieColors.navy,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(contact.phone),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Chỉnh sửa liên hệ',
            onPressed: enabled ? onEdit : null,
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
            tooltip: 'Xóa liên hệ',
            onPressed: enabled ? onDelete : null,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    ),
  );
}

class _EmptyContactsNotice extends StatelessWidget {
  const _EmptyContactsNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Text(
      'Chưa có liên hệ khẩn cấp. Hãy thêm người thân để DiVie có thể gọi nhanh khi cần.',
      style: TextStyle(color: DivieColors.muted, height: 1.4),
    ),
  );
}

class _EmergencyContactDialog extends StatefulWidget {
  const _EmergencyContactDialog({this.initial});

  final EmergencyContact? initial;

  @override
  State<_EmergencyContactDialog> createState() =>
      _EmergencyContactDialogState();
}

class _EmergencyContactDialogState extends State<_EmergencyContactDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial?.name ?? '');
    _phoneController = TextEditingController(text: widget.initial?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Thêm liên hệ' : 'Chỉnh sửa liên hệ'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Tên gọi',
              hintText: 'Ví dụ: Con trai',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Nhập tên gọi để dễ nhận biết.'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Số điện thoại',
              prefixIcon: Icon(Icons.phone_rounded),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Nhập số điện thoại.'
                : null,
            onFieldSubmitted: (_) => _submit(),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Lưu')),
    ],
  );

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      EmergencyContact(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      ),
    );
  }
}
