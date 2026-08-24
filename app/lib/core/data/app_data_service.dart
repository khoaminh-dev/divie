import 'package:supabase_flutter/supabase_flutter.dart';

class ContactRecord {
  const ContactRecord({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.initials,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String initials;
}

class ConversationRecord {
  const ConversationRecord({
    required this.id,
    required this.title,
    required this.preview,
    required this.timeLabel,
    required this.lastMessageAt,
    required this.otherUserId,
  });

  final String id;
  final String title;
  final String preview;
  final String timeLabel;
  final DateTime? lastMessageAt;
  final String? otherUserId;
}

class MessageRecord {
  const MessageRecord({
    required this.id,
    required this.content,
    required this.senderId,
    required this.createdAt,
  });

  final String id;
  final String content;
  final String senderId;
  final DateTime createdAt;
}

class AppDataService {
  AppDataService(this.client);

  final SupabaseClient client;

  String get _userId =>
      client.auth.currentUser?.id ??
      (throw StateError('Phiên đăng nhập Supabase đã hết hạn.'));

  Future<List<ContactRecord>> loadContacts() async {
    final rows = await client
        .from('profiles')
        .select('id, full_name, email, phone_number')
        .neq('id', _userId)
        .order('full_name');

    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(_contactFromRow)
        .toList();
  }

  /// Finds one DiVie account from a Vietnamese mobile number without relying
  /// on a name match. Numbers are stored in the canonical 0xxxxxxxxx format.
  Future<ContactRecord?> findContactByPhone(String value) async {
    final phone = normalizeVietnamesePhone(value);
    if (!isValidVietnameseMobilePhone(phone)) {
      throw ArgumentError('Nhập số điện thoại Việt Nam hợp lệ.');
    }

    final rows = await client
        .from('profiles')
        .select('id, full_name, email, phone_number')
        .eq('phone_number', phone)
        .neq('id', _userId)
        .limit(1);
    final matches = (rows as List).whereType<Map<String, dynamic>>().toList();
    if (matches.isEmpty) return null;
    return _contactFromRow(matches.first);
  }

  static String normalizeVietnamesePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('84') && digits.length == 11) {
      return '0${digits.substring(2)}';
    }
    return digits;
  }

  static bool isValidVietnameseMobilePhone(String value) =>
      RegExp(r'^0(?:3|5|7|8|9)\d{8}$').hasMatch(value);

  Future<List<ConversationRecord>> loadConversations() async {
    final rows = await client
        .from('chat_participants')
        .select(
          'room_id, chat_rooms(id, name, last_message_text, last_message_time)',
        )
        .eq('profile_id', _userId);

    final result = <ConversationRecord>[];
    for (final item in (rows as List).whereType<Map<String, dynamic>>()) {
      final room =
          _asMap(item['chat_rooms']) ?? _asMapFromList(item['chat_rooms']);
      if (room == null) continue;
      final roomId = _asString(room['id']) ?? _asString(item['room_id']);
      if (roomId == null) continue;
      final participants = await client
          .from('chat_participants')
          .select('profile_id, profiles(full_name, email)')
          .eq('room_id', roomId)
          .neq('profile_id', _userId)
          .limit(1);
      final participantRows = participants
          .whereType<Map<String, dynamic>>()
          .toList();
      final otherParticipant = participantRows.isEmpty
          ? null
          : participantRows.first;
      final other =
          _asMap(otherParticipant?['profiles']) ??
          _asMapFromList(otherParticipant?['profiles']);
      final title =
          _asString(room['name']) ??
          _asString(other?['full_name']) ??
          _asString(other?['email']) ??
          'Cuộc trò chuyện';
      result.add(
        ConversationRecord(
          id: roomId,
          title: title,
          preview: _asString(room['last_message_text']) ?? 'Chưa có tin nhắn',
          timeLabel: _formatTime(room['last_message_time']),
          lastMessageAt: _parseDateTime(room['last_message_time']),
          otherUserId: _asString(otherParticipant?['profile_id']),
        ),
      );
    }
    result.sort((a, b) {
      final aTime = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return result;
  }

  Future<String> createOrGetDirectChat(String otherUserId) async {
    final result = await client.rpc(
      'create_or_get_direct_chat',
      params: {'other_user_id': otherUserId},
    );
    final roomId = _asString(result);
    if (roomId == null) {
      throw StateError('Supabase không trả về mã cuộc trò chuyện.');
    }
    return roomId;
  }

  Future<List<MessageRecord>> loadMessages(String roomId) async {
    final rows = await client
        .from('chat_messages')
        .select('id, content, sender_id, created_at')
        .eq('room_id', roomId)
        .eq('is_deleted', false)
        .order('created_at');
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => MessageRecord(
            id: _asString(row['id']) ?? '',
            content: _asString(row['content']) ?? '',
            senderId: _asString(row['sender_id']) ?? '',
            createdAt:
                DateTime.tryParse(_asString(row['created_at']) ?? '') ??
                DateTime.now(),
          ),
        )
        .toList();
  }

  Future<void> sendMessage(String roomId, String content) async {
    await client.from('chat_messages').insert({
      'room_id': roomId,
      'sender_id': _userId,
      'content': content.trim(),
      'type': 'text',
      'status': 'sent',
    });
    await client
        .from('chat_rooms')
        .update({
          'last_message_text': content.trim(),
          'last_message_time': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', roomId);
  }

  ContactRecord _contactFromRow(Map<String, dynamic> row) {
    final name =
        _asString(row['full_name']) ?? _asString(row['email']) ?? 'Người dùng';
    return ContactRecord(
      id: _asString(row['id']) ?? '',
      name: name,
      phone: _asString(row['phone_number']) ?? 'Chưa cập nhật số điện thoại',
      email: _asString(row['email']) ?? '',
      initials: _initials(name),
    );
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  static Map<String, dynamic>? _asMapFromList(Object? value) {
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }

  static String? _asString(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  static String _formatTime(Object? value) {
    final date = _parseDateTime(value)?.toLocal();
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  static DateTime? _parseDateTime(Object? value) {
    return DateTime.tryParse(_asString(value) ?? '');
  }
}
