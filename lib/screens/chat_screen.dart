import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../services/firestore_service.dart';
import '../services/api_service.dart';
import '../services/call_service.dart';
import '../services/websocket_service.dart';
import 'call_screen.dart';

class ChatScreen extends StatefulWidget {
  final ConversationModel conversation;
  final String myUid;
  const ChatScreen({super.key, required this.conversation, required this.myUid});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  String? _replyToId;

  String get _otherUid => widget.conversation.otherUid(widget.myUid);
  Map<String, dynamic> get _otherP => widget.conversation.otherParticipant(widget.myUid);

  @override
  void initState() {
    super.initState();
    WebSocketService.on('call_answer', _onAnswer);
    WebSocketService.on('call_ice',    _onIce);
  }

  void _onAnswer(Map<String, dynamic> msg) {
    if ((msg['fromUid'] ?? '') == _otherUid) {
      CallService.handleCallAnswer(msg['sdp'] as Map<String, dynamic>);
    }
  }

  void _onIce(Map<String, dynamic> msg) {
    if ((msg['fromUid'] ?? '') == _otherUid) {
      CallService.addIceCandidate(msg['candidate'] as Map<String, dynamic>);
    }
  }

  @override
  void dispose() {
    WebSocketService.off('call_answer', _onAnswer);
    WebSocketService.off('call_ice',    _onIce);
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendText() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _ctrl.clear();
    try {
      await FirestoreService.sendMessage(
        widget.conversation.id, widget.myUid,
        type: 'text', content: text, replyToId: _replyToId,
      );
      if (_replyToId != null) setState(() => _replyToId = null);
      _scrollToBottom();
      if (_otherUid.isNotEmpty) {
        ApiService.sendNotification(
          targetUid: _otherUid,
          title: (_otherP['displayName'] ?? 'Message') as String,
          body: text,
        ).ignore();
      }
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _uploadAndSend(String path, String mime, String name, String type) async {
    try {
      final bytes = await File(path).readAsBytes();
      final result = await ApiService.uploadFile(
        base64: 'data:$mime;base64,${base64Encode(bytes)}',
        mimeType: mime, fileName: name,
      );
      await FirestoreService.sendMessage(
        widget.conversation.id, widget.myUid,
        type: type, fileUrl: result['url'] as String,
        fileName: name, fileSize: result['size'] as int?, mimeType: mime,
      );
      _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (p == null) return;
    await _uploadAndSend(p.path, 'image/jpeg', p.name, 'image');
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.platform.pickFiles();
    if (r == null || r.files.isEmpty || r.files.first.path == null) return;
    final f = r.files.first;
    await _uploadAndSend(f.path!, 'application/${f.extension ?? 'octet-stream'}', f.name, 'file');
  }

  void _call(bool isVideo) => Navigator.push(context, MaterialPageRoute(
    builder: (_) => CallScreen(
      otherUid: _otherUid,
      otherName: _otherP['displayName'] as String? ?? 'Unknown',
      otherPhoto: _otherP['photoUrl'] as String?,
      isVideo: isVideo, isIncoming: false,
      convId: widget.conversation.id,
    ),
  ));

  @override
  Widget build(BuildContext context) {
    final otherName  = widget.conversation.displayName(widget.myUid);
    final otherPhoto = widget.conversation.displayPhoto(widget.myUid);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00A884),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white24,
            backgroundImage: otherPhoto != null ? NetworkImage(otherPhoto) : null,
            child: otherPhoto == null
                ? Text(otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 16))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(otherName,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.videocam, color: Colors.white), onPressed: () => _call(true)),
          IconButton(icon: const Icon(Icons.call,     color: Colors.white), onPressed: () => _call(false)),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<List<MessageModel>>(
            stream: FirestoreService.messagesStream(widget.conversation.id),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final msgs = snap.data ?? [];
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                itemCount: msgs.length,
                itemBuilder: (_, i) {
                  final msg = msgs[i];
                  final isMe = msg.senderId == widget.myUid;
                  return _MsgBubble(
                    msg: msg, isMe: isMe,
                    onReply: (id) => setState(() => _replyToId = id),
                    onDelete: () => FirestoreService.deleteMessage(widget.conversation.id, msg.id),
                  );
                },
              );
            },
          ),
        ),
        if (_replyToId != null)
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(children: [
              const Icon(Icons.reply, color: Color(0xFF00A884)),
              const SizedBox(width: 8),
              const Expanded(child: Text('Replying…', style: TextStyle(color: Colors.grey))),
              IconButton(icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _replyToId = null)),
            ]),
          ),
        _inputBar(),
      ]),
    );
  }

  Widget _inputBar() => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: Row(children: [
      IconButton(
        icon: const Icon(Icons.attach_file, color: Color(0xFF00A884)),
        onPressed: () => showModalBottomSheet(context: context, builder: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.image), title: const Text('Image'),
                onTap: () { Navigator.pop(context); _pickImage(); }),
            ListTile(leading: const Icon(Icons.attach_file), title: const Text('File'),
                onTap: () { Navigator.pop(context); _pickFile(); }),
          ],
        )),
      ),
      Expanded(child: TextField(
        controller: _ctrl,
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'Message',
          filled: true, fillColor: const Color(0xFFF0F0F0),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      )),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: _sending ? null : _sendText,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(color: Color(0xFF00A884), shape: BoxShape.circle),
          child: _sending
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.send, color: Colors.white, size: 20),
        ),
      ),
    ]),
  );
}

class _MsgBubble extends StatelessWidget {
  final MessageModel msg;
  final bool isMe;
  final void Function(String id) onReply;
  final VoidCallback onDelete;
  const _MsgBubble({required this.msg, required this.isMe, required this.onReply, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => showModalBottomSheet(context: context, builder: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.reply), title: const Text('Reply'),
                onTap: () { Navigator.pop(context); onReply(msg.id); }),
            if (isMe) ListTile(leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(context); onDelete(); }),
          ],
        )),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFD9FDD3) : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(isMe ? 12 : 0),
              bottomRight: Radius.circular(isMe ? 0 : 12),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 2)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (msg.type == 'image' && msg.fileUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(msg.fileUrl!, width: 220, fit: BoxFit.cover),
              )
            else if (msg.fileUrl != null)
              Row(children: [
                const Icon(Icons.attach_file, size: 18, color: Color(0xFF00A884)),
                const SizedBox(width: 6),
                Flexible(child: Text(msg.fileName ?? 'File', overflow: TextOverflow.ellipsis)),
              ])
            else
              Text(msg.content ?? '', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 2),
            Text(
              '${msg.createdAt.hour.toString().padLeft(2,'0')}:${msg.createdAt.minute.toString().padLeft(2,'0')}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ]),
        ),
      ),
    );
  }
}
