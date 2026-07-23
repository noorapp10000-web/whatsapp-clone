import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/conversation_model.dart';
import '../services/firestore_service.dart';
import '../services/api_service.dart';
import 'contact_info_screen.dart';

class GroupInfoScreen extends StatefulWidget {
  final ConversationModel conversation;
  final String myUid;

  const GroupInfoScreen({super.key, required this.conversation, required this.myUid});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  late ConversationModel _conv;
  bool _editingName = false;
  bool _editingDesc = false;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _conv = widget.conversation;
    _nameCtrl.text = _conv.name ?? '';
    _descCtrl.text = _conv.description ?? '';
  }

  bool get _isAdmin => _conv.isAdmin(widget.myUid);

  @override
  Widget build(BuildContext context) {
    final participants = _conv.participants;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with photo
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildGroupHeader(),
            ),
            actions: [
              if (_isAdmin)
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () => _editGroupInfo(),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: _onMenuAction,
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'invite', child: Text('دعوة عبر رابط')),
                  if (_isAdmin)
                    const PopupMenuItem(value: 'settings', child: Text('إعدادات المجموعة')),
                  const PopupMenuItem(
                    value: 'leave',
                    child: Text('مغادرة المجموعة', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                if (_conv.description != null && _conv.description!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1F2C34) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, color: Color(0xFF00A884), size: 18),
                            const SizedBox(width: 8),
                            const Text('الوصف', style: TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold, fontSize: 13)),
                            const Spacer(),
                            if (_isAdmin)
                              GestureDetector(
                                onTap: () => _editGroupInfo(),
                                child: const Icon(Icons.edit, color: Colors.grey, size: 18),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_conv.description!, style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                  ),

                // Group Settings (admins only)
                if (_isAdmin) ...[
                  _sectionHeader('إعدادات المجموعة'),
                  _settingCard([
                    SwitchListTile.adaptive(
                      secondary: const Icon(Icons.lock_outline, color: Color(0xFF00A884)),
                      title: const Text('الرسائل فقط للمشرفين', style: TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: const Text('فقط المشرفون يمكنهم إرسال الرسائل', style: TextStyle(fontSize: 12)),
                      value: _conv.onlyAdminsCanMessage,
                      onChanged: (v) async {
                        await FirestoreService.updateConversation(_conv.id, {'onlyAdminsCanMessage': v});
                        setState(() => _conv = ConversationModel.fromJson({
                          'id': _conv.id,
                          'type': _conv.type,
                          'name': _conv.name,
                          'groupPhotoUrl': _conv.groupPhotoUrl,
                          'description': _conv.description,
                          'participants': _conv.participants,
                          'participantIds': _conv.participantIds,
                          'adminIds': _conv.adminIds,
                          'lastMessage': _conv.lastMessage,
                          'lastMessageAt': _conv.lastMessageAt,
                          'onlyAdminsCanMessage': v,
                          'pinnedMessageIds': _conv.pinnedMessageIds,
                          'blockedBy': _conv.blockedBy,
                        }));
                      },
                      activeColor: const Color(0xFF00A884),
                    ),
                  ]),
                ],

                // Invite link
                _sectionHeader('رابط الدعوة'),
                _settingCard([
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A884).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.link, color: Color(0xFF00A884)),
                    ),
                    title: Text(
                      'https://wa-clone.app/join/${_conv.id}',
                      style: const TextStyle(color: Color(0xFF00A884), fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: const Text('انقر لنسخ الرابط'),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: 'https://wa-clone.app/join/${_conv.id}'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم نسخ رابط الدعوة')),
                      );
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.share, color: Color(0xFF00A884)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('مشاركة رابط المجموعة')),
                        );
                      },
                    ),
                  ),
                ]),

                // Members
                _sectionHeader('${participants.length} مشارك'),
                if (_isAdmin)
                  ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A884).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add, color: Color(0xFF00A884)),
                    ),
                    title: const Text('إضافة مشارك', style: TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.w500)),
                    onTap: () => _addMember(),
                  ),
                Container(
                  color: isDark ? const Color(0xFF1F2C34) : Colors.white,
                  child: Column(
                    children: participants.map((p) => _buildMemberTile(p)).toList(),
                  ),
                ),

                // Leave group
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    onPressed: _leaveGroup,
                    icon: const Icon(Icons.exit_to_app, color: Colors.red),
                    label: const Text('مغادرة المجموعة', style: TextStyle(color: Colors.red, fontSize: 15)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupHeader() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _conv.groupPhotoUrl != null
            ? Image.network(_conv.groupPhotoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFF00A884).withOpacity(0.3)))
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF00A884), Color(0xFF007B63)],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.group, size: 80, color: Colors.white),
                ),
              ),
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
                  _conv.name ?? 'مجموعة',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_conv.participants.length} مشارك',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> p) {
    final uid = (p['uid'] ?? p['id'] ?? '') as String;
    final name = (p['displayName'] ?? p['name'] ?? 'مجهول') as String;
    final photo = p['photoUrl'] as String?;
    final isAdmin = _conv.adminIds.contains(uid);
    final isMe = uid == widget.myUid;

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: const Color(0xFF00A884).withOpacity(0.2),
        backgroundImage: photo != null ? NetworkImage(photo) : null,
        child: photo == null
            ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold))
            : null,
      ),
      title: Text(
        isMe ? '$name (أنت)' : name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: isAdmin
          ? const Text('مشرف', style: TextStyle(color: Color(0xFF00A884), fontSize: 12, fontWeight: FontWeight.w500))
          : null,
      onTap: isMe ? null : () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => ContactInfoScreen(uid: uid, myUid: widget.myUid),
      )),
      trailing: (!isMe && _isAdmin)
          ? PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (action) => _memberAction(action, uid, name, isAdmin),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'admin',
                  child: Text(isAdmin ? 'إلغاء صلاحيات المشرف' : 'تعيين كمشرف'),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('إزالة من المجموعة', style: TextStyle(color: Colors.red)),
                ),
              ],
            )
          : null,
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        title,
        style: const TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _settingCard(List<Widget> children) {
    return Container(
      color: Theme.of(context).cardColor,
      child: Column(children: children),
    );
  }

  void _editGroupInfo() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تعديل معلومات المجموعة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم المجموعة',
                prefixIcon: Icon(Icons.group, color: Color(0xFF00A884)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'الوصف (اختياري)',
                prefixIcon: Icon(Icons.info_outline, color: Color(0xFF00A884)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: _saving ? null : () async {
              setState(() => _saving = true);
              await FirestoreService.updateConversation(_conv.id, {
                'name': _nameCtrl.text.trim(),
                if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
              });
              setState(() => _saving = false);
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884)),
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _memberAction(String action, String uid, String name, bool isAdmin) async {
    switch (action) {
      case 'admin':
        if (isAdmin) {
          await FirestoreService.demoteAdmin(_conv.id, uid);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إلغاء صلاحيات $name')));
        } else {
          await FirestoreService.promoteToAdmin(_conv.id, uid);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تعيين $name كمشرف')));
        }
        break;
      case 'remove':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('إزالة $name'),
            content: Text('هل تريد إزالة $name من المجموعة؟'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('إزالة', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await FirestoreService.removeGroupMember(_conv.id, uid);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إزالة $name')));
        }
        break;
    }
  }

  void _addMember() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ميزة إضافة الأعضاء — تبحث عن مستخدمين...')),
    );
  }

  void _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('مغادرة المجموعة'),
        content: const Text('هل أنت متأكد من مغادرة هذه المجموعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('مغادرة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirestoreService.removeGroupMember(_conv.id, widget.myUid);
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  void _onMenuAction(String action) {
    switch (action) {
      case 'invite':
        Clipboard.setData(ClipboardData(text: 'https://wa-clone.app/join/${_conv.id}'));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم نسخ رابط الدعوة')),
        );
        break;
      case 'settings':
        break;
      case 'leave':
        _leaveGroup();
        break;
    }
  }
}
