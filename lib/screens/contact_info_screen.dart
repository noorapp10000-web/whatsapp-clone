import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';
import '../models/conversation_model.dart';
import '../services/firestore_service.dart';
import 'chat_screen.dart';
import 'call_screen.dart';

class ContactInfoScreen extends StatefulWidget {
  final String uid;
  final String myUid;
  final ConversationModel? conversation;

  const ContactInfoScreen({
    super.key,
    required this.uid,
    required this.myUid,
    this.conversation,
  });

  @override
  State<ContactInfoScreen> createState() => _ContactInfoScreenState();
}

class _ContactInfoScreenState extends State<ContactInfoScreen> {
  UserModel? _user;
  bool _loading = true;
  bool _isBlocked = false;
  bool _isMuted = false;
  List<String> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = await FirestoreService.getUser(widget.uid);
    final blocked = await FirestoreService.getBlockedUsers(widget.myUid);
    setState(() {
      _user = user;
      _blockedUsers = blocked;
      _isBlocked = blocked.contains(widget.uid);
      _isMuted = widget.conversation?.isMutedNow() ?? false;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF00A884))));
    }
    final user = _user;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('معلومات الاتصال')),
        body: const Center(child: Text('المستخدم غير موجود')),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with photo
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHero(user),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: _onMenuAction,
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'share', child: Text('مشاركة الاتصال')),
                  PopupMenuItem(
                    value: 'block',
                    child: Text(_isBlocked ? 'إلغاء الحجب' : 'حجب',
                        style: TextStyle(color: _isBlocked ? Colors.green : Colors.red)),
                  ),
                  const PopupMenuItem(value: 'report', child: Text('الإبلاغ عن إساءة', style: TextStyle(color: Colors.red))),
                ],
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                // Action buttons
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _actionButton(Icons.chat_bubble_outline, 'رسالة', () => _openChat(user)),
                      _actionButton(Icons.call_outlined, 'مكالمة صوتية', () => _call(user, false)),
                      _actionButton(Icons.videocam_outlined, 'مكالمة فيديو', () => _call(user, true)),
                      _actionButton(Icons.search, 'بحث', () {}),
                    ],
                  ),
                ),

                // Info section
                _sectionCard([
                  _infoTile(
                    icon: Icons.info_outline,
                    title: user.status ?? 'لا توجد حالة',
                    subtitle: 'الحالة',
                  ),
                  const Divider(height: 1, indent: 56),
                  _infoTile(
                    icon: Icons.email_outlined,
                    title: user.email,
                    subtitle: 'البريد الإلكتروني',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: user.email));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم نسخ البريد الإلكتروني')),
                      );
                    },
                  ),
                  if (user.lastSeen != null) ...[
                    const Divider(height: 1, indent: 56),
                    _infoTile(
                      icon: Icons.access_time,
                      title: user.isOnline ? 'متصل الآن' : _formatLastSeen(user.lastSeen!),
                      subtitle: 'آخر ظهور',
                    ),
                  ],
                ]),

                const SizedBox(height: 8),

                // Notification settings
                _sectionCard([
                  SwitchListTile.adaptive(
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.notifications_outlined, color: Colors.orange),
                    ),
                    title: const Text('كتم الإشعارات', style: TextStyle(fontWeight: FontWeight.w500)),
                    value: _isMuted,
                    onChanged: widget.conversation == null ? null : (v) async {
                      setState(() => _isMuted = v);
                      await FirestoreService.muteConversation(
                        widget.conversation!.id,
                        v,
                        until: v ? DateTime.now().add(const Duration(hours: 8)) : null,
                      );
                    },
                    activeColor: const Color(0xFF00A884),
                  ),
                ]),

                const SizedBox(height: 8),

                // Media section header
                if (widget.conversation != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الوسائط والملفات والروابط',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        TextButton(
                          onPressed: () {},
                          child: const Text('عرض الكل', style: TextStyle(color: Color(0xFF00A884))),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // Block / Report section
                _sectionCard([
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (_isBlocked ? Colors.green : Colors.red).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _isBlocked ? Icons.lock_open : Icons.block,
                        color: _isBlocked ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(
                      _isBlocked ? 'إلغاء حجب ${user.displayName}' : 'حجب ${user.displayName}',
                      style: TextStyle(color: _isBlocked ? Colors.green : Colors.red, fontWeight: FontWeight.w500),
                    ),
                    onTap: _toggleBlock,
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.report_outlined, color: Colors.red),
                    ),
                    title: Text('الإبلاغ عن ${user.displayName}',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                    onTap: _reportUser,
                  ),
                ]),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(UserModel user) {
    return Stack(
      fit: StackFit.expand,
      children: [
        user.photoUrl != null
            ? Image.network(user.photoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFF00A884).withOpacity(0.2)))
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF00A884), Color(0xFF007B63)],
                  ),
                ),
                child: Center(
                  child: Text(
                    user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
        // Gradient overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: user.isOnline ? const Color(0xFF25D366) : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      user.isOnline ? 'متصل الآن' : 'غير متصل',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF00A884).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF00A884), size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF00A884)), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _sectionCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      color: Theme.of(context).cardColor,
      child: Column(children: children),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF00A884).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF00A884), size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)) : null,
      onTap: onTap,
      trailing: onTap != null ? const Icon(Icons.copy, size: 16, color: Colors.grey) : null,
    );
  }

  String _formatLastSeen(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'منذ لحظة';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays == 1) return 'أمس ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _openChat(UserModel user) async {
    if (widget.conversation != null) {
      Navigator.pop(context);
      return;
    }
    final conv = await FirestoreService.createDirectConversation(widget.myUid, user.id);
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => ChatScreen(conversation: conv, myUid: widget.myUid),
      ));
    }
  }

  void _call(UserModel user, bool isVideo) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CallScreen(
        otherUid: user.id,
        otherName: user.displayName,
        otherPhoto: user.photoUrl,
        isVideo: isVideo,
        isIncoming: false,
        convId: widget.conversation?.id,
      ),
    ));
  }

  void _toggleBlock() async {
    final userName = _user?.displayName ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_isBlocked ? 'إلغاء حجب $userName' : 'حجب $userName'),
        content: Text(_isBlocked
            ? 'ستتمكن الآن من استلام رسائل ومكالمات من $userName'
            : 'لن تتلقى أي رسائل أو مكالمات من $userName'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _isBlocked ? Colors.green : Colors.red),
            child: Text(_isBlocked ? 'إلغاء الحجب' : 'حجب', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      if (_isBlocked) {
        await FirestoreService.unblockUser(widget.myUid, widget.uid);
      } else {
        await FirestoreService.blockUser(widget.myUid, widget.uid);
      }
      setState(() => _isBlocked = !_isBlocked);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isBlocked ? 'تم حجب $userName' : 'تم إلغاء حجب $userName')),
        );
      }
    }
  }

  void _reportUser() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('الإبلاغ عن إساءة'),
        content: const Text('هل تريد الإبلاغ عن هذا المستخدم لانتهاك شروط الخدمة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم إرسال تقرير الإبلاغ. شكراً لك.')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('إبلاغ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _onMenuAction(String action) {
    switch (action) {
      case 'share':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('مشاركة جهة الاتصال')),
        );
        break;
      case 'block':
        _toggleBlock();
        break;
      case 'report':
        _reportUser();
        break;
    }
  }
}
