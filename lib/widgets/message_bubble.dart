import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
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
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 10),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.status == 'read'
                              ? Icons.done_all
                              : Icons.done,
                          size: 14,
                          color: message.status == 'read'
                              ? const Color(0xFF00A884)
                              : Colors.grey,
                        ),
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
                  left: isMe ? 0 : 12,
                  right: isMe ? 12 : 0,
                  bottom: 4,
                ),
                child: _buildReactions(),
              ),
          ],
        ),
      ),
    );
  }

  EdgeInsets _bubblePadding() {
    if (message.type == 'image') {
      return const EdgeInsets.all(4);
    }
    return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  }

  Widget _buildReactions() {
    final grouped = <String, int>{};
    for (final emoji in message.reactions!.values) {
      grouped[emoji] = (grouped[emoji] ?? 0) + 1;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: grouped.entries
            .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text('${e.key}${e.value > 1 ? " ${e.value}" : ""}',
                      style: const TextStyle(fontSize: 13)),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (message.type) {
      case 'image':
        return _buildImage();
      case 'video':
        return _buildVideo(context);
      case 'voice':
      case 'audio':
        return _buildVoice();
      case 'file':
        return _buildFile();
      case 'listen_together':
        return _buildListenTogether(context);
      default:
        return Text(
          message.content ?? '',
          style: const TextStyle(fontSize: 15, height: 1.3),
        );
    }
  }

  Widget _buildImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: message.fileUrl!,
        width: 220,
        height: 220,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 220,
          height: 220,
          color: Colors.grey[200],
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => Container(
          width: 220,
          height: 100,
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildVideo(BuildContext context) {
    return GestureDetector(
      onTap: () => _playVideo(context),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 220,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.video_file, color: Colors.white54, size: 48),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  void _playVideo(BuildContext context) {
    if (message.fileUrl == null) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(message.fileUrl!));
    showDialog(
      context: context,
      builder: (_) => _VideoDialog(controller: controller),
    );
  }

  Widget _buildVoice() {
    return SizedBox(
      width: 200,
      child: Row(
        children: [
          const Icon(Icons.mic, color: Color(0xFF00A884), size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: AudioPlayerWidget(
              url: message.fileUrl ?? '',
              isMe: isMe,
              durationMs: message.durationMs,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFile() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF00A884).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.insert_drive_file,
                color: Color(0xFF00A884), size: 22),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.fileName ?? 'File',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                if (message.fileSize != null)
                  Text(
                    _formatSize(message.fileSize!),
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListenTogether(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C2333), Color(0xFF0D1117)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF00A884).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.headphones,
                    color: Color(0xFF00A884), size: 20),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Listen Together',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    Text('Music invitation',
                        style:
                            TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.music_note,
                  color: Color(0xFF00A884), size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message.ltTitle ?? 'Unknown Song',
            style: const TextStyle(
                color: Colors.white70, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          if (!isMe && onJoinListen != null && message.ltSessionId != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onJoinListen!(message.ltSessionId!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A884),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Join Now',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            )
          else if (isMe)
            const Center(
              child: Text('Waiting for response...',
                  style: TextStyle(color: Colors.grey, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                  borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.reply, color: Color(0xFF00A884)),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                onReply(message.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_emotions_outlined,
                  color: Color(0xFF00A884)),
              title: const Text('React'),
              onTap: () {
                Navigator.pop(context);
                _showEmojiPicker(context);
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  onDelete(message.id);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEmojiPicker(BuildContext context) {
    const emojis = ['❤️', '😂', '😮', '😢', '👍', '👎'];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ─── Video Dialog ─────────────────────────────────────────────────────────────
class _VideoDialog extends StatefulWidget {
  final VideoPlayerController controller;
  const _VideoDialog({required this.controller});

  @override
  State<_VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<_VideoDialog> {
  @override
  void initState() {
    super.initState();
    widget.controller.initialize().then((_) {
      if (mounted) {
        setState(() {});
        widget.controller.play();
      }
    });
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          if (widget.controller.value.isInitialized)
            Center(child: AspectRatio(
              aspectRatio: widget.controller.value.aspectRatio,
              child: VideoPlayer(widget.controller),
            ))
          else
            const Center(child: CircularProgressIndicator()),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  if (widget.controller.value.isPlaying) {
                    widget.controller.pause();
                  } else {
                    widget.controller.play();
                  }
                  setState(() {});
                },
                child: Icon(
                  widget.controller.value.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: Colors.white,
                  size: 56,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
