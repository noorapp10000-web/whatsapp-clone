import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/call_service.dart';
import 'call_screen.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final ConversationModel conversation;
  final int myUserId;

  const ChatScreen({
    super.key,
    required this.conversation,
    required this.myUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<MessageModel> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _isTyping = false;
  int? _replyToId;

  int get _otherUserId {
    final other = widget.conversation.participants.firstWhere(
      (p) => p['userId'] != widget.myUserId,
      orElse: () => widget.conversation.participants.isNotEmpty
          ? widget.conversation.participants.first
          : {},
    );
    return other['userId'] ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupWebSocket();
  }

  Future<void> _loadMessages() async {
    try {
      final data = await ApiService.getMessages(widget.conversation.id);
      if (mounted) {
        setState(() {
          _messages = (data['messages'] as List)
              .map((m) => MessageModel.fromJson(m))
              .toList();
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setupWebSocket() {
    WebSocketService.on('new-message', _onNewMessage);
    WebSocketService.on('typing', _onTyping);
    WebSocketService.on('message-deleted', _onMessageDeleted);
  }

  void _onNewMessage(Map<String, dynamic> msg) {
    final message = MessageModel.fromJson(msg['message']);
    if (message.conversationId == widget.conversation.id && mounted) {
      setState(() => _messages.add(message));
      _scrollToBottom();
    }
  }

  void _onTyping(Map<String, dynamic> msg) {
    if (msg['conversationId'] == widget.conversation.id && mounted) {
      setState(() => _isTyping = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isTyping = false);
      });
    }
  }

  void _onMessageDeleted(Map<String, dynamic> msg) {
    final msgId = msg['messageId'];
    if (mounted) {
      setState(() {
        _messages.removeWhere((m) => m.id == msgId);
      });
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      await ApiService.sendMessage(
        widget.conversation.id,
        content: text,
        replyToId: _replyToId,
      );
      setState(() => _replyToId = null);
    } catch (_) {}
    setState(() => _sending = false);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    await _uploadAndSend(picked.path, 'image/jpeg', picked.name, 'image');
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;
    final file = result.files.single;
    await _uploadAndSend(file.path!, file.extension ?? 'bin', file.name, 'file');
  }

  Future<void> _uploadAndSend(
      String path, String mimeType, String fileName, String type) async {
    try {
      final bytes = await File(path).readAsBytes();
      final base64 = 'data:$mimeType;base64,${base64Encode(bytes)}';
      final uploaded = await ApiService.uploadFile(
        base64: base64,
        mimeType: mimeType,
        fileName: fileName,
      );
      await ApiService.sendMessage(
        widget.conversation.id,
        type: type,
        fileUrl: uploaded['url'],
        fileName: fileName,
        fileSize: uploaded['bytes'],
        mimeType: mimeType,
      );
    } catch (_) {}
  }

  void _startVoiceCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          otherUserId: _otherUserId,
          otherName: widget.conversation.displayName(widget.myUserId),
          otherPhoto: widget.conversation.displayPhoto(widget.myUserId),
          isVideo: false,
          isIncoming: false,
          conversationId: widget.conversation.id,
        ),
      ),
    );
  }

  void _startVideoCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          otherUserId: _otherUserId,
          otherName: widget.conversation.displayName(widget.myUserId),
          otherPhoto: widget.conversation.displayPhoto(widget.myUserId),
          isVideo: true,
          isIncoming: false,
          conversationId: widget.conversation.id,
        ),
      ),
    );
  }

  @override
  void dispose() {
    WebSocketService.off('new-message', _onNewMessage);
    WebSocketService.off('typing', _onTyping);
    WebSocketService.off('message-deleted', _onMessageDeleted);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.conversation.displayName(widget.myUserId);
    final photo = widget.conversation.displayPhoto(widget.myUserId);
    final isOnline = widget.conversation.isOtherOnline(widget.myUserId);

    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00A884),
        leading: Row(
          children: [
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              backgroundImage: photo != null ? NetworkImage(photo) : null,
              child: photo == null
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Color(0xFF00A884)))
                  : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text(
                  _isTyping
                      ? 'typing...'
                      : isOnline
                          ? 'online'
                          : 'offline',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            onPressed: _startVideoCall,
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: _startVoiceCall,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) => MessageBubble(
                      message: _messages[i],
                      isMe: _messages[i].senderId == widget.myUserId,
                      onReply: (id) => setState(() => _replyToId = id),
                      onDelete: (id) async {
                        await ApiService.deleteMessage(id);
                      },
                    ),
                  ),
          ),
          if (_replyToId != null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.reply, color: Color(0xFF00A884)),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: Text('Replying to message',
                          style: TextStyle(color: Colors.grey))),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _replyToId = null),
                  ),
                ],
              ),
            ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file, color: Colors.grey),
            onPressed: _pickFile,
          ),
          IconButton(
            icon: const Icon(Icons.image, color: Colors.grey),
            onPressed: _pickImage,
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              onChanged: (v) {
                if (_otherUserId != 0) {
                  WebSocketService.sendTyping(
                      widget.conversation.id, _otherUserId);
                }
              },
              decoration: InputDecoration(
                hintText: 'Message',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFFF0F0F0),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sending ? null : _sendText,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF00A884),
                shape: BoxShape.circle,
              ),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
