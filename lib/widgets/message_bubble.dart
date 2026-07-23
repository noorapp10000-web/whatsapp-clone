import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/message_model.dart';
import 'audio_player_widget.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final void Function(String id) onReply;
  final void Function(String id) onDelete;
  final void Function(String id, String emoji) onReact;
  final void Function(String sessionId)? onJoinListen;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.onReply,
    required this.onDelete,
    required this.onReact,
    this.onJoinListen,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showOptions(context),
      onDoubleTap: () => _showEmojiPicker(context),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78),
              margin:
                  const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
              padding: _bubblePadding(),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && message.senderName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.senderName!,
                        style: const TextStyle(
                          color: Color(0xFF00A884),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  _buildContent(context),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.createdAt),
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 10),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _buildStatusTick(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Reactions
            if (message.reactions != null && message.reactions!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  right: isMe ? 8 : 0,
                  left: isMe ? 0 : 8,
                  bottom: 4,
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: message.reactions!.entries
                        .map((e) => Text(e.value,
                            style: const TextStyle(fontSize: 14)))
                        .toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// WhatsApp-style status ticks:
  /// sent      → single grey tick  ✓
  /// delivered → double grey ticks ✓✓
  /// read      → double blue ticks ✓✓ (blue)
  Widget _buildStatusTick() {
    final status = message.status ?? 'sent';
    switch (status) {
      case 'read':
        return const Icon(Icons.done_all, size: 15,
            color: Color(0xFF53BDEB)); // WhatsApp blue
      case 'delivered':
        return Icon(Icons.done_all, size: 15, color: Colors.grey[500]);
      case 'sent':
      default:
        return Icon(Icons.done, size: 15, color: Colors.grey[500]);
    }
  }

  EdgeInsets _bubblePadding() {
    final t = message.type;
    if (t == 'image' || t == 'video') {
      return const EdgeInsets.all(4);
    }
    return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  }

  Widget _buildContent(BuildContext context) {
    switch (message.type) {
      case 'image':
        return _buildImage(context);
      case 'video':
        return _buildVideo();
      case 'voice':
      case 'audio':
        return _buildAudio();
      case 'file':
        return _buildFile();
      case 'listen_together':
        return _buildListenTogether(context);
      default:
        return _buildText();
    }
  }

  Widget _buildText() {
    return Text(
      message.content ?? '',
      style: const TextStyle(fontSize: 15, height: 1.4),
    );
  }

  Widget _buildImage(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: message.fileUrl ?? '',
        width: 240,
        height: 200,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 240,
          height: 200,
          color: Colors.grey[200],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (_, __, ___) => Container(
          width: 240,
          height: 200,
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildVideo() {
    return Container(
      width: 240,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.play_circle_fill, color: Colors.white, size: 48),
      ),
    );
  }

  Widget _buildAudio() {
    return SizedBox(
      width: 220,
      child: AudioPlayerWidget(
        url: message.fileUrl ?? '',
        isMe: isMe,
        durationMs: message.durationMs,
      ),
    );
  }

  Widget _buildFile() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF00A884).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.insert_drive_file,
              color: Color(0xFF00A884), size: 28),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.fileName ?? 'ملف',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              if (message.fileSize != null)
                Text(
                  _formatSize(message.fileSize!),
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListenTogether(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF005C4B), Color(0xFF00A884)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.headphones, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('استماع معاً',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message.ltTitle ?? 'جلسة موسيقية',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (onJoinListen != null && message.ltSessionId != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => onJoinListen!(message.ltSessionId!),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('انضم الآن',
                    style: TextStyle(
                        color: Color(0xFF00A884),
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.reply, color: Color(0xFF00A884)),
              title: const Text('رد'),
              onTap: () {
                Navigator.pop(context);
                onReply(message.id);
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('حذف'),
                onTap: () {
                  Navigator.pop(context);
                  onDelete(message.id);
                },
              ),
            ListTile(
              leading:
                  const Icon(Icons.emoji_emotions, color: Color(0xFF00A884)),
              title: const Text('تفاعل بإيموجي'),
              onTap: () {
                Navigator.pop(context);
                _showEmojiPicker(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEmojiPicker(BuildContext context) {
    const emojis = ['❤️', '😂', '😮', '😢', '👍', '🙏'];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: emojis
              .map((e) => GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onReact(message.id, e);
                    },
                    child: Text(e, style: const TextStyle(fontSize: 28)),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
