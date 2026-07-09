import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frontend/utils/app_theme.dart';
import 'package:intl/intl.dart';
import '../../models/chat_message.dart';
import '../../models/users.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/user_service.dart';

class ChatScreen extends StatefulWidget {
  final String classId;
  final User otherUser;

  const ChatScreen({super.key, required this.classId, required this.otherUser});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late Future<List<ChatMessage>> _futureMessages;
  List<ChatMessage> _messages = [];
  String? _currentUserId;
  bool _sending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _futureMessages = _fetchMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        await _fetchMessages();
      } catch (_) {
        // Silent retry; keep existing messages visible.
      }
    });
  }

  Future<void> _loadCurrentUser() async {
    final me = await AuthService.getCurrentUserFromLocal();
    if (!mounted) return;
    setState(() {
      _currentUserId = me?.username; // 👈 เปลี่ยนเป็น username เพื่อเอาไว้เทียบกับชื่อตัวหนังสือที่มาจากหลังบ้าน
    });
  }

  Future<List<ChatMessage>> _fetchMessages() async {
    final messages = await ChatService.getConversation(widget.classId, widget.otherUser.userId);
    if (!mounted) return messages;
    setState(() {
      _messages = messages;
    });
    _scrollToBottom();
    return messages;
  }

  Future<void> _scrollToBottom() async {
    if (_scrollController.hasClients) {
      await Future.delayed(const Duration(milliseconds: 100));
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  CircleAvatar _buildProfileAvatar(User user, {double radius = 16}) {
    final url = UserService.absoluteAvatarUrl(user.avatarUrl);
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(url),
      );
    }
    final initial =
        (user.username.isNotEmpty
                ? user.username[0]
                : (user.email?.isNotEmpty == true ? user.email![0] : '?'))
            .toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade300,
      child: Text(initial, style: const TextStyle(color: Colors.black87)),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _sending = true;
    });

    try {
      final message = await ChatService.sendMessage(widget.classId, widget.otherUser.userId, text);
      _messageController.clear();
      setState(() {
        _messages = [..._messages, message];
      });
      _scrollToBottom();
      await _fetchMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ส่งข้อความไม่สำเร็จ: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isMine = msg.senderId == _currentUserId; 
    final alignment = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isMine ? const Color.fromARGB(255, 107, 161, 255) : const Color.fromARGB(255, 240, 238, 238);
    final textColor = isMine ? Colors.white : Colors.black87;
    final timeString = DateFormat('HH:mm').format(msg.createdAt.toLocal());

    return Align(
      alignment: alignment,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: 8,
          horizontal: 10,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment:
              isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine && msg.senderProfile != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildProfileAvatar(msg.senderProfile!, radius: 18),
              ),
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.65,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment:
                    isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.content,
                    style: TextStyle(color: textColor, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    timeString,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.75),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (isMine && msg.senderProfile != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _buildProfileAvatar(msg.senderProfile!, radius: 18),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Row(
          children: [
            _buildProfileAvatar(widget.otherUser, radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.otherUser.displayName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<ChatMessage>>(
              future: _futureMessages,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done && _messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('โหลดบทสนทนาไม่สำเร็จ: ${snapshot.error}'));
                }
                final messages = _messages;
                if (messages.isEmpty) {
                  return const Center(child: Text('ยังไม่มีข้อความในบทสนทนานี้'));
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 16, bottom: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(messages[index]);
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    keyboardType: TextInputType.text,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.none,
                    decoration: const InputDecoration(
                      hintText: 'พิมพ์ข้อความ...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _sending
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.send, color: AppColors.primary),
                  onPressed: _sending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
