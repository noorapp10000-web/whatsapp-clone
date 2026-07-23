import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../models/poll_model.dart';
import '../services/firestore_service.dart';
import '../services/api_service.dart';
import '../services/call_service.dart';
import '../services/websocket_service.dart';
import '../widgets/message_bubble.dart';
import 'call_screen.dart';
import 'music_player_screen.dart';
import 'contact_info_screen.dart';
import 'group_info_screen.dart';
import 'starred_messages_screen.dart';

class ChatScreen extends StatefulWidget {
  final ConversationModel conversation;
  final String myUid;

  const ChatScreen({super.key, required this.conversation, required this.myUid});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _focusNode = FocusNode();
  bool _sending = false;
  String? _replyToId;
  MessageModel? _replyMsg;

  bool _otherTyping = false;
  Timer? _typingTimer;
  bool _iAmTyping = false;
  Timer? _myTypingTimer;

  bool _showEmoji = false;

  final _recorder = AudioRecorder();
  bool _recording = false;
  Timer? _recordTimer;
  int _recordSeconds = 0;

  bool _selecting = false;
  final Set<String> _selectedIds = {};

  List<MessageModel> _pinnedMessages = [];
  int? _disappearingSeconds;
  String? _wallpaper;

  String get _otherUid => widget.conversation.otherUid(widget.myUid);
  String get _convName => widget.conversation.displayName(widget.myUid);
  bool get _isGroup => widget.conversation.isGroup();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WebSocketService.on('call_answer', _onAnswer);
    WebSocketService.on('call_ice', _onIce);
    WebSocketService.on('typing_start', _onTypingStart);
    WebSocketService.on('typing_stop', _onTypingStop);
    FirestoreService.markMessagesRead(widget.conversation.id, widget.myUid).ignore();
    _disappearingSeconds = widget.conversation.disappearingSeconds;
    _wallpaper = widget.conversation.wallpaper;
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmoji) setState(() => _showEmoji = false);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      WebSocketService.sendTyping(_otherUid, isTyping: false);
    }
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
    _typingTimer = Timer(const Duration(seconds: 4), () { if (mounted) setState(() => _otherTyping = false); });
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
    WidgetsBinding.instance.removeObserver(this);
    WebSocketService.off('call_answer', _onAnswer);
    WebSocketService.off('call_ice', _onIce);
    WebSocketService.off('typing_start', _onTypingStart);
    WebSocketService.off('typing_stop', _onTypingStop);
    _ctrl.dispose();
    _scroll.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    _myTypingTimer?.cancel();
    _recordTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendText() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    _ctrl.clear();
    setState(() => _sending = true);
    _iAmTyping = false;
    WebSocketService.sendTyping(_otherUid, isTyping: false);
    try {
      await FirestoreService.sendMessage(
        widget.conversation.id, widget.myUid,
        type: 'text', text: text,
        replyToId: _replyToId,
        replyToText: _replyMsg?.displayText,
        replyToSender: _replyMsg?.senderId == widget.myUid ? 'أنت' : _replyMsg?.senderName,
        disappearAfterSeconds: _disappearingSeconds,
      );
      setState(() { _replyToId = null; _replyMsg = null; });
      _scrollToBottom();
      _sendPush(text);
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _sendPush(String text) async {
    try {
      if (_isGroup) return;
      await ApiService.sendPushNotification(targetUid: _otherUid, title: '💬 رسالة جديدة', body: text);
    } catch (_) {}
  }

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
        widget.conversation.id, widget.myUid,
        type: 'image', fileUrl: result['url'] as String?,
        replyToId: _replyToId, disappearAfterSeconds: _disappearingSeconds,
      );
      setState(() { _replyToId = null; _replyMsg = null; });
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _pickVideo() async {
    Navigator.pop(context);
    final p = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 5));
    if (p == null) return;
    setState(() => _sending = true);
    try {
      final bytes = await File(p.path).readAsBytes();
      final result = await ApiService.uploadFile(
        base64: 'data:video/mp4;base64,${base64Encode(bytes)}',
        mimeType: 'video/mp4',
        fileName: 'vid_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      await FirestoreService.sendMessage(
        widget.conversation.id, widget.myUid,
        type: 'video', fileUrl: result['url'] as String?, mimeType: 'video/mp4',
        fileSize: result['size'] as int?, replyToId: _replyToId,
      );
      setState(() { _replyToId = null; _replyMsg = null; });
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _pickFile() async {
    Navigator.pop(context);
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    final file = result.files.first;
    setState(() => _sending = true);
    try {
      final bytes = await File(file.path!).readAsBytes();
      final mime = _mimeForFile(file.extension ?? '');
      final uploaded = await ApiService.uploadFile(
        base64: 'data:$mime;base64,${base64Encode(bytes)}',
        mimeType: mime, fileName: file.name,
      );
      await FirestoreService.sendMessage(
        widget.conversation.id, widget.myUid,
        type: 'file', fileUrl: uploaded['url'] as String?,
        fileName: file.name, mimeType: mime, fileSize: file.size,
        replyToId: _replyToId,
      );
      setState(() { _replyToId = null; _replyMsg = null; });
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
    if (mounted) setState(() => _sending = false);
  }

  String _mimeForFile(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf': return 'application/pdf';
      case 'doc': case 'docx': return 'application/msword';
      case 'mp3': return 'audio/mpeg';
      case 'mp4': return 'video/mp4';
      case 'zip': return 'application/zip';
      default: return 'application/octet-stream';
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى منح إذن الميكروفون')));
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);
    setState(() { _recording = true; _recordSeconds = 0; });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
  }

  Future<void> _stopRecording({bool send = true}) async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    setState(() => _recording = false);
    if (!send || path == null) return;
    setState(() => _sending = true);
    try {
      final bytes = await File(path).readAsBytes();
      final result = await ApiService.uploadFile(
        base64: 'data:audio/m4a;base64,${base64Encode(bytes)}',
        mimeType: 'audio/m4a',
        fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      await FirestoreService.sendMessage(
        widget.conversation.id, widget.myUid,
        type: 'audio', fileUrl: result['url'] as String?, mimeType: 'audio/m4a',
        replyToId: _replyToId,
      );
      setState(() { _replyToId = null; _replyMsg = null; });
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
    if (mounted) setState(() => _sending = false);
  }

  void _showCreatePoll() {
    Navigator.pop(context);
    final questionCtrl = TextEditingController();
    final optionCtrls = [TextEditingController(), TextEditingController()];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.poll, color: Color(0xFF00A884)), SizedBox(width: 8), Text('إنشاء استطلاع'),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: questionCtrl, decoration: const InputDecoration(labelText: 'السؤال *'), maxLength: 200),
                const SizedBox(height: 12),
                const Align(alignment: Alignment.centerRight, child: Text('الخيارات:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                const SizedBox(height: 8),
                ...List.generate(optionCtrls.length, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(child: TextField(controller: optionCtrls[i],
                          decoration: InputDecoration(labelText: 'خيار ${i + 1}'))),
                      if (optionCtrls.length > 2)
                        IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            onPressed: () => setSt(() => optionCtrls.removeAt(i))),
                    ],
                  ),
                )),
                if (optionCtrls.length < 6)
                  TextButton.icon(
                    icon: const Icon(Icons.add, color: Color(0xFF00A884)),
                    label: const Text('إضافة خيار', style: TextStyle(color: Color(0xFF00A884))),
                    onPressed: () => setSt(() => optionCtrls.add(TextEditingController())),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (questionCtrl.text.trim().isEmpty) return;
                final opts = optionCtrls.where((c) => c.text.trim().isNotEmpty).toList();
                if (opts.length < 2) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب إضافة خيارين على الأقل')));
                  return;
                }
                Navigator.pop(ctx);
                setState(() => _sending = true);
                try {
                  final poll = PollModel(
                    question: questionCtrl.text.trim(),
                    options: opts.map((c) => PollOption(text: c.text.trim())).toList(),
                  );
                  await FirestoreService.sendMessage(widget.conversation.id, widget.myUid, type: 'poll', poll: poll);
                  _scrollToBottom();
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                }
                if (mounted) setState(() => _sending = false);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884)),
              child: const Text('إنشاء', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDisappearingSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 8, bottom: 16), width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('الرسائل المختفية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            for (final option in [
              {'label': 'إيقاف', 'seconds': null},
              {'label': '24 ساعة', 'seconds': 86400},
              {'label': '7 أيام', 'seconds': 604800},
              {'label': '90 يوم', 'seconds': 7776000},
            ])
              ListTile(
                title: Text(option['label'] as String),
                trailing: _disappearingSeconds == option['seconds'] ? const Icon(Icons.check, color: Color(0xFF00A884)) : null,
                onTap: () async {
                  final secs = option['seconds'] as int?;
                  setState(() => _disappearingSeconds = secs);
                  await FirestoreService.setDisappearingMessages(widget.conversation.id, secs);
                  if (mounted) Navigator.pop(context);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showWallpaperPicker() {
    final wallpapers = [
      {'label': 'بدون', 'value': null as String?, 'color': Colors.grey[200]},
      {'label': 'أخضر', 'value': 'green' as String?, 'color': const Color(0xFFE7F5EC)},
      {'label': 'أزرق', 'value': 'blue' as String?, 'color': const Color(0xFFE3F2FD)},
      {'label': 'بنفسجي', 'value': 'purple' as String?, 'color': const Color(0xFFF3E5F5)},
      {'label': 'وردي', 'value': 'pink' as String?, 'color': const Color(0xFFFCE4EC)},
    ];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 8, bottom: 16), width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('خلفية المحادثة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: wallpapers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final w = wallpapers[i];
                  final selected = _wallpaper == w['value'];
                  return GestureDetector(
                    onTap: () async {
                      final val = w['value'] as String?;
                      setState(() => _wallpaper = val);
                      await FirestoreService.setChatWallpaper(widget.conversation.id, val);
                      if (mounted) Navigator.pop(context);
                    },
                    child: Column(children: [
                      Container(width: 60, height: 60,
                        decoration: BoxDecoration(
                          color: w['color'] as Color?,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selected ? const Color(0xFF00A884) : Colors.grey.withOpacity(0.3), width: selected ? 2 : 1),
                        ),
                        child: selected ? const Icon(Icons.check, color: Color(0xFF00A884)) : null,
                      ),
                      const SizedBox(height: 6),
                      Text(w['label'] as String, style: const TextStyle(fontSize: 12)),
                    ]),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Color? get _wallpaperColor {
    switch (_wallpaper) {
      case 'green': return const Color(0xFFE7F5EC);
      case 'blue': return const Color(0xFFE3F2FD);
      case 'purple': return const Color(0xFFF3E5F5);
      case 'pink': return const Color(0xFFFCE4EC);
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = _wallpaperColor ?? (isDark ? const Color(0xFF0B141A) : const Color(0xFFEBE5DE));

    return Scaffold(
      appBar: _selecting ? _buildSelectionAppBar() : _buildNormalAppBar(isDark),
      backgroundColor: bgColor,
      body: Column(
        children: [
          if (_pinnedMessages.isNotEmpty) _buildPinnedBanner(isDark),
          if (_disappearingSeconds != null) _buildDisappearingBanner(),
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: FirestoreService.messagesStream(widget.conversation.id),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF00A884)));
                }
                final messages = snap.data ?? [];
                final pinned = messages.where((m) => m.isPinned && !m.deleted).toList();
                if (pinned.length != _pinnedMessages.length) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _pinnedMessages = pinned);
                  });
                }
                if (messages.isEmpty) {
                  return Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text('ابدأ المحادثة!', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                    ]),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) {
                    final msg = messages[i];
                    final prev = i > 0 ? messages[i - 1] : null;
                    final showDate = prev == null || !_sameDay(prev.createdAt, msg.createdAt);
                    return Column(children: [
                      if (showDate) _dateSeparator(msg.createdAt),
                      _buildBubble(msg),
                    ]);
                  },
                );
              },
            ),
          ),
          if (_otherTyping) _buildTypingIndicator(isDark),
          if (_replyMsg != null) _buildReplyBanner(isDark),
          _buildInput(isDark),
          if (_showEmoji)
            SizedBox(
              height: 280,
              child: EmojiPicker(
                onEmojiSelected: (_, emoji) {
                  _ctrl
                    ..text += emoji.emoji
                    ..selection = TextSelection.fromPosition(TextPosition(offset: _ctrl.text.length));
                  setState(() {});
                },
                config: const Config(
                  emojiViewConfig: EmojiViewConfig(emojiSizeMax: 28),
                  bottomActionBarConfig: BottomActionBarConfig(enabled: false),
                ),
              ),
            ),
        ],
      ),
    );
  }

  AppBar _buildNormalAppBar(bool isDark) {
    final photo = widget.conversation.displayPhoto(widget.myUid);
    final name = _convName;
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF1F2C34) : const Color(0xFF00A884),
      leadingWidth: 30,
      title: GestureDetector(
        onTap: () {
          if (_isGroup) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => GroupInfoScreen(conversation: widget.conversation, myUid: widget.myUid),
            ));
          } else {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => ContactInfoScreen(uid: _otherUid, myUid: widget.myUid, conversation: widget.conversation),
            ));
          }
        },
        child: Row(children: [
          Hero(
            tag: 'avatar_${widget.conversation.id}',
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white.withOpacity(0.3),
              backgroundImage: photo != null ? NetworkImage(photo) : null,
              child: photo == null
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (_otherTyping)
                const Text('يكتب...', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
        ]),
      ),
      actions: [
        if (!_isGroup)
          IconButton(icon: const Icon(Icons.call, color: Colors.white), onPressed: () => _startCall(false)),
        IconButton(icon: const Icon(Icons.videocam, color: Colors.white), onPressed: () => _startCall(true)),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: _onMenuAction,
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'disappearing', child: Text('الرسائل المختفية')),
            const PopupMenuItem(value: 'wallpaper', child: Text('خلفية المحادثة')),
            const PopupMenuItem(value: 'mute', child: Text('كتم الإشعارات')),
            const PopupMenuItem(value: 'starred', child: Text('الرسائل المميزة')),
          ],
        ),
      ],
    );
  }

  AppBar _buildSelectionAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF00A884),
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () => setState(() { _selecting = false; _selectedIds.clear(); }),
      ),
      title: Text('${_selectedIds.length} محدد', style: const TextStyle(color: Colors.white)),
      actions: [
        IconButton(
          icon: const Icon(Icons.star_border, color: Colors.white),
          onPressed: () async {
            for (final id in _selectedIds) {
              await FirestoreService.starMessage(widget.conversation.id, id, true);
            }
            setState(() { _selecting = false; _selectedIds.clear(); });
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.white),
          onPressed: () async {
            for (final id in _selectedIds) {
              await FirestoreService.deleteMessage(widget.conversation.id, id, forEveryone: false);
            }
            setState(() { _selecting = false; _selectedIds.clear(); });
          },
        ),
      ],
    );
  }

  Widget _buildPinnedBanner(bool isDark) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        color: isDark ? const Color(0xFF1F2C34) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          const Icon(Icons.push_pin, color: Color(0xFF00A884), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text('📌 ${_pinnedMessages.last.displayText}', maxLines: 1,
                overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          ),
        ]),
      ),
    );
  }

  Widget _buildDisappearingBanner() {
    String label = '';
    if (_disappearingSeconds == 86400) label = '24 ساعة';
    else if (_disappearingSeconds == 604800) label = '7 أيام';
    else if (_disappearingSeconds == 7776000) label = '90 يوم';
    return Container(
      color: Colors.amber.withOpacity(0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        const Icon(Icons.timer, color: Colors.amber, size: 16),
        const SizedBox(width: 8),
        Text('الرسائل المختفية: $label', style: const TextStyle(color: Colors.amber, fontSize: 12)),
      ]),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2C34) : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _TypingDot(delay: 0),
            const SizedBox(width: 3),
            _TypingDot(delay: 150),
            const SizedBox(width: 3),
            _TypingDot(delay: 300),
          ]),
        ),
      ]),
    );
  }

  Widget _buildReplyBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2C34) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: Color(0xFF00A884), width: 3)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_replyMsg?.senderId == widget.myUid ? 'أنت' : (_replyMsg?.senderName ?? 'رد على'),
                style: const TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold, fontSize: 12)),
            Text(_replyMsg?.displayText ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ]),
        ),
        IconButton(icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() { _replyToId = null; _replyMsg = null; })),
      ]),
    );
  }

  Widget _buildInput(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: isDark ? const Color(0xFF1F2C34) : const Color(0xFFF0F2F5),
      child: Row(children: [
        IconButton(
          icon: Icon(_showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined, color: Colors.grey[600]),
          onPressed: () {
            setState(() => _showEmoji = !_showEmoji);
            if (_showEmoji) _focusNode.unfocus(); else _focusNode.requestFocus();
          },
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A3942) : Colors.white,
              borderRadius: BorderRadius.circular(25),
            ),
            child: TextField(
              controller: _ctrl,
              focusNode: _focusNode,
              maxLines: 5, minLines: 1,
              onChanged: _onTextChanged,
              decoration: InputDecoration(
                hintText: 'اكتب رسالة...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.grey),
                  onPressed: _showAttachMenu,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _recording
            ? Row(children: [
                Text('${_recordSeconds ~/ 60}:${(_recordSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.stop, color: Colors.red, size: 28),
                    onPressed: () => _stopRecording(send: false)),
                GestureDetector(
                  onTap: () => _stopRecording(send: true),
                  child: Container(width: 48, height: 48,
                      decoration: const BoxDecoration(color: Color(0xFF00A884), shape: BoxShape.circle),
                      child: const Icon(Icons.send, color: Colors.white, size: 22)),
                ),
              ])
            : _ctrl.text.trim().isNotEmpty
                ? GestureDetector(
                    onTap: _sendText,
                    child: Container(width: 48, height: 48,
                        decoration: const BoxDecoration(color: Color(0xFF00A884), shape: BoxShape.circle),
                        child: _sending
                            ? const Padding(padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send, color: Colors.white, size: 22)),
                  )
                : GestureDetector(
                    onLongPressStart: (_) => _startRecording(),
                    onLongPressEnd: (_) => _stopRecording(send: true),
                    child: Container(width: 48, height: 48,
                        decoration: const BoxDecoration(color: Color(0xFF00A884), shape: BoxShape.circle),
                        child: const Icon(Icons.mic, color: Colors.white, size: 24)),
                  ),
      ]),
    );
  }

  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(margin: const EdgeInsets.only(bottom: 20), width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _attachItem(Icons.photo_library, 'الصور', Colors.purple, () => _pickImage(ImageSource.gallery)),
                _attachItem(Icons.camera_alt, 'الكاميرا', Colors.red, () => _pickImage(ImageSource.camera)),
                _attachItem(Icons.videocam, 'فيديو', Colors.blue, _pickVideo),
                _attachItem(Icons.insert_drive_file, 'ملف', Colors.orange, _pickFile),
              ]),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _attachItem(Icons.location_on, 'الموقع', Colors.green, _shareLocation),
                _attachItem(Icons.poll, 'استطلاع', Colors.teal, _showCreatePoll),
                _attachItem(Icons.headphones, 'معاً', const Color(0xFF00A884), _startListenTogether),
                _attachItem(Icons.contact_phone, 'جهة اتصال', Colors.amber, () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مشاركة جهة اتصال')));
                }),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(width: 56, height: 56,
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 26)),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildBubble(MessageModel msg) {
    final isMe = msg.senderId == widget.myUid;
    return MessageBubble(
      message: msg,
      isMe: isMe,
      myUid: widget.myUid,
      convId: widget.conversation.id,
      onReply: (id) {
        setState(() { _replyToId = id; _replyMsg = msg; });
        _focusNode.requestFocus();
      },
      onDelete: (id) async {
        final choice = await showDialog<String>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('حذف الرسالة'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('إلغاء')),
              if (isMe) TextButton(onPressed: () => Navigator.pop(context, 'everyone'),
                  child: const Text('حذف للجميع', style: TextStyle(color: Colors.red))),
              TextButton(onPressed: () => Navigator.pop(context, 'me'), child: const Text('حذف لي فقط')),
            ],
          ),
        );
        if (choice == 'everyone') {
          await FirestoreService.deleteMessage(widget.conversation.id, id, forEveryone: true);
        } else if (choice == 'me') {
          await FirestoreService.deleteMessage(widget.conversation.id, id);
        }
      },
      onReact: (id, emoji) async {
        await FirestoreService.reactToMessage(widget.conversation.id, id, widget.myUid, emoji);
        WebSocketService.sendReaction(_otherUid, widget.conversation.id, id, emoji);
      },
      onStar: (id, starred) => FirestoreService.starMessage(widget.conversation.id, id, starred),
      onPin: (id, pinned) => FirestoreService.pinMessage(widget.conversation.id, id, pinned),
      onEdit: isMe ? (id, currentText) async {
        final ctrl = TextEditingController(text: currentText);
        final newText = await showDialog<String>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('تعديل الرسالة'),
            content: TextField(controller: ctrl, maxLines: 5, autofocus: true,
                decoration: const InputDecoration(hintText: 'الرسالة الجديدة...')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884)),
                child: const Text('حفظ', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (newText != null && newText.isNotEmpty) {
          await FirestoreService.editMessage(widget.conversation.id, id, newText);
        }
      } : null,
      onSelect: (id) => setState(() { _selecting = true; _selectedIds.add(id); }),
      onVotePoll: (msgId, optIdx) => FirestoreService.votePoll(widget.conversation.id, msgId, optIdx, widget.myUid),
      onJoinListen: (sessionId) => Navigator.push(context, MaterialPageRoute(
        builder: (_) => MusicPlayerScreen(sessionId: sessionId, otherUid: _otherUid, isHost: false),
      )),
    );
  }

  void _startCall(bool isVideo) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CallScreen(
        otherUid: _otherUid, otherName: _convName,
        otherPhoto: widget.conversation.displayPhoto(widget.myUid),
        isVideo: isVideo, isIncoming: false, convId: widget.conversation.id,
      ),
    ));
  }

  void _startListenTogether() {
    Navigator.pop(context);
    final sessionId = const Uuid().v4();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => MusicPlayerScreen(sessionId: sessionId, otherUid: _otherUid, isHost: true),
    ));
    WebSocketService.sendLTInvite(_otherUid, sessionId);
  }

  void _shareLocation() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [Icon(Icons.location_on, color: Color(0xFF00A884)), SizedBox(width: 8), Text('مشاركة الموقع')]),
        content: const Text('سيتم مشاركة موقعك الحالي'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _sending = true);
              try {
                await FirestoreService.sendMessage(widget.conversation.id, widget.myUid,
                    type: 'location', location: {'lat': 30.0444, 'lng': 31.2357, 'address': 'القاهرة، مصر'});
                _scrollToBottom();
              } catch (_) {}
              if (mounted) setState(() => _sending = false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884)),
            child: const Text('مشاركة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _onMenuAction(String action) {
    switch (action) {
      case 'disappearing': _showDisappearingSettings(); break;
      case 'wallpaper': _showWallpaperPicker(); break;
      case 'mute': FirestoreService.muteConversation(widget.conversation.id, !widget.conversation.isMutedNow()); break;
      case 'starred':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const StarredMessagesScreen()));
        break;
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _dateSeparator(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    String label;
    if (msgDay == today) label = 'اليوم';
    else if (today.difference(msgDay).inDays == 1) label = 'أمس';
    else label = '${dt.day}/${dt.month}/${dt.year}';
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});
  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Transform.translate(
      offset: Offset(0, -4 * _anim.value),
      child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
    ),
  );
}
