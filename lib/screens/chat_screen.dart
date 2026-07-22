import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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

  // Voice recording
  final _recorder = AudioRecorder();
  bool _recording = false;
  Timer? _recTimer;
  int _recSeconds = 0;
  String? _recPath;

  // Typing indicator
  bool _otherTyping = false;
  Timer? _typingTimer;
  bool _iAmTyping = false;
  Timer? _myTypingTimer;

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
  }

  // ─── WebSocket handlers ────────────────────────────────────────────────────
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
    _typingTimer =
        Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _otherTyping = false);
    });
  }

  void _onTypingStop(Map<String, dynamic> msg) {
    if ((msg['fromUid'] ?? '') != _otherUid) return;
    _typingTimer?.cancel();
    if (mounted) setState(() => _otherTyping = false);
  }

  // ─── Typing detection ──────────────────────────────────────────────────────
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
    setState(() {}); // refresh send/mic button
  }

  @override
  void dispose() {
    WebSocketService.off('call_answer', _onAnswer);
    WebSocketService.off('call_ice', _onIce);
    WebSocketService.off('typing_start', _onTypingStart);
    WebSocketService.off('typing_stop', _onTypingStop);
    _ctrl.dispose();
    _scroll.dispose();
    _recorder.dispose();
    _recTimer?.cancel();
    _typingTimer?.cancel();
    _myTypingTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── Send text ─────────────────────────────────────────────────────────────
  Future<void> _sendText() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _ctrl.clear();
    _iAmTyping = false;
    WebSocketService.sendTyping(_otherUid, isTyping: false);
    try {
      await FirestoreService.sendMessage(
        widget.conversation.id,
        widget.myUid,
        type: 'text',
        content: text,
        replyToId: _replyToId,
      );
      if (_replyToId != null) setState(() { _replyToId = null; _replyMsg = null; });
      _scrollToBottom();
      if (_otherUid.isNotEmpty) {
        ApiService.sendNotification(
          targetUid: _otherUid,
          title: (_otherP['displayName'] ?? _convName) as String,
          body: text,
          data: {'conversationId': widget.conversation.id, 'type': 'message'},
        ).ignore();
      }
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  // ─── Upload file helper ────────────────────────────────────────────────────
  Future<void> _uploadAndSend(
      String path, String mime, String name, String type,
      {int? durationMs}) async {
    if (mounted) setState(() => _sending = true);
    try {
      final bytes = await File(path).readAsBytes();
      final result = await ApiService.uploadFile(
        base64: 'data:$mime;base64,${base64Encode(bytes)}',
        mimeType: mime,
        fileName: name,
      );
      await FirestoreService.sendMessage(
        widget.conversation.id,
        widget.myUid,
        type: type,
        fileUrl: result['url'] as String,
        fileName: name,
        fileSize: result['size'] as int?,
        mimeType: mime,
        durationMs: durationMs,
      );
      _scrollToBottom();
      if (_otherUid.isNotEmpty) {
        final body = type == 'voice'
            ? '🎤 Voice message'
            : type == 'image'
                ? '📷 Image'
                : type == 'video'
                    ? '🎥 Video'
                    : '📎 $name';
        ApiService.sendNotification(
          targetUid: _otherUid,
          title: (_otherP['displayName'] ?? _convName) as String,
          body: body,
          data: {'conversationId': widget.conversation.id, 'type': type},
        ).ignore();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  // ─── Media pickers ─────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final p = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (p == null) return;
    await _uploadAndSend(p.path, 'image/jpeg', p.name, 'image');
  }

  Future<void> _capturePhoto() async {
    final p = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 75);
    if (p == null) return;
    await _uploadAndSend(p.path, 'image/jpeg', p.name, 'image');
  }

  Future<void> _pickVideo() async {
    final p = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (p == null) return;
    await _uploadAndSend(p.path, 'video/mp4', p.name, 'video');
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.platform.pickFiles();
    if (r == null || r.files.isEmpty || r.files.first.path == null) return;
    final f = r.files.first;
    await _uploadAndSend(
        f.path!, 'application/${f.extension ?? 'octet-stream'}', f.name, 'file');
  }

  // ─── Voice recording ───────────────────────────────────────────────────────
  Future<void> _startRecording() async {
    final perm = await Permission.microphone.request();
    if (!perm.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission required')));
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    _recPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
        path: _recPath!,
      );
      setState(() {
        _recording = true;
        _recSeconds = 0;
      });
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recSeconds++);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot record: $e')));
      }
    }
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    _recTimer?.cancel();
    final path = await _recorder.stop();
    setState(() => _recording = false);
    if (cancel || path == null || _recSeconds < 1) return;
    await _uploadAndSend(
      path,
      'audio/aac',
      'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
      'voice',
      durationMs: _recSeconds * 1000,
    );
  }

  // ─── Listen Together ───────────────────────────────────────────────────────
  Future<void> _showListenTogetherDialog() async {
    final playlist = <Map<String, dynamic>>[];
    String? title;
    String? url;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDlg) {
          final urlCtrl = TextEditingController();
          final titleCtrl = TextEditingController();
          return AlertDialog(
            title: const Row(children: [
              Icon(Icons.headphones, color: Color(0xFF00A884)),
              SizedBox(width: 8),
              Text('Listen Together'),
            ]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add songs to your playlist. Use direct audio URLs (MP3, M4A, OGG…)',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Song title',
                      prefixIcon: Icon(Icons.music_note),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Audio URL',
                      prefixIcon: Icon(Icons.link),
                      hintText: 'https://example.com/song.mp3',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add to playlist'),
                      onPressed: () {
                        final t = titleCtrl.text.trim();
                        final u = urlCtrl.text.trim();
                        if (t.isEmpty || u.isEmpty) return;
                        setDlg(() {
                          playlist.add({'title': t, 'url': u});
                          title = t;
                          url = u;
                          titleCtrl.clear();
                          urlCtrl.clear();
                        });
                      },
                    ),
                  ),
                  if (playlist.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Playlist:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ...playlist.asMap().entries.map((e) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.music_note,
                              size: 16, color: Color(0xFF00A884)),
                          title: Text(e.value['title'] as String,
                              style: const TextStyle(fontSize: 13)),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle,
                                color: Colors.red, size: 18),
                            onPressed: () =>
                                setDlg(() => playlist.removeAt(e.key)),
                          ),
                        )),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Invite'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A884),
                    foregroundColor: Colors.white),
                onPressed: playlist.isEmpty
                    ? null
                    : () => Navigator.pop(ctx, true),
              ),
            ],
          );
        });
      },
    );

    if (playlist.isEmpty) return;
    try {
      final sessionId = await FirestoreService.createListenSession(
        creatorUid: widget.myUid,
        participantUids: [_otherUid],
        playlist: playlist,
      );
      final firstTitle = playlist.first['title'] as String;
      final firstUrl = playlist.first['url'] as String;
      await FirestoreService.sendMessage(
        widget.conversation.id,
        widget.myUid,
        type: 'listen_together',
        ltSessionId: sessionId,
        ltUrl: firstUrl,
        ltTitle: firstTitle,
        ltPlaylist: playlist,
      );
      WebSocketService.sendLTInvite(_otherUid, sessionId);
      _scrollToBottom();

      // Open player for sender
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MusicPlayerScreen(
              sessionId: sessionId,
              myUid: widget.myUid,
              otherUid: _otherUid,
              otherName: _convName,
              isCreator: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _joinListenTogether(String sessionId) {
    WebSocketService.sendLTAccept(_otherUid, sessionId);
    FirestoreService.updateListenSession(
        sessionId, {'status': 'active', 'isPlaying': true}, widget.myUid);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MusicPlayerScreen(
          sessionId: sessionId,
          myUid: widget.myUid,
          otherUid: _otherUid,
          otherName: _convName,
          isCreator: false,
        ),
      ),
    );
  }

  // ─── Attachment menu ───────────────────────────────────────────────────────
  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _menuItem(Icons.photo, 'Gallery', Colors.purple, _pickImage),
                  _menuItem(
                      Icons.camera_alt, 'Camera', Colors.red, _capturePhoto),
                  _menuItem(Icons.videocam, 'Video', Colors.orange, _pickVideo),
                  _menuItem(Icons.attach_file, 'File', Colors.teal, _pickFile),
                  _menuItem(Icons.headphones, 'Listen\nTogether',
                      const Color(0xFF00A884), () {
                    Navigator.pop(context);
                    _showListenTogetherDialog();
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle),
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

  // ─── Start call ────────────────────────────────────────────────────────────
  Future<void> _startCall(bool isVideo) async {
    final callId = await FirestoreService.logCall(
        widget.myUid, _otherUid, isVideo ? 'video' : 'voice');
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          otherUid: _otherUid,
          otherName: (_otherP['displayName'] ?? _convName) as String,
          otherPhoto: _otherP['photoUrl'] as String?,
          isVideo: isVideo,
          isIncoming: false,
          convId: widget.conversation.id,
          callId: callId,
        ),
      ),
    );
    ApiService.sendNotification(
      targetUid: _otherUid,
      title: isVideo ? '📹 Incoming Video Call' : '📞 Incoming Voice Call',
      body: 'Tap to answer',
      data: {
        'type': isVideo ? 'video_call' : 'voice_call',
        'callerUid': widget.myUid,
      },
    ).ignore();
  }

  // ─── Reply / Delete / React ────────────────────────────────────────────────
  void _setReply(String msgId, List<MessageModel> msgs) {
    final msg = msgs.firstWhere((m) => m.id == msgId,
        orElse: () => msgs.first);
    setState(() {
      _replyToId = msgId;
      _replyMsg = msg;
    });
  }

  Future<void> _deleteMsg(String msgId) async {
    await FirestoreService.deleteMessage(widget.conversation.id, msgId);
  }

  Future<void> _reactMsg(String msgId, String emoji) async {
    await FirestoreService.addReaction(
        widget.conversation.id, msgId, widget.myUid, emoji);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final other = _otherP;
    final otherName =
        (other['displayName'] ?? _convName) as String;
    final otherPhoto = other['photoUrl'] as String?;
    final isOnline = (other['isOnline'] ?? false) as bool;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00A884),
        leadingWidth: 32,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              backgroundImage: otherPhoto != null
                  ? NetworkImage(otherPhoto)
                  : null,
              child: otherPhoto == null
                  ? Text(
                      otherName.isNotEmpty
                          ? otherName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Color(0xFF00A884), fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(otherName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  if (_otherTyping)
                    const Text('typing...',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 11))
                  else if (isOnline)
                    const Text('online',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: () => _startCall(false),
            tooltip: 'Voice call',
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            onPressed: () => _startCall(true),
            tooltip: 'Video call',
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: FirestoreService.messagesStream(widget.conversation.id),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF00A884)));
                }
                final msgs = snap.data!;
                if (msgs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text('Say hi to $otherName! 👋',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 16)),
                        const SizedBox(height: 8),
                        const Text(
                          'Your messages are end-to-end encrypted',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scroll,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final msg = msgs[i];
                    final isMe = msg.senderId == widget.myUid;
                    return MessageBubble(
                      key: ValueKey(msg.id),
                      message: msg,
                      isMe: isMe,
                      onReply: (id) => _setReply(id, msgs),
                      onDelete: _deleteMsg,
                      onReact: _reactMsg,
                      onJoinListen: _joinListenTogether,
                    );
                  },
                );
              },
            ),
          ),

          // Reply preview
          if (_replyMsg != null)
            Container(
              color: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                      width: 3,
                      height: 40,
                      color: const Color(0xFF00A884)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _replyMsg!.senderId == widget.myUid
                              ? 'You'
                              : otherName,
                          style: const TextStyle(
                              color: Color(0xFF00A884),
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                        Text(
                          _replyMsg!.content ??
                              _replyMsg!.fileName ??
                              _replyMsg!.type,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () =>
                        setState(() {
                          _replyToId = null;
                          _replyMsg = null;
                        }),
                  ),
                ],
              ),
            ),

          // Recording indicator
          if (_recording)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.fiber_manual_record,
                      color: Colors.red, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    'Recording ${_recSeconds ~/ 60}:${(_recSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _stopRecording(cancel: true),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ],
              ),
            ),

          // Input bar
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file,
                      color: Color(0xFF00A884)),
                  onPressed: _sending ? null : _showAttachMenu,
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2F5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _ctrl,
                      onChanged: _onTextChanged,
                      maxLines: 5,
                      minLines: 1,
                      style: const TextStyle(fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Send / Mic button
                GestureDetector(
                  onTap: _ctrl.text.trim().isNotEmpty
                      ? (_sending ? null : _sendText)
                      : null,
                  onLongPressStart: _ctrl.text.trim().isEmpty && !_sending
                      ? (_) => _startRecording()
                      : null,
                  onLongPressEnd: _ctrl.text.trim().isEmpty && !_sending
                      ? (_) => _stopRecording()
                      : null,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _sending
                          ? Colors.grey
                          : const Color(0xFF00A884),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _ctrl.text.trim().isNotEmpty
                          ? Icons.send
                          : _recording
                              ? Icons.stop
                              : Icons.mic,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
