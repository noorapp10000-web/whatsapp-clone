import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
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
    if (diff.inDays == 0) return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService.callsStream(myUid),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final calls = snap.data ?? [];
        if (calls.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.call, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No call history', style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }
        return ListView.separated(
          itemCount: calls.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
          itemBuilder: (_, i) {
            final call     = calls[i];
            final callerId  = call['callerId']   as String? ?? '';
            final receiverId = call['receiverId'] as String? ?? '';
            final isOutgoing = callerId == myUid;
            final otherUid  = isOutgoing ? receiverId : callerId;
            final isVideo   = (call['type'] as String? ?? '') == 'video';
            final isMissed  = ['missed','rejected'].contains(call['status'] as String? ?? '');

            return FutureBuilder<UserModel?>(
              future: FirestoreService.getUser(otherUid),
              builder: (_, uSnap) {
                final user  = uSnap.data;
                final name  = user?.displayName ?? otherUid;
                final photo = user?.photoUrl;
                return ListTile(
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF00A884),
                    backgroundImage: photo != null ? NetworkImage(photo) : null,
                    child: photo == null
                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 18))
                        : null,
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Row(children: [
                    Icon(isOutgoing ? Icons.call_made : Icons.call_received,
                        size: 14, color: isMissed ? Colors.red : const Color(0xFF00A884)),
                    const SizedBox(width: 4),
                    Text('${isMissed ? 'Missed ' : ''}${isVideo ? 'Video' : 'Voice'} call',
                        style: TextStyle(
                            color: isMissed ? Colors.red : Colors.grey[600], fontSize: 13)),
                  ]),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_fmtTime(call['startedAt']),
                          style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                      const SizedBox(height: 4),
                      Icon(isVideo ? Icons.videocam : Icons.call,
                          color: const Color(0xFF00A884), size: 20),
                    ],
                  ),
                  onTap: user == null ? null : () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => CallScreen(
                      otherUid: otherUid, otherName: name, otherPhoto: photo,
                      isVideo: isVideo, isIncoming: false,
                    ),
                  )),
                );
              },
            );
          },
        );
      },
    );
  }
}
