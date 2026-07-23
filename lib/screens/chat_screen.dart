import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../services/firestore_service.dart';
import '../services/api_service.dart';
import '../services/call_service.dart';
import '../services/websocket_service.dart';
import '../widgets/message_bubble.dart';
import 'call_screen.dart';
import 'music_player_screen.dart';

class ChatScreen extends StatefulWidget {
  final ConversationModel conversation;
  final String myUid;

  const ChatScreen(
      {super.key, required this.conversation, required this.myUid});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  String? _replyToId;
  MessageModel? _replyMsg;

  // Typing
  bool _otherTyping = false;
  Timer? _typingTimer;
  bool _iAmTyping = false;
  Timer? _myTypingTimer;

  // Emoji
  bool _showEmoji = false;
  final _focusNode = FocusNode();

  // Audio recording
  final _recorder = AudioRecorder();
  bool _recording = false;
  String? _recordPath;

  String get _otherUid => widget.conversation.otherUid(widget.myUid);
  Map<String, dynamic> get _otherP =>
      widget.conversation.otherParticipant(widget.myUid);
  String get _convName => widget.conversation.displayName(widget.myUid);

  @override
  void initState() {
    super.initState();
    WebSocketService.on('call_answer', _onAnswer);
    WebSocketService.on('call_ice', _onIce);
    WebSocketService.on('typing_start', _onTypingStart);
    WebSocketService.on('typing_stop', _onTypingStop);
    FirestoreService.markMessagesRead(widget.conversation.id, widget.myUid)
        .ignore();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmoji) {
        setState(() => _showEmoji = false);
      }
    });
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

  void _onTypingStart(Map<String, dynamic> msg) {
    if ((msg['fromUid'] ?? '') != _otherUid) return;
    _typingTimer?.cancel();
    if (mounted) setState(() => _otherTyping = true);
    _typingTimer = Timer(const Duration(seconds: 4),
        () { if (mounted) setState(() => _otherTyping = false); });
  }

  void _onTypingStop(Map<String, dynamic> msg) {
    if ((msg['fromUid'] ?? '') != _otherUid) return;
    _typingTimer?.cancel();
    if (mounted) setState(() => _otherTyping = false);
  }

  void _onTextChanged(String v) {
    if (v.isNotEmpty && !_iAmTyping) {
      _iAmTyping = true;
      WebSocketService.sendTyping(_otherUid, isTyping: true);
    }
    _myTypingTimer?.cancel();
    _myTypingTimer = Timer(const Duration(seconds: 2), () {
      _iAmTyping = false;
      WebSocketService.sendTyping(_otherUid, isTyping: false);
    });
    setState(() {});
  }

  @override
  void dispose() {
    WebSocketService.off('call_answer', _onAnswer);
    WebSocketService.off('call_ice', _onIce);
    WebSocketService.off('typing_start', _onTypingStart);
    WebSocketService.off('typing_stop', _onTypingStop);
    _ctrl.dispose();
    _scroll.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    _myTypingTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  // ── Send text ──────────────────────────────────────────────────────────────
  Future<void> _sendText() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _ctrl.clear();
    try {
      await FirestoreService.sendMessage(
        widget.conversation.id,
        widget.myUid,
        type: 'text',
        content: text,
        replyToId: _replyToId,
      );
      setState(() { _replyToId = null; _replyMsg = null; });
      _scrollToBottom();
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  // ── Send image ─────────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource src) async {
    Navigator.pop(context);
    final p = await ImagePicker().pickImage(source: src, imageQuality: 80);
    if (p == null) return;
    setState(() => _sending = true);
    try {
      final bytes = await File(p.path).readAsBytes();
      final result = await ApiService.uploadFile(
        base64: 'data:image/jpeg;base64,${base64Encode(bytes)}',
        mimeType: 'image/jpeg',
        fileName: 'img_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await FirestoreService.sendMessage(
        widget.conversation.id,
        widget.myUid,
        type: 'image',
        fileUrl: result['url'] as String?,
        replyToId: _replyToId,
      );
      setState(() { _replyToId = null; _replyMsg = null; });
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
    if (mounted) setState(() => _sending = false);
  }

  // ── Send file ──────────────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    Navigator.pop(context);
    final result =
        await FilePicker.platform.pickFiles(withData: false, withReadStream: false);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    setState(() => _sending = true);
    try {
      final bytes = await File(file.path!).readAsBytes();
      final mime = _mimeForFile(file.extension ?? '');
      final uploaded = await ApiService.uploadFile(
        base64: 'data:$mime;base64,${base64Encode(bytes)}',
        mimeType: mime,
        fileName: file.name,
      );
      await FirestoreService.sendMessage(
        widget.conversation.id,
        widget.myUid,
        type: 'file',
        fileUrl: uploaded['url'] as String?,
        fileName: file.name,
        fileSize: file.size,
        mimeType: mime,
        replyToId: _replyToId,
      );
      setState(() { _replyToId = null; _replyMsg = null; });
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
    if (mounted) setState(() => _sending = false);
  }

  String _mimeForFile(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf': return 'application/pdf';
      case 'doc': case 'docx': return 'application/msword';
      case 'mp3': return 'audio/mpeg';
      case 'm4a': return 'audio/mp4';
      case 'ogg': return 'audio/ogg';
      case 'mp4': return 'video/mp4';
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      default: return 'application/octet-stream';
    }
  }

  // ── Voice recording ────────────────────────────────────────────────────────
  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() { _recording = true; _recordPath = path; });
  }

  Future<void> _stopRecordingAndSend() async {
    final path = await _recorder.stop();
    setState(() => _recording = false);
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) return;
    setState(() => _sending = true);
    try {
      final bytes = await file.readAsBytes();
      final durationMs = await _getAudioDuration(file);
      final uploaded = await ApiService.uploadFile(
        base64: 'data:audio/mp4;base64,${base64Encode(bytes)}',
        mimeType: 'audio/mp4',
        fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      await FirestoreService.sendMessage(
        widget.conversation.id,
        widget.myUid,
        type: 'voice',
        fileUrl: uploaded['url'] as String?,
        durationMs: durationMs,
        replyToId: _replyToId,
      );
      setState(() { _replyToId = null; _replyMsg = null; });
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ في إرسال الرسالة الصوتية: $e')));
    }
    if (mounted) setState(() => _sending = false);
    // Clean up
    file.delete().ignore();
  }

  Future<void> _cancelRecording() async {
    await _recorder.stop();
    setState(() => _recording = false);
  }

  Future<int?> _getAudioDuration(File file) async {
    // Approximate from file size: ~16kbps for AAC ≈ 2KB/s
    final size = await file.length();
    return (size / 2000 * 1000).round();
  }

  // ── Listen Together ────────────────────────────────────────────────────────
  Future<void> _sendListenTogether() async {
    Navigator.pop(context);
    // Host navigates to session FIRST, then invite is sent from there
    final sessionId =
        'lt_${widget.conversation.id}_${DateTime.now().millisecondsSinceEpoch}';
    await FirestoreService.createListenSessionById(sessionId, {
      'host': widget.myUid,
      'participants': [widget.myUid],
      'playlist': [],
      'currentIndex': 0,
    });

    // Send invite message in chat
    await FirestoreService.sendMessage(
      widget.conversation.id,
      widget.myUid,
      type: 'listen_together',
      content: 'دعوة للاستماع معاً 🎵',
      ltSessionId: sessionId,
      ltTitle: 'جلسة موسيقية مشتركة',
    );

    // Notify via WebSocket
    WebSocketService.sendLTInvite(_otherUid, sessionId);

    // HOST navigates to music player and stays there
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MusicPlayerScreen(
          sessionId: sessionId,
          otherUid: _otherUid,
          isHost: true,
        ),
      ),
    );
  }

  // ── React & Reply ──────────────────────────────────────────────────────────
  Future<void> _reactMsg(String msgId, String emoji) async {
    await FirestoreService.reactToMessage(
        widget.conversation.id, msgId, widget.myUid, emoji);
  }

  void _setReply(String msgId, List<MessageModel> msgs) {
    final msg = msgs.firstWhere((m) => m.id == msgId,
        orElse: () => msgs.first);
    setState(() { _replyToId = msgId; _replyMsg = msg; });
  }

  Future<void> _deleteMsg(String msgId) async {
    await FirestoreService.deleteMessage(widget.conversation.id, msgId);
  }

  Future<void> _joinListenSession(String sessionId) async {
    WebSocketService.sendLTAccept(widget.myUid, sessionId);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => MusicPlayerScreen(
        sessionId: sessionId,
        otherUid: _otherUid,
        isHost: false,
      ),
    ));
  }

  // ── Calls ──────────────────────────────────────────────────────────────────
  Future<void> _startCall(bool isVideo) async {
    final callId = await FirestoreService.logCall(
        widget.myUid, _otherUid, isVideo ? 'video' : 'voice');
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CallScreen(
        otherUid: _otherUid,
        otherName: (_otherP['displayName'] ?? _convName) as String,
        otherPhoto: _otherP['photoUrl'] as String?,
        isVideo: isVideo,
        isIncoming: false,
        convId: widget.conversation.id,
        callId: callId,
      ),
    ));
    ApiService.sendNotification(
      targetUid: _otherUid,
      title: isVideo ? '📹 مكالمة فيديو واردة' : '📞 مكالمة صوتية واردة',
      body: 'اضغط للرد',
      data: {
        'type': isVideo ? 'video_call' : 'voice_call',
        'callerUid': widget.myUid,
      },
    ).ignore();
  }

  // ── Attach menu ────────────────────────────────────────────────────────────
  void _showAttachMenu() {
    if (_showEmoji) setState(() => _showEmoji = false);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _menuItem(Icons.image, 'معرض الصور', Colors.purple,
                      () => _pickImage(ImageSource.gallery)),
                  _menuItem(Icons.camera_alt, 'الكاميرا', Colors.red,
                      () => _pickImage(ImageSource.camera)),
                  _menuItem(Icons.attach_file, 'ملف', Colors.teal,
                      _pickFile),
                  _menuItem(Icons.headphones, 'استماع معاً', Colors.blue,
                      _sendListenTogether),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, height: 1.2)),
        ],
      ),
    );
  }

  // ── Sticker picker (simple) ────────────────────────────────────────────────
  void _showStickerPicker() {
    const stickers = ['😀','😂','😍','🥰','😎','🤩','😢','😡','🥺','🤔',
      '👍','👎','❤️','🔥','🎉','🎊','💯','✅','🙏','🤣',
      '😮','😴','🤗','😏','🥳','💪','👏','🤝','✌️','🫡'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Text('الملصقات',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: stickers.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _ctrl.text += stickers[i];
                    setState(() {});
                  },
                  child: Text(stickers[i],
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGroup = widget.conversation.type == 'group';
    final photo = widget.conversation.displayPhoto(widget.myUid);

    return PopScope(
      canPop: !_showEmoji,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showEmoji) setState(() => _showEmoji = false);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF00A884),
          foregroundColor: Colors.white,
          titleSpacing: 0,
          leadingWidth: 32,
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                backgroundImage: photo != null ? NetworkImage(photo) : null,
                child: photo == null
                    ? Text(_convName.isNotEmpty ? _convName[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_convName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis),
                    if (_otherTyping)
                      const Text('يكتب...',
                          style: TextStyle(
                              fontSize: 12, color: Colors.white70))
                    else if (!isGroup)
                      StreamBuilder<bool>(
                        stream: FirestoreService.onlineStream(_otherUid),
                        builder: (_, snap) => Text(
                          (snap.data ?? false) ? 'متصل الآن' : 'غير متصل',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (!isGroup) ...[
              IconButton(
                icon: const Icon(Icons.call, color: Colors.white),
                tooltip: 'مكالمة صوتية',
                onPressed: () => _startCall(false),
              ),
              IconButton(
                icon: const Icon(Icons.videocam, color: Colors.white),
                tooltip: 'مكالمة فيديو',
                onPressed: () => _startCall(true),
              ),
            ],
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () {},
            ),
          ],
        ),
        body: Column(
          children: [
            // ── Messages ──
            Expanded(
              child: StreamBuilder<List<MessageModel>>(
                stream: FirestoreService.messagesStream(widget.conversation.id),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF00A884)));
                  }
                  final msgs = snap.data ?? [];
                  if (msgs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('لا توجد رسائل بعد',
                              style: TextStyle(color: Colors.grey[500])),
                          const SizedBox(height: 4),
                          Text('ابدأ المحادثة الآن! 👋',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 13)),
                        ],
                      ),
                    );
                  }
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _scrollToBottom());
                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 4),
                    itemCount: msgs.length,
                    itemBuilder: (ctx, i) {
                      final msg = msgs[i];
                      final isMe = msg.senderId == widget.myUid;
                      // Group date separator
                      final showDate = i == 0 ||
                          !_sameDay(msgs[i - 1].createdAt, msg.createdAt);
                      return Column(
                        children: [
                          if (showDate) _dateSeparator(msg.createdAt),
                          MessageBubble(
                            key: ValueKey(msg.id),
                            message: msg,
                            isMe: isMe,
                            onReply: (_) => _setReply(msg.id, msgs),
                            onDelete: _deleteMsg,
                            onReact: _reactMsg,
                            onJoinListen: _joinListenSession,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            // ── Reply preview ──
            if (_replyMsg != null)
              Container(
                color: const Color(0xFFF0FFF8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Container(
                        width: 3,
                        height: 36,
                        color: const Color(0xFF00A884)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('رد على',
                              style: TextStyle(
                                  color: Color(0xFF00A884),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                          Text(
                            _replyMsg!.content ??
                                (_replyMsg!.type == 'voice'
                                    ? '🎤 رسالة صوتية'
                                    : '📎 ملف'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: Colors.grey),
                      onPressed: () =>
                          setState(() { _replyToId = null; _replyMsg = null; }),
                    ),
                  ],
                ),
              ),

            // ── Input bar ──
            Container(
              color: const Color(0xFFF0F2F5),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  // Emoji button
                  IconButton(
                    icon: Icon(
                      _showEmoji ? Icons.keyboard : Icons.emoji_emotions,
                      color: Colors.grey[600],
                    ),
                    onPressed: () {
                      if (_showEmoji) {
                        _focusNode.requestFocus();
                      } else {
                        _focusNode.unfocus();
                      }
                      setState(() => _showEmoji = !_showEmoji);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 36, minHeight: 36),
                  ),
                  // Sticker button
                  IconButton(
                    icon: Icon(Icons.sticky_note_2_outlined,
                        color: Colors.grey[600]),
                    onPressed: _showStickerPicker,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 36, minHeight: 36),
                  ),
                  // Text field
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              focusNode: _focusNode,
                              onChanged: _onTextChanged,
                              maxLines: 5,
                              minLines: 1,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(fontSize: 15),
                              decoration: const InputDecoration(
                                hintText: 'اكتب رسالة...',
                                hintTextDirection: TextDirection.rtl,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                hintStyle: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                          // Attach
                          IconButton(
                            icon: Icon(Icons.attach_file,
                                color: Colors.grey[600]),
                            onPressed: _sending ? null : _showAttachMenu,
                            padding: const EdgeInsets.only(left: 4),
                            constraints: const BoxConstraints(
                                minWidth: 36, minHeight: 36),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Mic / Send / Recording
                  if (_recording)
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _cancelRecording,
                          child: const CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.red,
                            child: Icon(Icons.delete,
                                color: Colors.white, size: 20),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _stopRecordingAndSend,
                          child: const CircleAvatar(
                            radius: 22,
                            backgroundColor: Color(0xFF00A884),
                            child: Icon(Icons.send,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    )
                  else
                    GestureDetector(
                      onTap: _ctrl.text.trim().isNotEmpty && !_sending
                          ? _sendText
                          : null,
                      onLongPress: _ctrl.text.trim().isEmpty && !_sending
                          ? _startRecording
                          : null,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _sending
                              ? Colors.grey[400]
                              : const Color(0xFF00A884),
                          shape: BoxShape.circle,
                        ),
                        child: _sending
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : Icon(
                                _ctrl.text.trim().isNotEmpty
                                    ? Icons.send
                                    : Icons.mic,
                                color: Colors.white,
                                size: 22,
                              ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Emoji Picker ──
            if (_showEmoji)
              SizedBox(
                height: 280,
                child: EmojiPicker(
                  textEditingController: _ctrl,
                  config: Config(
                    emojiViewConfig: const EmojiViewConfig(
                      columns: 8,
                      emojiSizeMax: 28,
                    ),
                    categoryViewConfig: const CategoryViewConfig(
                      indicatorColor: Color(0xFF00A884),
                      iconColorSelected: Color(0xFF00A884),
                    ),
                    bottomActionBarConfig: const BottomActionBarConfig(
                      enabled: false,
                    ),
                  ),
                  onEmojiSelected: (_, emoji) {
                    _ctrl
                      ..text += emoji.emoji
                      ..selection = TextSelection.fromPosition(
                        TextPosition(offset: _ctrl.text.length),
                      );
                    setState(() {});
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _dateSeparator(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    String label;
    if (msgDay == today) {
      label = 'اليوم';
    } else if (today.difference(msgDay).inDays == 1) {
      label = 'أمس';
    } else {
      label = '${dt.day}/${dt.month}/${dt.year}';
    }
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ),
    );
  }
}
