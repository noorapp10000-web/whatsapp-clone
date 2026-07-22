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
import 'profile_screen.dart';
import 'music_player_screen.dart';

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
    _updateOnlineStatus(true);
  }

  Future<void> _connectWs() async {
    await WebSocketService.connect();
    WebSocketService.on('call_offer', _handleIncomingCall);
    WebSocketService.on('lt_invite', _handleLTInvite);
  }

  void _updateOnlineStatus(bool online) {
    if (_myUid.isEmpty) return;
    FirestoreService.updateUserOnline(_myUid, online).ignore();
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

  void _handleLTInvite(Map<String, dynamic> msg) async {
    final fromUid = msg['fromUid'] as String? ?? '';
    final sessionId = msg['sessionId'] as String? ?? '';
    if (fromUid.isEmpty || sessionId.isEmpty || !mounted) return;
    final callerDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(fromUid)
        .get();
    final callerName =
        callerDoc.data()?['displayName'] as String? ?? 'Someone';
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.headphones, color: Color(0xFF00A884)),
          SizedBox(width: 8),
          Text('Listen Together'),
        ]),
        content: Text('$callerName wants to listen to music together!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              WebSocketService.sendLTReject(fromUid, sessionId);
            },
            child:
                const Text('Decline', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.headphones),
            label: const Text('Join'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A884),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              WebSocketService.sendLTAccept(fromUid, sessionId);
              FirestoreService.updateListenSession(
                  sessionId, {'status': 'active'}, _myUid);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MusicPlayerScreen(
                    sessionId: sessionId,
                    myUid: _myUid,
                    otherUid: fromUid,
                    otherName: callerName,
                    isCreator: false,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    _updateOnlineStatus(false);
    WebSocketService.disconnect();
    await AuthService.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  @override
  void dispose() {
    _updateOnlineStatus(false);
    WebSocketService.off('call_offer', _handleIncomingCall);
    WebSocketService.off('lt_invite', _handleLTInvite);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF00A884),
        elevation: 0,
        title: const Text('WhatsApp Clone',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => _tabController.animateTo(1),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v) {
              if (v == 'logout') _signOut();
              if (v == 'profile') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ProfileScreen(myUid: _myUid)));
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'profile',
                  child: ListTile(
                      leading: Icon(Icons.person),
                      title: Text('My Profile'),
                      contentPadding: EdgeInsets.zero,
                      dense: true)),
              const PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                      leading: Icon(Icons.logout, color: Colors.red),
                      title: Text('Logout',
                          style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                      dense: true)),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.call), text: 'Calls'),
            Tab(icon: Icon(Icons.chat_bubble), text: 'Chats'),
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
        elevation: 4,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => NewChatScreen(myUid: _myUid)),
        ),
        child: const Icon(Icons.chat, color: Colors.white),
      ),
    );
  }

  Widget _buildConvList({required bool groupOnly}) {
    return StreamBuilder<List<ConversationModel>>(
      stream: FirestoreService.conversationsStream(_myUid),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
                  CircularProgressIndicator(color: Color(0xFF00A884)));
        }
        final all = snap.data ?? [];
        final convs = groupOnly
            ? all.where((c) => c.type == 'group').toList()
            : all.where((c) => c.type == 'direct').toList();

        if (convs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    groupOnly ? Icons.group : Icons.chat_bubble_outline,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    groupOnly
                        ? 'No groups yet'
                        : 'No conversations yet',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    groupOnly
                        ? 'Create a group to chat with multiple friends at once'
                        : 'Tap the chat button below to start a conversation.\nSearch for friends by name or email.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: Icon(groupOnly ? Icons.group_add : Icons.person_add),
                    label: Text(groupOnly ? 'Create Group' : 'Start Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A884),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              NewChatScreen(myUid: _myUid)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          itemCount: convs.length,
          separatorBuilder: (_, __) => const Divider(
              height: 1, indent: 72, color: Color(0xFFEEEEEE)),
          itemBuilder: (_, i) {
            final conv = convs[i];
            final name = conv.displayName(_myUid);
            final photo = conv.displayPhoto(_myUid);
            final lastMsg = conv.lastMessage;
            final lastTime = conv.lastMessageAt;
            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF00A884),
                backgroundImage:
                    photo != null ? NetworkImage(photo) : null,
                child: photo == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              title: Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 16)),
              subtitle: lastMsg != null
                  ? Text(
                      _fmtLastMsg(lastMsg),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    )
                  : null,
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _fmtTime(lastTime),
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  if (conv.unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A884),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${conv.unreadCount}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              onTap: () => Navigator.push(
                context,
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

  String _fmtLastMsg(lastMsg) {
    final type = lastMsg.type as String? ?? 'text';
    if (type == 'image') return '📷 Image';
    if (type == 'video') return '🎥 Video';
    if (type == 'voice') return '🎤 Voice message';
    if (type == 'audio') return '🎵 Audio';
    if (type == 'file') return '📎 ${lastMsg.fileName ?? 'File'}';
    if (type == 'listen_together') return '🎵 Listen Together: ${lastMsg.ltTitle ?? 'Music'}';
    return lastMsg.content ?? '';
  }

  String _fmtTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    if (msgDay == today) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (today.difference(msgDay).inDays == 1) {
      return 'Yesterday';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }
}
