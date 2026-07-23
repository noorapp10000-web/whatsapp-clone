import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/message_model.dart';
import 'audio_player_widget.dart';
import 'poll_widget.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final String myUid;
  final String convId;
  final void Function(String id) onReply;
  final void Function(String id) onDelete;
  final void Function(String id, String emoji) onReact;
  final void Function(String id, bool starred) onStar;
  final void Function(String id, bool pinned) onPin;
  final void Function(String id, String currentText)? onEdit;
  final void Function(String id) onSelect;
  final void Function(String msgId, int optionIndex) onVotePoll;
  final void Function(String sessionId)? onJoinListen;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.myUid,
    required this.convId,
    required this.onReply,
    required this.onDelete,
    required this.onReact,
    required this.onStar,
    required this.onPin,
    this.onEdit,
    required this.onSelect,
    required this.onVotePoll,
    this.onJoinListen,
  });

  @override
  Widget build(BuildContext context) {
    if (message.deleted) return _buildDeletedMessage(context);
    if (message.type == 'system') {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(message.text ?? '', style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
      );
    }

    return GestureDetector(
      onLongPress: () => _showOptions(context),
      onDoubleTap: () => _showEmojiPicker(context),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.isPinned)
              Padding(
                padding: EdgeInsets.only(right: isMe ? 12 : 0, left: isMe ? 0 : 12, bottom: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.push_pin, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('مثبتة', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  ],
                ),
              ),
            if (message.forwardedFrom != null)
              Padding(
                padding: EdgeInsets.only(right: isMe ? 12 : 0, left: isMe ? 0 : 12, bottom: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.forward, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text('تم التحويل', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  ],
                ),
              ),
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
              margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
              padding: _bubblePadding(),
              decoration: BoxDecoration(
                color: _bubbleColor(context),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && message.senderName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(message.senderName!,
                          style: TextStyle(color: _senderColor(message.senderName ?? ''), fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  if (message.replyToId != null) _buildReplyBanner(context),
                  _buildContent(context),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.isEdited)
                        Text('معدّل ', style: TextStyle(color: Colors.grey[500], fontSize: 10, fontStyle: FontStyle.italic)),
                      Text(_formatTime(message.createdAt), style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                      if (message.isStarred) ...[const SizedBox(width: 4), const Icon(Icons.star, size: 10, color: Colors.amber)],
                      if (isMe) ...[const SizedBox(width: 4), _buildStatusTick()],
                    ],
                  ),
                ],
              ),
            ),
            if (message.reactions != null && message.reactions!.isNotEmpty)
              _buildReactions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDeletedMessage(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: const BorderRadius.all(Radius.circular(16))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Text('تم حذف هذه الرسالة', style: TextStyle(color: Colors.grey[500], fontSize: 13, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Color _bubbleColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isMe) return isDark ? const Color(0xFF025C4B) : const Color(0xFFDCF8C6);
    return isDark ? const Color(0xFF1F2C34) : Colors.white;
  }

  Color _senderColor(String name) {
    final colors = [const Color(0xFFE91E63), const Color(0xFF9C27B0), const Color(0xFF2196F3),
      const Color(0xFF00BCD4), const Color(0xFF4CAF50), const Color(0xFFFF5722), const Color(0xFF607D8B)];
    return colors[name.hashCode.abs() % colors.length];
  }

  EdgeInsets _bubblePadding() {
    if (message.type == 'image' || message.type == 'video') return EdgeInsets.zero;
    return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  }

  Widget _buildReplyBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.black12,
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: Color(0xFF00A884), width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.replyToSender != null)
            Text(message.replyToSender!, style: const TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold, fontSize: 11)),
          Text(message.replyToText ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (message.type) {
      case 'text': return _buildTextContent(context);
      case 'image': return _buildImageContent(context);
      case 'video': return _buildVideoContent(context);
      case 'audio': return _buildAudioContent();
      case 'file': return _buildFileContent();
      case 'listen_together': return _buildListenTogetherContent(context);
      case 'poll': return _buildPollContent(context);
      case 'location': return _buildLocationContent(context);
      case 'contact': return _buildContactContent(context);
      default: return const Text('رسالة غير معروفة');
    }
  }

  Widget _buildTextContent(BuildContext context) {
    final text = message.isEdited && message.editedText != null ? message.editedText! : (message.text ?? '');
    final urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);
    final match = urlRegex.firstMatch(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRichText(text, context),
        if (match != null) _LinkPreviewWidget(url: match.group(0)!),
      ],
    );
  }

  Widget _buildRichText(String text, BuildContext context) {
    final urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);
    final spans = <InlineSpan>[];
    int last = 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultStyle = TextStyle(
        color: isDark ? Colors.white : Colors.black87, fontSize: 15, height: 1.4);

    for (final m in urlRegex.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final url = m.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: const TextStyle(color: Color(0xFF0969DA), decoration: TextDecoration.underline),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
          },
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return RichText(text: TextSpan(style: defaultStyle, children: spans.isEmpty ? [TextSpan(text: text)] : spans));
  }

  Widget _buildImageContent(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullImage(context),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 4), bottomRight: Radius.circular(isMe ? 4 : 16),
        ),
        child: Stack(
          children: [
            CachedNetworkImage(
              imageUrl: message.fileUrl ?? '',
              width: 240, height: 300, fit: BoxFit.cover,
              placeholder: (_, __) => Container(width: 240, height: 300, color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator(color: Color(0xFF00A884)))),
              errorWidget: (_, __, ___) => Container(width: 240, height: 200, color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, size: 50, color: Colors.grey)),
            ),
            if (message.text != null && message.text!.isNotEmpty)
              Positioned(bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.7)])),
                  child: Text(message.text!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openFullImage(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: Center(child: InteractiveViewer(child: CachedNetworkImage(imageUrl: message.fileUrl ?? ''))),
      ),
    ));
  }

  Widget _buildVideoContent(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
        bottomLeft: Radius.circular(isMe ? 16 : 4), bottomRight: Radius.circular(isMe ? 4 : 16),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: 240, height: 200, color: Colors.grey[800],
              child: message.thumbnailUrl != null
                  ? CachedNetworkImage(imageUrl: message.thumbnailUrl!, fit: BoxFit.cover)
                  : const Icon(Icons.videocam, size: 60, color: Colors.white54)),
          Container(width: 56, height: 56,
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 32)),
          if (message.fileSize != null)
            Positioned(bottom: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8)),
                child: Text(_formatSize(message.fileSize!), style: const TextStyle(color: Colors.white, fontSize: 10)),
              )),
        ],
      ),
    );
  }

  Widget _buildAudioContent() {
    return AudioPlayerWidget(
      url: message.fileUrl ?? '',
      isMe: isMe,
    );
  }

  Widget _buildFileContent() {
    final ext = (message.fileName ?? '').split('.').last.toUpperCase();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(color: const Color(0xFF00A884).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(ext.isNotEmpty ? ext : 'FILE',
              style: const TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold, fontSize: 10)))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.fileName ?? 'ملف', maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              if (message.fileSize != null)
                Text(_formatSize(message.fileSize!), style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async {
            if (message.fileUrl != null) {
              final uri = Uri.parse(message.fileUrl!);
              if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: const Color(0xFF00A884).withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.download, color: Color(0xFF00A884), size: 20)),
        ),
      ],
    );
  }

  Widget _buildListenTogetherContent(BuildContext context) {
    return GestureDetector(
      onTap: () { if (message.sessionId != null) onJoinListen?.call(message.sessionId!); },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF00A884), Color(0xFF007B63)]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.headphones, color: Colors.white, size: 32),
            SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('استماع معاً', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              Text('انقر للانضمام', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildPollContent(BuildContext context) {
    if (message.poll == null) return const SizedBox.shrink();
    return PollWidget(
      poll: message.poll!,
      myUid: myUid,
      onVote: (optionIndex) => onVotePoll(message.id, optionIndex),
    );
  }

  Widget _buildLocationContent(BuildContext context) {
    final loc = message.location ?? {};
    final address = loc['address'] as String? ?? 'موقع';
    return GestureDetector(
      onTap: () async {
        final lat = loc['lat'];
        final lng = loc['lng'];
        final url = Uri.parse('https://www.google.com/maps?q=$lat,$lng');
        if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Container(width: 220, height: 150, color: const Color(0xFFE8F5E9),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.location_on, color: Color(0xFF00A884), size: 48),
                  Text(address, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                ])),
            Positioned(bottom: 0, left: 0, right: 0,
              child: Container(padding: const EdgeInsets.all(8), color: Colors.white,
                child: Row(children: [
                  const Icon(Icons.open_in_new, color: Color(0xFF00A884), size: 14),
                  const SizedBox(width: 4),
                  const Text('فتح في الخرائط', style: TextStyle(color: Color(0xFF00A884), fontSize: 11)),
                ]))),
          ],
        ),
      ),
    );
  }

  Widget _buildContactContent(BuildContext context) {
    final contact = message.contact ?? {};
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.3)), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF00A884).withOpacity(0.2),
            child: Text((contact['name'] as String? ?? '?').isNotEmpty ? (contact['name'] as String)[0].toUpperCase() : '?',
                style: const TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(contact['name'] as String? ?? 'جهة اتصال',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            if (contact['phone'] != null)
              Text(contact['phone'] as String, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ]),
        ],
      ),
    );
  }

  Widget _buildReactions(BuildContext context) {
    final reactions = message.reactions!;
    final grouped = <String, int>{};
    for (final emoji in reactions.values) {
      grouped[emoji] = (grouped[emoji] ?? 0) + 1;
    }
    return Padding(
      padding: EdgeInsets.only(right: isMe ? 12 : 0, left: isMe ? 0 : 12, bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: grouped.entries.map((e) => Text(
            '${e.key}${e.value > 1 ? ' ${e.value}' : ''}',
            style: const TextStyle(fontSize: 13),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusTick() {
    final readBy = message.readBy ?? {};
    final delivered = readBy.isNotEmpty;
    final read = readBy.length > 1;
    return Icon(
      delivered ? Icons.done_all : Icons.done,
      size: 14,
      color: read ? const Color(0xFF53BDEB) : Colors.grey[500],
    );
  }

  void _showEmojiPicker(BuildContext context) {
    final emojis = ['❤️', '😂', '😮', '😢', '😡', '👍'];
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: emojis.map((emoji) => GestureDetector(
                onTap: () { Navigator.pop(context); onReact(message.id, emoji); },
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(emoji, style: const TextStyle(fontSize: 26))),
              )).toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    final isText = message.type == 'text';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 8, bottom: 8), width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['❤️', '😂', '😮', '😢', '😡', '👍'].map((emoji) =>
                  GestureDetector(
                    onTap: () { Navigator.pop(context); onReact(message.id, emoji); },
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  )
                ).toList(),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('رد'),
              onTap: () { Navigator.pop(context); onReply(message.id); },
            ),
            if (isText) ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('نسخ'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: message.displayText));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ')));
              },
            ),
            if (isMe && isText && onEdit != null) ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF00A884)),
              title: const Text('تعديل'),
              onTap: () { Navigator.pop(context); onEdit?.call(message.id, message.displayText); },
            ),
            ListTile(
              leading: Icon(message.isStarred ? Icons.star : Icons.star_border, color: Colors.amber),
              title: Text(message.isStarred ? 'إلغاء التمييز' : 'تمييز'),
              onTap: () { Navigator.pop(context); onStar(message.id, !message.isStarred); },
            ),
            ListTile(
              leading: Icon(message.isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: Colors.blue),
              title: Text(message.isPinned ? 'إلغاء التثبيت' : 'تثبيت'),
              onTap: () { Navigator.pop(context); onPin(message.id, !message.isPinned); },
            ),
            ListTile(
              leading: const Icon(Icons.forward),
              title: const Text('تحويل'),
              onTap: () { Navigator.pop(context); onSelect(message.id); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('حذف', style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(context); onDelete(message.id); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ─── Link Preview Widget ──────────────────────────────────────────────────────
class _LinkPreviewWidget extends StatelessWidget {
  final String url;
  const _LinkPreviewWidget({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: const Center(child: Icon(Icons.link, size: 28, color: Colors.grey)),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Uri.tryParse(url)?.host ?? url,
                    style: const TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  Text(url, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
