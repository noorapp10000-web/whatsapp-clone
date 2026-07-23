import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';
import '../services/firestore_service.dart';
import '../widgets/message_bubble.dart';
import '../models/conversation_model.dart';

class StarredMessagesScreen extends StatelessWidget {
  const StarredMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('الرسائل المميزة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder<List<MessageModel>>(
        stream: FirestoreService.starredMessagesStream(myUid),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00A884)));
          }
          final messages = snap.data ?? [];
          if (messages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A884).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.star_outline, size: 50, color: Color(0xFF00A884)),
                  ),
                  const SizedBox(height: 20),
                  const Text('لا توجد رسائل مميزة',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'اضغط مطولاً على أي رسالة واختر "تمييز" لحفظها هنا',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: messages.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final msg = messages[i];
              return _StarredMessageTile(message: msg, myUid: myUid);
            },
          );
        },
      ),
    );
  }
}

class _StarredMessageTile extends StatelessWidget {
  final MessageModel message;
  final String myUid;

  const _StarredMessageTile({required this.message, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final isMe = message.senderId == myUid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onLongPress: () => _showOptions(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Star icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star, color: Colors.amber, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender name & time
                  Row(
                    children: [
                      Text(
                        isMe ? 'أنت' : (message.senderName ?? 'مجهول'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00A884),
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Message content preview
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe
                          ? const Color(0xFFDCF8C6)
                          : (isDark ? const Color(0xFF2A2A2A) : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: _buildContent(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (message.deleted) {
      return const Text('🚫 تم حذف هذه الرسالة',
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey));
    }
    switch (message.type) {
      case 'image':
        return Row(
          children: [
            const Icon(Icons.photo, size: 18, color: Colors.grey),
            const SizedBox(width: 6),
            const Text('صورة'),
            if (message.text != null && message.text!.isNotEmpty) ...[
              const Text(' — '),
              Expanded(child: Text(message.text!, maxLines: 2, overflow: TextOverflow.ellipsis)),
            ],
          ],
        );
      case 'audio':
        return const Row(
          children: [
            Icon(Icons.mic, size: 18, color: Colors.grey),
            SizedBox(width: 6),
            Text('رسالة صوتية'),
          ],
        );
      case 'video':
        return const Row(
          children: [
            Icon(Icons.videocam, size: 18, color: Colors.grey),
            SizedBox(width: 6),
            Text('فيديو'),
          ],
        );
      case 'file':
        return Row(
          children: [
            const Icon(Icons.attach_file, size: 18, color: Colors.grey),
            const SizedBox(width: 6),
            Expanded(child: Text(message.fileName ?? 'ملف', maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        );
      default:
        final text = message.isEdited && message.editedText != null
            ? message.editedText!
            : (message.text ?? '');
        return Text(text, maxLines: 3, overflow: TextOverflow.ellipsis);
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'أمس';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
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
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.star_outline, color: Colors.amber),
              title: const Text('إلغاء التمييز'),
              onTap: () {
                Navigator.pop(context);
                FirestoreService.starMessage(message.conversationId, message.id, false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('نسخ الرسالة'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
