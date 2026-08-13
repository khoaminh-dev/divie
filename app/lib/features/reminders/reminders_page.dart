import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/supabase_bootstrap.dart';
import '../../core/data/reminder_data_service.dart';
import '../../core/roles/app_role.dart';
import 'notification_service.dart';
import 'reminder_model.dart';

const _teal = Color(0xFF12A9B5);
const _navy = Color(0xFF10264D);

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key, required this.role});

  final AppRole role;

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  late final ReminderDataService _service;
  List<MedicineReminder> _items = [];
  Map<int, String> _statuses = {};
  bool _loading = true;
  String? _error;
  RealtimeChannel? _realtimeChannel;

  bool get _isFamily => widget.role == AppRole.family;

  @override
  void initState() {
    super.initState();
    _service = ReminderDataService(
      client: SupabaseBootstrap.enabled ? Supabase.instance.client : null,
    );
    _load();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    if (!SupabaseBootstrap.enabled) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _realtimeChannel = Supabase.instance.client
        .channel('divie-reminders-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'medicine_reminders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'account_id',
            value: user.id,
          ),
          callback: (_) {
            if (mounted) unawaited(_load());
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'medicine_reminder_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'account_id',
            value: user.id,
          ),
          callback: (_) {
            if (mounted) unawaited(_load());
          },
        )
        .subscribe();
  }

  Future<void> _load() async {
    try {
      final items = await _service.load();
      final statuses = await _service.loadStatuses(DateTime.now());
      if (!_isFamily) {
        for (final item in items) {
          await NotificationService.instance.schedule(item);
        }
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _statuses = statuses;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được lịch nhắc thuốc.';
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final result = await showModalBottomSheet<MedicineReminder>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ReminderForm(),
    );
    if (result == null) return;
    try {
      final created = await _service.create(result);
      if (!_isFamily) {
        await NotificationService.instance.schedule(created);
      }
      if (!mounted) return;
      setState(() => _items = [..._items, created]..sort(_sortByTime));
    } catch (_) {
      _showError('Không tạo được lịch nhắc thuốc.');
    }
  }

  Future<void> _edit(MedicineReminder item) async {
    final result = await showModalBottomSheet<MedicineReminder>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReminderForm(initial: item),
    );
    if (result == null) return;
    try {
      await _service.update(result);
      if (!_isFamily) {
        await NotificationService.instance.schedule(result);
      }
      if (!mounted) return;
      setState(() {
        _items =
            _items
                .map((value) => value.id == result.id ? result : value)
                .toList()
              ..sort(_sortByTime);
      });
    } catch (_) {
      _showError('Không cập nhật được lịch nhắc thuốc.');
    }
  }

  Future<void> _toggle(MedicineReminder item, bool value) async {
    final updated = item.copyWith(enabled: value);
    setState(() {
      _items = _items
          .map((current) => current.id == item.id ? updated : current)
          .toList();
    });
    try {
      await _service.update(updated);
      if (!_isFamily) {
        await NotificationService.instance.schedule(updated);
      }
    } catch (_) {
      _showError('Không cập nhật được trạng thái lịch nhắc.');
    }
  }

  Future<void> _delete(MedicineReminder item) async {
    setState(
      () => _items = _items.where((current) => current.id != item.id).toList(),
    );
    try {
      await _service.delete(item);
      if (!_isFamily) {
        await NotificationService.instance.cancel(item.id);
      }
    } catch (_) {
      _showError('Không xóa được lịch nhắc thuốc.');
    }
  }

  Future<void> _markStatus(MedicineReminder item, String status) async {
    try {
      await _service.recordStatus(
        reminder: item,
        day: DateTime.now(),
        status: status,
      );
      if (!mounted) return;
      setState(() => _statuses = {..._statuses, item.id: status});
    } catch (_) {
      _showError('Không đồng bộ được trạng thái uống thuốc.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    final channel = _realtimeChannel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    super.dispose();
  }

  static int _sortByTime(MedicineReminder a, MedicineReminder b) =>
      a.time.compareTo(b.time);

  @override
  Widget build(BuildContext context) {
    final title = _isFamily ? 'Quản lý nhắc thuốc' : 'Thuốc hôm nay';
    return Scaffold(
      backgroundColor: const Color(0xFFF1FAFA),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        foregroundColor: _navy,
        elevation: 0,
        actions: [
          if (_isFamily)
            IconButton(onPressed: _add, icon: const Icon(Icons.add_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : _error != null
          ? Center(child: Text(_error!))
          : _items.isEmpty
          ? _EmptyReminders(onAdd: _isFamily ? _add : null, role: widget.role)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, index) => _isFamily
                    ? _FamilyReminderCard(
                        item: _items[index],
                        onToggle: (value) => _toggle(_items[index], value),
                        onEdit: () => _edit(_items[index]),
                        onDelete: () => _delete(_items[index]),
                      )
                    : _ElderReminderCard(
                        item: _items[index],
                        status: _statuses[_items[index].id],
                        onStatus: (status) =>
                            _markStatus(_items[index], status),
                      ),
              ),
            ),
      floatingActionButton: _isFamily && _items.isNotEmpty
          ? FloatingActionButton(onPressed: _add, child: const Icon(Icons.add))
          : null,
    );
  }
}

class _FamilyReminderCard extends StatelessWidget {
  const _FamilyReminderCard({
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final MedicineReminder item;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    child: ListTile(
      contentPadding: const EdgeInsets.fromLTRB(18, 8, 10, 8),
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFDDF8F8),
        child: Icon(Icons.medication_rounded, color: _teal),
      ),
      title: Text(
        item.name,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '${item.time}${item.note.isEmpty ? '' : ' · ${item.note}'}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch.adaptive(value: item.enabled, onChanged: onToggle),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Sửa lịch')),
              PopupMenuItem(value: 'delete', child: Text('Xóa lịch')),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ElderReminderCard extends StatelessWidget {
  const _ElderReminderCard({
    required this.item,
    required this.status,
    required this.onStatus,
  });

  final MedicineReminder item;
  final String? status;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    final completed = status == 'taken';
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 25,
                  backgroundColor: Color(0xFFDDF8F8),
                  child: Icon(Icons.medication_rounded, color: _teal, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.time,
                        style: const TextStyle(
                          color: _teal,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        item.name,
                        style: const TextStyle(
                          color: _navy,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (item.note.isNotEmpty) Text(item.note),
                    ],
                  ),
                ),
                if (completed)
                  const Chip(
                    label: Text('Đã uống'),
                    avatar: Icon(Icons.check, size: 16),
                    backgroundColor: Color(0xFFDDF8E9),
                  ),
              ],
            ),
            if (!completed) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => onStatus('taken'),
                      icon: const Icon(Icons.check),
                      label: const Text('Đã uống'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onStatus('snoozed'),
                      child: const Text('Để sau'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => onStatus('skipped'),
                    tooltip: 'Bỏ qua',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyReminders extends StatelessWidget {
  const _EmptyReminders({required this.onAdd, required this.role});

  final VoidCallback? onAdd;
  final AppRole role;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.alarm_add_rounded, size: 58, color: _teal),
          const SizedBox(height: 14),
          Text(
            role == AppRole.family
                ? 'Chưa có lịch nhắc thuốc'
                : 'Chưa có lịch thuốc hôm nay',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            role == AppRole.family
                ? 'Thêm giờ uống thuốc để DiVie báo đúng giờ mỗi ngày.'
                : 'Người thân chưa tạo lịch nhắc thuốc cho tài khoản này.',
            textAlign: TextAlign.center,
          ),
          if (onAdd != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Thêm lịch nhắc'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ReminderForm extends StatefulWidget {
  const _ReminderForm({this.initial});

  final MedicineReminder? initial;

  @override
  State<_ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends State<_ReminderForm> {
  late final TextEditingController _name;
  late final TextEditingController _note;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _note = TextEditingController(text: initial?.note ?? '');
    final parts = (initial?.time ?? '08:00').split(':');
    _time = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 8,
      minute: int.tryParse(parts.last) ?? 0,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      12,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.initial == null ? 'Thêm nhắc thuốc' : 'Sửa lịch nhắc',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tên thuốc',
            hintText: 'Ví dụ: Thuốc huyết áp',
          ),
        ),
        TextField(
          controller: _note,
          decoration: const InputDecoration(
            labelText: 'Ghi chú (không bắt buộc)',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: _time,
            );
            if (picked != null) setState(() => _time = picked);
          },
          icon: const Icon(Icons.schedule_rounded),
          label: Text('Nhắc lúc ${_time.format(context)}'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              MedicineReminder(
                id:
                    widget.initial?.id ??
                    DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
                name: name,
                time:
                    '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                note: _note.text.trim(),
                enabled: widget.initial?.enabled ?? true,
              ),
            );
          },
          child: Text(
            widget.initial == null ? 'Lưu lịch nhắc' : 'Cập nhật lịch',
          ),
        ),
      ],
    ),
  );
}
