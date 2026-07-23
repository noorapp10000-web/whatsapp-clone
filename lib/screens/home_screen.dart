import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/websocket_service.dart';
import '../services/firestore_service.dart';
import '../models/conversation_model.dart';
import '../models/status_model.dart';
import 'chat_screen.dart';
import 'new_chat_screen.dart';
import 'calls_screen.dart';
import 'call_screen.dart';
import 'status_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'starred_messages_screen.dart';
import 'search_screen.dart';
import 'music_player_screen.dart';
import 'group_info_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late String _myUid;
  String _myName = '';
  String? _myPhoto;

  bool _searching = false;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Filter tabs in chats
  String _chatFilter = 'all'; // all | unread | groups | archived

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 0);
    final user = FirebaseAuth.instance.currentUser;
    _myUid = user?.uid ?? '';
    _myName = user?.displayName ?? '';
    _myPhoto = user?.photoURL;
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
    final callerDoc = await FirebaseFirestore.instance.collection('users').doc(fromUid).get();
    final callerData = callerDoc.data() ?? {};
    if (!mounted) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      pageBuilder: (_, __, ___) => CallScreen(
        otherUid: fromUid,
        otherName: callerData['displayName'] as String? ?? 'مجهول',
        otherPhoto: callerData['photoUrl'] as String?,
        isVideo: isVideo,
        isIncoming: true,
        offerSdp: offerSdp,
      ),
    );
  }

  void _handleLTInvite(Map<String, dynamic> msg) async {
    final fromUid = msg['fromUid'] as String? ?? '';
    final sessionId = msg['sessionId'] as String? ?? '';
    if (fromUid.isEmpty || sessionId.isEmpty || !mounted) return;
    final callerDoc = await FirebaseFirestore.instance.collection('users').doc(fromUid).get();
    final callerName = callerDoc.data()?['displayName'] as String? ?? 'أحدهم';
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
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => MusicPlayerScreen(
                  sessionId: sessionId,
                  otherUid: fromUid,
                  isHost: false,
                ),
              ));
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WebSocketService.off('call_offer', _handleIncomingCall);
    WebSocketService.off('lt_invite', _handleLTInvite);
    _updateOnlineStatus(false);
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarColor = isDark ? const Color(0xFF1F2C34) : const Color(0xFF00A884);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: appBarColor,
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'ابحث...',
                  hintStyle: TextStyle(color: Colors.white60),
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text('WhatsApp Clone',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          if (!_searching) ...[
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () => setState(() => _searching = true),
              tooltip: 'بحث',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: _onMenuAction,
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'new_group', child: Text('مجموعة جديدة')),
                const PopupMenuItem(value: 'starred', child: Text('الرسائل المميزة')),
                const PopupMenuItem(value: 'settings', child: Text('الإعدادات')),
                const PopupMenuItem(value: 'profile', child: Text('الملف الشخصي')),
                const PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج')),
              ],
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => setState(() {
                _searching = false;
                _searchQuery = '';
                _searchCtrl.clear();
              }),
            ),
          ],
        ],
        bottom: _searching
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'الدردشات'),
                  Tab(icon: Icon(Icons.circle, size: 10), text: 'الحالة'),
                  Tab(text: 'المكالمات'),
                  Tab(text: 'المجتمع'),
                ],
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
              ),
      ),
      body: _searching
          ? SearchScreen(myUid: _myUid, query: _searchQuery)
          : TabBarView(
              controller: _tabController,
              children: [
                _ChatsTab(myUid: _myUid, filter: _chatFilter, onFilterChange: (f) => setState(() => _chatFilter = f)),
                StatusScreen(myUid: _myUid, myName: _myName, myPhoto: _myPhoto),
                CallsScreen(myUid: _myUid),
                _CommunityTab(myUid: _myUid),
              ],
            ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: () {
        final tabIdx = _tabController.index;
        if (tabIdx == 0) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => NewChatScreen(myUid: _myUid),
          ));
        } else if (tabIdx == 1) {
          _showCreateStatus();
        } else if (tabIdx == 2) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => NewChatScreen(myUid: _myUid),
          ));
        }
      },
      backgroundColor: const Color(0xFF25D366),
      child: Icon(
        _tabController.index == 1 ? Icons.edit : Icons.chat_bubble,
        color: Colors.white,
      ),
    );
  }

  void _showCreateStatus() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CreateStatusScreen(myUid: _myUid, myName: _myName, myPhoto: _myPhoto),
    ));
  }

  void _onMenuAction(String action) async {
    switch (action) {
      case 'new_group':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => NewChatScreen(myUid: _myUid),
        ));
        break;
      case 'starred':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const StarredMessagesScreen(),
        ));
        break;
      case 'settings':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
        ));
        break;
      case 'profile':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ProfileScreen(myUid: _myUid),
        ));
        break;
      case 'logout':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('تسجيل الخروج'),
            content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('خروج', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (confirm == true && mounted) {
          _updateOnlineStatus(false);
          WebSocketService.disconnect();
          await AuthService.signOut();
          if (mounted) Navigator.pushReplacementNamed(context, '/login');
        }
        break;
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Chats Tab
// ──────────────────────────────────────────────────────────────────────────────
class _ChatsTab extends StatefulWidget {
  final String myUid;
  final String filter;
  final ValueChanged<String> onFilterChange;

  const _ChatsTab({required this.myUid, required this.filter, required this.onFilterChange});

  @override
  State<_ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<_ChatsTab> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Filter chips
        Container(
          color: isDark ? const Color(0xFF1F2C34) : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('all', 'الكل'),
                const SizedBox(width: 8),
                _filterChip('unread', 'غير مقروء'),
                const SizedBox(width: 8),
                _filterChip('groups', 'مجموعات'),
                const SizedBox(width: 8),
                _filterChip('archived', 'مؤرشفة'),
              ],
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ConversationModel>>(
            stream: FirestoreService.conversationsStream(widget.myUid),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF00A884)));
              }
              final all = snap.data ?? [];
              final filtered = _applyFilter(all);
              if (filtered.isEmpty) {
                return _emptyState();
              }
              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (ctx, i) => _ConversationTile(
                  conv: filtered[i],
                  myUid: widget.myUid,
                  onTap: () => _openChat(filtered[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<ConversationModel> _applyFilter(List<ConversationModel> all) {
    switch (widget.filter) {
      case 'unread':
        return all.where((c) => c.unreadCount(widget.myUid) > 0 && !c.isArchived).toList();
      case 'groups':
        return all.where((c) => c.isGroup() && !c.isArchived).toList();
      case 'archived':
        return all.where((c) => c.isArchived).toList();
      default:
        return all.where((c) => !c.isArchived).toList();
    }
  }

  Widget _filterChip(String value, String label) {
    final selected = widget.filter == value;
    return GestureDetector(
      onTap: () => widget.onFilterChange(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF00A884) : Colors.grey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey[700],
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            widget.filter == 'archived' ? 'لا توجد محادثات مؤرشفة' : 'لا توجد محادثات',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ محادثة جديدة بالضغط على زر الدردشة',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _openChat(ConversationModel conv) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatScreen(conversation: conv, myUid: widget.myUid),
    ));
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationModel conv;
  final String myUid;
  final VoidCallback onTap;

  const _ConversationTile({required this.conv, required this.myUid, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = conv.displayName(myUid);
    final photo = conv.displayPhoto(myUid);
    final unread = conv.unreadCount(myUid);
    final isMuted = conv.isMutedNow();
    final lastMsg = conv.lastMessage ?? '';

    return Dismissible(
      key: Key(conv.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.archive, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        await FirestoreService.archiveConversation(conv.id, !conv.isArchived);
        return false;
      },
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showOptions(context),
        child: Container(
          color: isDark ? const Color(0xFF1F2C34) : Colors.white,
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Hero(
                  tag: 'avatar_${conv.id}',
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFF00A884).withOpacity(0.2),
                        backgroundImage: photo != null ? NetworkImage(photo) : null,
                        child: photo == null
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Color(0xFF00A884),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              )
                            : null,
                      ),
                      if (conv.isGroup())
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xFF00A884),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.group, color: Colors.white, size: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatTime(conv.lastMessageAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: unread > 0 ? const Color(0xFF00A884) : Colors.grey,
                        fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                subtitle: Row(
                  children: [
                    Expanded(
                      child: Text(
                        lastMsg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unread > 0 ? Colors.black87 : Colors.grey[600],
                          fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isMuted)
                      Icon(Icons.volume_off, size: 14, color: Colors.grey[400]),
                    if (unread > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isMuted ? Colors.grey : const Color(0xFF00A884),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          unread > 99 ? '99+' : unread.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
              Divider(height: 1, indent: 72, color: Colors.grey.withOpacity(0.15)),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'أمس';
    } else if (diff.inDays < 7) {
      const days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
      return days[dt.weekday % 7];
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
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.archive),
              title: Text(conv.isArchived ? 'إلغاء الأرشفة' : 'أرشفة'),
              onTap: () {
                Navigator.pop(context);
                FirestoreService.archiveConversation(conv.id, !conv.isArchived);
              },
            ),
            ListTile(
              leading: Icon(conv.isMutedNow() ? Icons.volume_up : Icons.volume_off),
              title: Text(conv.isMutedNow() ? 'إلغاء الكتم' : 'كتم الإشعارات'),
              onTap: () {
                Navigator.pop(context);
                FirestoreService.muteConversation(conv.id, !conv.isMutedNow());
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('حذف المحادثة', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                // Show confirmation
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Community Tab
// ──────────────────────────────────────────────────────────────────────────────
class _CommunityTab extends StatelessWidget {
  final String myUid;
  const _CommunityTab({required this.myUid});

  @override
  Widget build(BuildContext context) {
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
            child: const Icon(Icons.people, size: 50, color: Color(0xFF00A884)),
          ),
          const SizedBox(height: 20),
          const Text('مجتمعات WhatsApp Clone',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'أنشئ مجتمعات وأدر مجموعات متعددة في مكان واحد',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => NewChatScreen(myUid: myUid),
              ));
            },
            icon: const Icon(Icons.add),
            label: const Text('إنشاء مجتمع جديد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A884),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
