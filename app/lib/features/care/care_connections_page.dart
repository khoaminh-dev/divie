import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/supabase_bootstrap.dart';
import '../../core/data/care_relationship_service.dart';
import '../../core/roles/app_role.dart';

class CareConnectionsPage extends StatefulWidget {
  const CareConnectionsPage({super.key, required this.role});

  final AppRole role;

  @override
  State<CareConnectionsPage> createState() => _CareConnectionsPageState();
}

class _CareConnectionsPageState extends State<CareConnectionsPage> {
  final _phoneController = TextEditingController();
  CareRelationshipService? _service;
  List<CareRecipient> _recipients = const [];
  List<CareInvitation> _invitations = const [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (SupabaseBootstrap.enabled) {
      _service = CareRelationshipService(Supabase.instance.client);
    }
    unawaited(_load());
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final service = _service;
    if (service == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Cần kết nối tài khoản để quản lý người thân.';
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.role == AppRole.family) {
        final recipients = await service.loadRecipients();
        if (mounted) {
          setState(() => _recipients = recipients);
        }
      } else {
        final invitations = await service.loadInvitations();
        if (mounted) {
          setState(() => _invitations = invitations);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Chưa tải được kết nối chăm sóc. Bác thử lại sau nhé.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestConnection() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Nhập số điện thoại của người cao tuổi.');
      return;
    }
    final service = _service;
    if (service == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await service.requestByPhone(phone);
      _phoneController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã gửi lời mời. Chờ người cao tuổi chấp nhận trên app.',
          ),
        ),
      );
      await _load();
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _error = _friendlyError(error.message));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa gửi được lời mời. Thử lại sau nhé.');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _respond(CareInvitation invitation, bool accept) async {
    final service = _service;
    if (service == null) return;
    setState(() => _submitting = true);
    try {
      await service.respond(
        relationshipId: invitation.relationshipId,
        accept: accept,
      );
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa cập nhật được lời mời. Bác thử lại nhé.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _friendlyError(String value) {
    if (value.contains('profile_not_found')) {
      return 'Không tìm thấy tài khoản DiVie có số điện thoại này.';
    }
    if (value.contains('invalid_phone')) {
      return 'Số điện thoại chưa đúng định dạng Việt Nam.';
    }
    if (value.contains('cannot_connect_self')) {
      return 'Không thể kết nối tài khoản của chính mình.';
    }
    return 'Chưa gửi được lời mời. Thử lại sau nhé.';
  }

  @override
  Widget build(BuildContext context) {
    final isFamily = widget.role == AppRole.family;
    return Scaffold(
      appBar: AppBar(
        title: Text(isFamily ? 'Người được chăm sóc' : 'Lời mời chăm sóc'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            Text(
              isFamily ? 'Kết nối người thân' : 'Quyền chia sẻ chăm sóc',
              style: const TextStyle(
                color: Color(0xFF10264D),
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFamily
                  ? 'Nhập số điện thoại tài khoản DiVie của người cao tuổi. Dữ liệu chỉ được chia sẻ sau khi bác ấy đồng ý.'
                  : 'Bác tự quyết định ai được xem sức khỏe và hỗ trợ lịch thuốc của bác.',
              style: const TextStyle(color: Color(0xFF687582), height: 1.4),
            ),
            const SizedBox(height: 22),
            if (isFamily) ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại người cao tuổi',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _submitting ? null : _requestConnection,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Gửi lời mời kết nối'),
              ),
              const SizedBox(height: 24),
              const Text(
                'Đang chăm sóc',
                style: TextStyle(
                  color: Color(0xFF10264D),
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ] else
              const Text(
                'Lời mời đang chờ',
                style: TextStyle(
                  color: Color(0xFF10264D),
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            const SizedBox(height: 12),
            if (_error != null) _ErrorText(text: _error!),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(26),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (isFamily)
              _RecipientsList(recipients: _recipients)
            else
              _InvitationsList(
                invitations: _invitations,
                busy: _submitting,
                onRespond: _respond,
              ),
          ],
        ),
      ),
    );
  }
}

class _RecipientsList extends StatelessWidget {
  const _RecipientsList({required this.recipients});

  final List<CareRecipient> recipients;

  @override
  Widget build(BuildContext context) {
    if (recipients.isEmpty) {
      return const _EmptyCareState(
        icon: Icons.group_add_outlined,
        message:
            'Chưa có ai được kết nối. Sau khi bác ấy chấp nhận, sức khỏe và lịch thuốc sẽ xuất hiện trong dashboard.',
      );
    }
    return Column(
      children: recipients
          .map(
            (recipient) => Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.elderly_rounded)),
                title: Text(recipient.name),
                subtitle: Text(
                  recipient.phone.isEmpty
                      ? 'Đã kết nối DiVie'
                      : recipient.phone,
                ),
                trailing: const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF198754),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _InvitationsList extends StatelessWidget {
  const _InvitationsList({
    required this.invitations,
    required this.busy,
    required this.onRespond,
  });

  final List<CareInvitation> invitations;
  final bool busy;
  final Future<void> Function(CareInvitation invitation, bool accept) onRespond;

  @override
  Widget build(BuildContext context) {
    if (invitations.isEmpty) {
      return const _EmptyCareState(
        icon: Icons.mark_email_read_outlined,
        message: 'Chưa có lời mời nào đang chờ.',
      );
    }
    return Column(
      children: invitations
          .map(
            (invitation) => Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invitation.name,
                      style: const TextStyle(
                        color: Color(0xFF10264D),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (invitation.phone.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        invitation.phone,
                        style: const TextStyle(color: Color(0xFF687582)),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => onRespond(invitation, false),
                            child: const Text('Từ chối'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: busy
                                ? null
                                : () => onRespond(invitation, true),
                            child: const Text('Đồng ý'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _EmptyCareState extends StatelessWidget {
  const _EmptyCareState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
    child: Column(
      children: [
        Icon(icon, size: 42, color: const Color(0xFF12A9B5)),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF687582), height: 1.4),
        ),
      ],
    ),
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFECEA),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: const TextStyle(color: Color(0xFFAD2E24))),
  );
}
