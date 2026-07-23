import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'call_screen.dart';

class CallsScreen extends StatelessWidget {
  final String myUid;
  const CallsScreen({super.key, required this.myUid});

  String _fmtTime(dynamic ts) {
    if (ts == null) return '';
    DateTime dt;
    if (ts is String) {
      dt = DateTime.tryParse(ts) ?? DateTime.now();
    } else {
      try {
        dt = (ts as Timestamp).toDate();
      } catch (_) {
        return '';
      }
    }
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return 'أمس';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService.callsStream(myUid),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00A884)));
        }
        final calls = snap.data ?? [];
        if (calls.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.call, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('لا يوجد سجل مكالمات',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                const SizedBox(height: 8),
                Text('ابدأ مكالمة من أي محادثة',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13)),
              ],
            ),
          );
        }
        return ListView.separated(
          itemCount: calls.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 72),
          itemBuilder: (ctx, i) {
            final call = calls[i];
            final isVideo = call['type'] == 'video';
            final isIncoming =
                (call['calleeUid'] ?? '') == myUid;
            final otherUid = isIncoming
                ? call['callerUid'] as String? ?? ''
                : call['calleeUid'] as String? ?? '';
            final otherName =
                call['otherName'] as String? ?? 'مجهول';
            final otherPhoto = call['otherPhoto'] as String?;
            final status = call['status'] as String? ?? '';
            final isMissed =
                status == 'missed' || (isIncoming && status == 'ended_by_caller');

            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor:
                    const Color(0xFF00A884).withOpacity(0.15),
                backgroundImage:
                    otherPhoto != null ? NetworkImage(otherPhoto) : null,
                child: otherPhoto == null
                    ? Text(
                        otherName.isNotEmpty
                            ? otherName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Color(0xFF00A884),
                            fontWeight: FontWeight.bold))
                    : null,
              ),
              title: Text(otherName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Row(
                children: [
                  Icon(
                    isIncoming
                        ? Icons.call_received
                        : Icons.call_made,
                    size: 14,
                    color: isMissed ? Colors.red : const Color(0xFF00A884),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isMissed
                        ? 'مكالمة فائتة'
                        : isIncoming
                            ? 'واردة'
                            : 'صادرة',
                    style: TextStyle(
                      color: isMissed ? Colors.red : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _fmtTime(call['createdAt']),
                    style:
                        TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.call,
                        color: Color(0xFF00A884), size: 22),
                    tooltip: 'مكالمة صوتية',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CallScreen(
                          otherUid: otherUid,
                          otherName: otherName,
                          otherPhoto: otherPhoto,
                          isVideo: false,
                          isIncoming: false,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.videocam,
                        color: Color(0xFF00A884), size: 22),
                    tooltip: 'مكالمة فيديو',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CallScreen(
                          otherUid: otherUid,
                          otherName: otherName,
                          otherPhoto: otherPhoto,
                          isVideo: true,
                          isIncoming: false,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
