import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/websocket_service.dart';
import '../services/firestore_service.dart';
import '../models/conversation_model.dart';
import 'chat_screen.dart';
import 'new_chat_screen.dart';
import 'calls_screen.dart';
import 'call_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _myUid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _connectWs();
  }

  Future<void> _connectWs() async {
    await WebSocketService.connect();
    WebSocketService.on('call_offer', _handleIncomingCall);
  }

  void _handleIncomingCall(Map<String, dynamic> msg) async {
    final fromUid = msg['fromUid'] as String? ?? '';
    if (fromUid.isEmpty || !mounted) return;
    final isVideo = (msg['callType'] ?? '') == 'video';
    final offerSdp = msg['sdp'] as Map<String, dynamic>?;
    final callerDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(fromUid)
        .get();
    final callerData = callerDoc.data() ?? {};
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          otherUid: fromUid,
          otherName: callerData['displayName'] as String? ?? 'Unknown',
          otherPhoto: callerData['photoUrl'] as String?,
          isVideo: isVideo,
          isIncoming: true,
          offerSdp: offerSdp,
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    WebSocketService.disconnect();
    await AuthService.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  @override
  void dispose() {
    WebSocketService.off('call_offer', _handleIncomingCall);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF00A884),
        title: const Text('WhatsApp Clone',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () {}),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v) {
              if (v == 'logout') _signOut();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.call), text: 'Calls'),
            Tab(icon: Icon(Icons.chat), text: 'Chats'),
            Tab(icon: Icon(Icons.group), text: 'Groups'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CallsScreen(myUid: _myUid),
          _buildConvList(groupOnly: false),
          _buildConvList(groupOnly: true),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00A884),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NewChatScreen(myUid: _myUid)),
        ),
        child: const Icon(Icons.chat, color: Colors.white),
      ),
    );
  }

  Widget _buildConvList({required bool groupOnly}) {
    return StreamBuilder<List<ConversationModel>>(
      stream: FirestoreService.conversationsStream(_myUid),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data ?? [];
        final convs = groupOnly
            ? all.where((c) => c.type == 'group').toList()
            : all.where((c) => c.type != 'group').toList();

        if (convs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(groupOnly ? Icons.group : Icons.chat,
                    size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(groupOnly ? 'No groups yet' : 'No chats yet',
                    style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: convs.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 72),
          itemBuilder: (ctx, i) {
            final conv = convs[i];
            final name  = conv.displayName(_myUid);
            final photo = conv.displayPhoto(_myUid);
            final lastMsg = conv.lastMessage;
            final lastText = lastMsg == null
                ? 'Say hello!'
                : lastMsg.type == 'image' ? '📷 Photo'
                : lastMsg.type == 'video' ? '🎥 Video'
                : lastMsg.type == 'file'  ? '📎 File'
                : lastMsg.content ?? '';

            return ListTile(
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF00A884),
                backgroundImage: photo != null ? NetworkImage(photo) : null,
                child: photo == null
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 20))
                    : null,
              ),
              title: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              subtitle: Text(lastText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              trailing: Text(
                _fmtTime(conv.lastMessageAt),
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
              onTap: () => Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) =>
                      ChatScreen(conversation: conv, myUid: _myUid),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _fmtTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
