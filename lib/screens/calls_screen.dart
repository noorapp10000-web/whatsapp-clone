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
      try { dt = (ts as Timestamp).toDate(); } catch (_) { return ''; }
    }
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return 'أمس';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _fmtDuration(int? secs) {
    if (secs == null) return '';
    final m = secs ~/ 60;
    final s = secs % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService.callsStream(myUid),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00A884)));
        }
        final calls = snap.data ?? [];
        if (calls.isEmpty) {
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
                  child: const Icon(Icons.call, size: 50, color: Color(0xFF00A884)),
                ),
                const SizedBox(height: 20),
                const Text('لا يوجد سجل مكالمات',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('ابدأ مكالمة من أي محادثة', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
          );
        }
        return ListView.separated(
          itemCount: calls.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
          itemBuilder: (ctx, i) {
            final call = calls[i];
            final isVideo = call['type'] == 'video';
            final isIncoming = (call['calleeUid'] ?? '') == myUid;
            final otherUid = isIncoming
                ? call['callerUid'] as String? ?? ''
                : call['calleeUid'] as String? ?? '';
            final otherName = call['otherName'] as String? ?? 'مجهول';
            final otherPhoto = call['otherPhoto'] as String?;
            final status = call['status'] as String? ?? '';
            final isMissed = status == 'missed' || (isIncoming && status == 'ended_by_caller');
            final duration = call['durationSeconds'] as int?;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF00A884).withOpacity(0.15),
                    backgroundImage: otherPhoto != null ? NetworkImage(otherPhoto) : null,
                    child: otherPhoto == null
                        ? Text(otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                            style: const TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold))
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1F2C34) : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isVideo ? Icons.videocam : Icons.call,
                        size: 12,
                        color: isMissed ? Colors.red : const Color(0xFF00A884),
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(otherName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Row(
                children: [
                  Icon(
                    isIncoming ? Icons.call_received : Icons.call_made,
                    size: 14,
                    color: isMissed ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isMissed ? 'مكالمة فائتة' : (isIncoming ? 'واردة' : 'صادرة'),
                    style: TextStyle(
                      color: isMissed ? Colors.red : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  if (duration != null) ...[
                    const Text(' • ', style: TextStyle(color: Colors.grey)),
                    Text(_fmtDuration(duration), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_fmtTime(call['createdAt']),
                      style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => CallScreen(
                        otherUid: otherUid,
                        otherName: otherName,
                        otherPhoto: otherPhoto,
                        isVideo: isVideo,
                        isIncoming: false,
                      ),
                    )),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A884).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isVideo ? Icons.videocam_outlined : Icons.call_outlined,
                        size: 16,
                        color: const Color(0xFF00A884),
                      ),
                    ),
                  ),
                ],
              ),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => CallScreen(
                  otherUid: otherUid,
                  otherName: otherName,
                  otherPhoto: otherPhoto,
                  isVideo: isVideo,
                  isIncoming: false,
                ),
              )),
            );
          },
        );
      },
    );
  }
}
