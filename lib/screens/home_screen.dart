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
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
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
          otherName: callerData['displayName'] as String? ?? 'مجهول',
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
        callerDoc.data()?['displayName'] as String? ?? 'أحدهم';
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.headphones, color: Color(0xFF00A884)),
          SizedBox(width: 8),
          Text('استماع معاً'),
        ]),
        content: Text('$callerName يدعوك للاستماع للموسيقى معاً!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              WebSocketService.sendLTReject(fromUid, sessionId);
            },
            child: const Text('رفض', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.headphones),
            label: const Text('انضم'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A884),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              WebSocketService.sendLTAccept(fromUid, sessionId);
              FirestoreService.updateListenSessionData(sessionId, {
                'participants': [_myUid],
              }).ignore();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MusicPlayerScreen(
                    sessionId: sessionId,
                    otherUid: fromUid,
                    isHost: false,
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
    await AuthService.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  void dispose() {
    WebSocketService.off('call_offer', _handleIncomingCall);
    WebSocketService.off('lt_invite', _handleLTInvite);
    _updateOnlineStatus(false);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00A884),
        title: const Text(
          'نور شات',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            tooltip: 'بحث',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NewChatScreen(myUid: _myUid),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v) {
              if (v == 'profile') {
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => ProfileScreen(myUid: _myUid)));
              } else if (v == 'logout') {
                _signOut();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'profile',
                  child: Row(children: [
                    Icon(Icons.person, color: Color(0xFF00A884)),
                    SizedBox(width: 12),
                    Text('الملف الشخصي'),
                  ])),
              const PopupMenuItem(
                  value: 'logout',
                  child: Row(children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 12),
                    Text('تسجيل الخروج'),
                  ])),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'الدردشات'),
            Tab(text: 'المكالمات'),
            Tab(text: 'المزيد'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ChatsTab(myUid: _myUid),
          CallsScreen(myUid: _myUid),
          _MoreTab(myUid: _myUid, onSignOut: _signOut),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF00A884),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => NewChatScreen(myUid: _myUid)),
              ),
              child: const Icon(Icons.chat, color: Colors.white),
            )
          : null,
    );
  }
}

// ── Chats Tab ────────────────────────────────────────────────────────────────
class _ChatsTab extends StatefulWidget {
  final String myUid;
  const _ChatsTab({required this.myUid});

  @override
  State<_ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<_ChatsTab> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConversationModel>>(
      stream: FirestoreService.conversationsStream(widget.myUid),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00A884)));
        }
        final convs = snap.data ?? [];
        if (convs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('لا توجد محادثات بعد',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                const SizedBox(height: 8),
                Text('اضغط على ✎ لبدء محادثة جديدة',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13)),
              ],
            ),
          );
        }
        return ListView.separated(
          itemCount: convs.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
          itemBuilder: (ctx, i) {
            final conv = convs[i];
            final photo = conv.displayPhoto(widget.myUid);
            final name = conv.displayName(widget.myUid);
            final isGroup = conv.type == 'group';

            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF00A884).withOpacity(0.15),
                backgroundImage:
                    photo != null ? NetworkImage(photo) : null,
                child: photo == null
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: Color(0xFF00A884),
                            fontWeight: FontWeight.bold,
                            fontSize: 18))
                    : null,
              ),
              title: Row(
                children: [
                  if (isGroup)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.group,
                          size: 14, color: Colors.grey),
                    ),
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text(
                    _fmtTime(conv.lastMessageAt),
                    style: TextStyle(
                        color: conv.unreadCount > 0
                            ? const Color(0xFF00A884)
                            : Colors.grey[500],
                        fontSize: 11),
                  ),
                ],
              ),
              subtitle: Row(
                children: [
                  Expanded(
                    child: Text(
                      _fmtLastMsg(conv.lastMessage),
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (conv.unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00A884),
                        shape: BoxShape.circle,
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
                      ChatScreen(conversation: conv, myUid: widget.myUid),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _fmtLastMsg(lastMsg) {
    if (lastMsg == null) return '';
    final type = lastMsg.type as String? ?? 'text';
    if (type == 'image') return '📷 صورة';
    if (type == 'video') return '🎥 فيديو';
    if (type == 'voice') return '🎤 رسالة صوتية';
    if (type == 'audio') return '🎵 صوت';
    if (type == 'file') return '📎 ${lastMsg.fileName ?? 'ملف'}';
    if (type == 'listen_together') return '🎵 استماع معاً';
    return lastMsg.content ?? '';
  }

  String _fmtTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    if (msgDay == today) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (today.difference(msgDay).inDays == 1) {
      return 'أمس';
    } else {
      return '${dt.day}/${dt.month}';
    }
  }
}

// ── More Tab ─────────────────────────────────────────────────────────────────
class _MoreTab extends StatelessWidget {
  final String myUid;
  final VoidCallback onSignOut;
  const _MoreTab({required this.myUid, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 8),
        _tile(context, Icons.person, 'الملف الشخصي', 'عرض وتعديل ملفك الشخصي',
            () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => ProfileScreen(myUid: myUid)))),
        _tile(context, Icons.notifications, 'الإشعارات', 'إدارة الإشعارات', null),
        _tile(context, Icons.lock, 'الخصوصية', 'إعدادات الخصوصية', null),
        _tile(context, Icons.color_lens, 'المظهر', 'تخصيص شكل التطبيق', null),
        const Divider(),
        _tile(context, Icons.help_outline, 'المساعدة', 'الأسئلة الشائعة', null),
        _tile(context, Icons.info_outline, 'عن التطبيق', 'الإصدار 2.0.0', null),
        const Divider(),
        ListTile(
          leading: const CircleAvatar(
              backgroundColor: Color(0xFFFFEEEE),
              child: Icon(Icons.logout, color: Colors.red)),
          title: const Text('تسجيل الخروج',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          onTap: onSignOut,
        ),
      ],
    );
  }

  Widget _tile(BuildContext ctx, IconData icon, String title, String subtitle,
      VoidCallback? onTap) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF00A884).withOpacity(0.1),
        child: Icon(icon, color: const Color(0xFF00A884)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle,
          style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      trailing: onTap != null
          ? const Icon(Icons.chevron_right, color: Colors.grey)
          : null,
      onTap: onTap,
    );
  }
}

