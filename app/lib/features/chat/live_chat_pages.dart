import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/app_data_service.dart';
import '../../main.dart';

class LiveContactsPage extends StatefulWidget {
  const LiveContactsPage({super.key});

  @override
  State<LiveContactsPage> createState() => _LiveContactsPageState();
}

class _LiveContactsPageState extends State<LiveContactsPage> {
  late final AppDataService _service;
  late Future<List<ContactRecord>> _future;
  final _searchController = TextEditingController();
  String _query = '';
  Timer? _refreshTimer;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _service = AppDataService(Supabase.instance.client);
    _future = _service.loadContacts();
    _realtimeChannel = Supabase.instance.client
        .channel('divie-contacts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (_) {
            if (mounted) _reload();
          },
        )
        .subscribe();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _future = _service.loadContacts());
    });
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _future = _service.loadContacts());
  }

  void _search(String value) =>
      setState(() => _query = value.trim().toLowerCase());

  @override
  void dispose() {
    _refreshTimer?.cancel();
    final channel = _realtimeChannel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _LivePageFrame(
      headerColor: DivieColors.teal,
      hint: 'Tìm kiếm danh bạ...',
      controller: _searchController,
      onSearch: _search,
      onRefresh: _reload,
      body: FutureBuilder<List<ContactRecord>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: DivieColors.teal),
            );
          }
          if (snapshot.hasError) {
            return _DataError(error: snapshot.error, onRetry: _reload);
          }
          final contacts = (snapshot.data ?? const <ContactRecord>[])
              .where(
                (contact) =>
                    _query.isEmpty ||
                    contact.name.toLowerCase().contains(_query) ||
                    contact.phone.toLowerCase().contains(_query) ||
                    contact.email.toLowerCase().contains(_query),
              )
              .toList();
          if (contacts.isEmpty) {
            return const _EmptyState(
              icon: Icons.contacts_outlined,
              title: 'Chưa có danh bạ',
              subtitle: 'Danh bạ sẽ hiển thị khi có người dùng trong hệ thống.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: contacts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return _LiveContactTile(
                contact: contact,
                onTap: () async {
                  try {
                    final roomId = await _service.createOrGetDirectChat(
                      contact.id,
                    );
                    if (!context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _ChatDetailPage(
                          roomId: roomId,
                          title: contact.name,
                        ),
                      ),
                    );
                  } on PostgrestException catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Không thể mở cuộc trò chuyện: ${error.message}',
                          ),
                        ),
                      );
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class LiveMessagesPage extends StatefulWidget {
  const LiveMessagesPage({super.key});

  @override
  State<LiveMessagesPage> createState() => _LiveMessagesPageState();
}

class _LiveMessagesPageState extends State<LiveMessagesPage> {
  late final AppDataService _service;
  late Future<List<ConversationRecord>> _future;
  final _searchController = TextEditingController();
  String _query = '';
  Timer? _refreshTimer;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _service = AppDataService(Supabase.instance.client);
    _future = _service.loadConversations();
    _realtimeChannel = Supabase.instance.client
        .channel('divie-conversations')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_rooms',
          callback: (_) {
            if (mounted) _reload();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          callback: (_) {
            if (mounted) _reload();
          },
        )
        .subscribe();
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) setState(() => _future = _service.loadConversations());
    });
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _future = _service.loadConversations());
  }

  void _search(String value) =>
      setState(() => _query = value.trim().toLowerCase());

  @override
  void dispose() {
    _refreshTimer?.cancel();
    final channel = _realtimeChannel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _LivePageFrame(
      headerColor: const Color(0xFF168BEA),
      hint: 'Tìm bạn bè, tin nhắn...',
      controller: _searchController,
      onSearch: _search,
      onRefresh: _reload,
      body: FutureBuilder<List<ConversationRecord>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: DivieColors.teal),
            );
          }
          if (snapshot.hasError) {
            return _DataError(error: snapshot.error, onRetry: _reload);
          }
          final conversations = (snapshot.data ?? const <ConversationRecord>[])
              .where(
                (conversation) =>
                    _query.isEmpty ||
                    conversation.title.toLowerCase().contains(_query) ||
                    conversation.preview.toLowerCase().contains(_query),
              )
              .toList();
          if (conversations.isEmpty) {
            return const _EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Chưa có cuộc trò chuyện',
              subtitle: 'Mở Danh bạ và chọn một người để bắt đầu nhắn tin.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: conversations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return _ConversationTile(
                conversation: conversation,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _ChatDetailPage(
                      roomId: conversation.id,
                      title: conversation.title,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ChatDetailPage extends StatefulWidget {
  const _ChatDetailPage({required this.roomId, required this.title});

  final String roomId;
  final String title;

  @override
  State<_ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<_ChatDetailPage> {
  final _controller = TextEditingController();
  late final AppDataService _service;
  late Future<List<MessageRecord>> _future;
  Timer? _refreshTimer;
  RealtimeChannel? _realtimeChannel;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _service = AppDataService(Supabase.instance.client);
    _future = _service.loadMessages(widget.roomId);
    _realtimeChannel = Supabase.instance.client
        .channel('divie-room-${widget.roomId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: widget.roomId,
          ),
          callback: (_) {
            if (mounted && !_sending) {
              setState(() => _future = _service.loadMessages(widget.roomId));
            }
          },
        )
        .subscribe();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_sending) {
        setState(() => _future = _service.loadMessages(widget.roomId));
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    final channel = _realtimeChannel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _service.sendMessage(widget.roomId, text);
      _controller.clear();
      if (mounted) {
        setState(() => _future = _service.loadMessages(widget.roomId));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể gửi tin nhắn: ${_errorMessage(error)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: DivieColors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<MessageRecord>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: DivieColors.teal),
                  );
                }
                if (snapshot.hasError) {
                  return _DataError(
                    error: snapshot.error,
                    onRetry: () => setState(
                      () => _future = _service.loadMessages(widget.roomId),
                    ),
                  );
                }
                final messages = snapshot.data ?? const <MessageRecord>[];
                if (messages.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'Bắt đầu cuộc trò chuyện',
                    subtitle: 'Gửi tin nhắn đầu tiên.',
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(18),
                  itemCount: messages.length,
                  itemBuilder: (_, index) {
                    final message = messages[messages.length - 1 - index];
                    final mine = message.senderId == userId;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: mine ? DivieColors.teal : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          message.content,
                          style: TextStyle(
                            color: mine ? Colors.white : DivieColors.navy,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: DivieColors.teal,
                    ),
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePageFrame extends StatelessWidget {
  const _LivePageFrame({
    required this.headerColor,
    required this.hint,
    required this.controller,
    required this.onSearch,
    required this.onRefresh,
    required this.body,
  });

  final Color headerColor;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final VoidCallback onRefresh;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: headerColor,
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
          child: Row(
            children: [
              Expanded(
                child: _LiveSearchBar(
                  hint: hint,
                  controller: controller,
                  onChanged: onSearch,
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Làm mới',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: body,
          ),
        ),
      ],
    );
  }
}

class _LiveContactTile extends StatelessWidget {
  const _LiveContactTile({required this.contact, required this.onTap});

  final ContactRecord contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            _LiveInitialAvatar(contact.initials),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: const TextStyle(
                      color: DivieColors.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contact.phone,
                    style: const TextStyle(
                      color: DivieColors.muted,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chat_bubble_outline_rounded,
              color: DivieColors.teal,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final ConversationRecord conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            _LiveInitialAvatar(
              conversation.title.substring(0, 1).toUpperCase(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.title,
                    style: const TextStyle(
                      color: DivieColors.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conversation.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: DivieColors.muted,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              conversation.timeLabel,
              style: const TextStyle(color: DivieColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataError extends StatelessWidget {
  const _DataError({required this.onRetry, this.error});

  final VoidCallback onRetry;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: DivieColors.muted,
            size: 42,
          ),
          const SizedBox(height: 12),
          const Text(
            'Chưa tải được dữ liệu',
            style: TextStyle(
              color: DivieColors.navy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage(error),
            textAlign: TextAlign.center,
            style: TextStyle(color: DivieColors.muted),
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

String _errorMessage(Object? error) {
  if (error is PostgrestException) {
    final message = error.message.trim();
    if (message.isNotEmpty) return message;
  }
  if (error is AuthException) {
    final message = error.message.trim();
    if (message.isNotEmpty) return message;
  }
  return 'Kiểm tra quyền truy cập Supabase rồi thử lại.';
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: DivieColors.teal, size: 48),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: DivieColors.navy,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: DivieColors.muted, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _LiveSearchBar extends StatelessWidget {
  const _LiveSearchBar({
    required this.hint,
    required this.controller,
    required this.onChanged,
  });

  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70, fontSize: 17),
        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: .14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      style: const TextStyle(color: Colors.white, fontSize: 17),
    );
  }
}

class _LiveInitialAvatar extends StatelessWidget {
  const _LiveInitialAvatar(this.initials);

  final String initials;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: const Color(0xFFE9F1F5),
      child: Text(
        initials,
        style: const TextStyle(
          color: DivieColors.teal,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
