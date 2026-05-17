import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/haraya_widgets.dart';

class ChatScreen extends StatefulWidget {
  final int sellerId;
  final String sellerName;
  final Map<String, dynamic> currentUser;

  const ChatScreen({
    super.key,
    required this.sellerId,
    required this.sellerName,
    required this.currentUser,
  });

  int get _currentUserId {
    final id = currentUser['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '0') ?? 0;
  }

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();

  int? _roomId;
  List<dynamic> _messages = [];
  bool _loading  = true;
  bool _sending  = false;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    try {
      final result = await ApiService.createChat(widget.sellerId, widget._currentUserId);
      final roomId = result['room_id'] as int? ??
          (result['data'] != null ? result['data']['room_id'] as int? : null);
      if (roomId == null) {
        if (mounted) setState(() { _error = 'Failed to start chat.'; _loading = false; });
        return;
      }
      _roomId = roomId;
      await _loadMessages();
      _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _loadMessages());
    } catch (e) {
      if (mounted) setState(() { _error = 'Connection error. Please try again.'; _loading = false; });
    }
  }

  Future<void> _loadMessages() async {
    if (_roomId == null) return;
    try {
      final msgs = await ApiService.getChatMessages(_roomId!);
      if (!mounted) return;
      final wasAtBottom = _scrollCtrl.hasClients &&
          _scrollCtrl.offset >= _scrollCtrl.position.maxScrollExtent - 60;
      setState(() {
        _messages = msgs;
        _loading  = false;
      });
      if (wasAtBottom || _messages.length <= 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _roomId == null || _sending) return;
    _msgCtrl.clear();
    setState(() => _sending = true);
    try {
      await ApiService.sendMessage(roomId: _roomId!, message: text, senderId: widget._currentUserId);
      await _loadMessages();
    } catch (_) {
      if (mounted) showHarayaSnackBar(context, 'Failed to send message.', isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HarayaColors.sectionBg,
      appBar: AppBar(
        backgroundColor: HarayaColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storefront_rounded, size: 17, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.sellerName,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Seller',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          _InputBar(
            controller: _msgCtrl,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: HarayaColors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: HarayaColors.border),
            const SizedBox(height: 12),
            Text(_error!, style: GoogleFonts.poppins(color: HarayaColors.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            TextButton(onPressed: _initChat, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 52, color: HarayaColors.border),
            const SizedBox(height: 12),
            Text(
              'No messages yet.\nSay hello to ${widget.sellerName}!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: HarayaColors.textMuted, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _MessageBubble(
        message: _messages[i],
        isMe: _isMyMessage(_messages[i]),
      ),
    );
  }

  bool _isMyMessage(dynamic msg) {
    final senderId = msg['sender_id'];
    if (senderId is int) return senderId == widget._currentUserId;
    return int.tryParse(senderId?.toString() ?? '') == widget._currentUserId;
  }
}

// ── Message Bubble ─────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final dynamic message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final content    = (message['message'] ?? message['content'] ?? '').toString();
    final senderName = (message['sender_name'] ?? '').toString();
    final timestamp  = (message['timestamp'] ?? message['created_at'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe && senderName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                senderName,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: HarayaColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? HarayaColors.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    content,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: isMe ? Colors.white : HarayaColors.textDark,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (timestamp.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: Text(
                _formatTime(timestamp),
                style: GoogleFonts.poppins(fontSize: 9, color: HarayaColors.textLight),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(String ts) {
    try {
      final dt   = DateTime.parse(ts).toLocal();
      final h    = dt.hour;
      final m    = dt.minute.toString().padLeft(2, '0');
      final ampm = h >= 12 ? 'PM' : 'AM';
      final hour = h % 12 == 0 ? 12 : h % 12;
      return '$hour:$m $ampm';
    } catch (_) {
      return ts.length > 5 ? ts.substring(ts.length - 5) : ts;
    }
  }
}

// ── Input Bar ──────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: GoogleFonts.poppins(fontSize: 13, color: HarayaColors.textLight),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: HarayaColors.sectionBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(HarayaRadius.pill),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(HarayaRadius.pill),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(HarayaRadius.pill),
                  borderSide: const BorderSide(color: HarayaColors.primary, width: 1.5),
                ),
              ),
              style: GoogleFonts.poppins(fontSize: 13, color: HarayaColors.textDark),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: sending ? HarayaColors.border : HarayaColors.primary,
                shape: BoxShape.circle,
                boxShadow: sending
                    ? null
                    : const [
                        BoxShadow(
                          color: Color(0x445682B1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
              ),
              child: sending
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
