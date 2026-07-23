import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/conversation_model.dart';
import '../services/firestore_service.dart';
import 'chat_screen.dart';

class NewChatScreen extends StatefulWidget {
  final String myUid;
  const NewChatScreen({super.key, required this.myUid});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _ctrl = TextEditingController();
  List<UserModel> _results = [];
  bool _loading = false;
  final _selectedForGroup = <UserModel>[];
  final _groupNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _ctrl.dispose();
    _groupNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final users = await FirestoreService.searchUsers(q.trim(), widget.myUid);
      if (mounted) setState(() => _results = users);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openChat(UserModel user) async {
    try {
      final conv = await FirestoreService.createDirectConversation(
          widget.myUid, user.id);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversation: conv, myUid: widget.myUid),
        ),
      );
    } catch (_) {}
  }

  Future<void> _createGroup() async {
    final name = _groupNameCtrl.text.trim();
    if (name.isEmpty || _selectedForGroup.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('أدخل اسم المجموعة وأضف عضوًا على الأقل')),
      );
      return;
    }
    try {
      final conv = await FirestoreService.createGroupConversation(
        myUid: widget.myUid,
        memberUids: _selectedForGroup.map((u) => u.id).toList(),
        name: name,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversation: conv, myUid: widget.myUid),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00A884),
        foregroundColor: Colors.white,
        title: const Text('محادثة جديدة',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'مباشر'),
            Tab(icon: Icon(Icons.group), text: 'مجموعة جديدة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ── Direct chat ──
          Column(
            children: [
              Container(
                color: const Color(0xFFF0FFF8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Color(0xFF00A884), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ابحث بالاسم أو البريد الإلكتروني للعثور على مستخدم',
                        style: TextStyle(
                            color: Color(0xFF005C4B), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _ctrl,
                  textDirection: TextDirection.rtl,
                  onChanged: _search,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن مستخدم...',
                    prefixIcon: const Icon(Icons.search,
                        color: Color(0xFF00A884)),
                    suffixIcon: _ctrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _ctrl.clear();
                              setState(() => _results = []);
                            })
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: Color(0xFF00A884)),
                )
              else
                Expanded(
                  child: _results.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline,
                                  size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(
                                _ctrl.text.length < 2
                                    ? 'اكتب على الأقل حرفين للبحث'
                                    : 'لا يوجد مستخدمون بهذا الاسم',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (ctx, i) {
                            final u = _results[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    const Color(0xFF00A884).withOpacity(0.15),
                                backgroundImage: u.photoUrl != null
                                    ? NetworkImage(u.photoUrl!)
                                    : null,
                                child: u.photoUrl == null
                                    ? Text(
                                        u.displayName.isNotEmpty
                                            ? u.displayName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                            color: Color(0xFF00A884),
                                            fontWeight: FontWeight.bold))
                                    : null,
                              ),
                              title: Text(u.displayName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(u.email,
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 12)),
                              trailing: ElevatedButton.icon(
                                onPressed: () => _openChat(u),
                                icon: const Icon(Icons.chat, size: 16),
                                label: const Text('مراسلة'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00A884),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                              ),
                              onTap: () => _openChat(u),
                            );
                          },
                        ),
                ),
            ],
          ),

          // ── Group chat ──
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _groupNameCtrl,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'اسم المجموعة',
                    prefixIcon:
                        const Icon(Icons.group, color: Color(0xFF00A884)),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  onChanged: _search,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'ابحث لإضافة أعضاء...',
                    prefixIcon:
                        const Icon(Icons.search, color: Color(0xFF00A884)),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              if (_selectedForGroup.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: SizedBox(
                    height: 60,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _selectedForGroup
                          .map((u) => Padding(
                                padding:
                                    const EdgeInsets.only(left: 8),
                                child: Column(
                                  children: [
                                    Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: const Color(
                                                  0xFF00A884)
                                              .withOpacity(0.15),
                                          child: Text(
                                              u.displayName[0].toUpperCase(),
                                              style: const TextStyle(
                                                  color: Color(0xFF00A884),
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                        Positioned(
                                          top: -2,
                                          right: -2,
                                          child: GestureDetector(
                                            onTap: () => setState(() =>
                                                _selectedForGroup.remove(u)),
                                            child: const CircleAvatar(
                                              radius: 8,
                                              backgroundColor: Colors.red,
                                              child: Icon(Icons.close,
                                                  size: 10,
                                                  color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      u.displayName.split(' ').first,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (ctx, i) {
                    final u = _results[i];
                    final selected = _selectedForGroup.contains(u);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            const Color(0xFF00A884).withOpacity(0.15),
                        child: Text(u.displayName[0].toUpperCase(),
                            style: const TextStyle(
                                color: Color(0xFF00A884),
                                fontWeight: FontWeight.bold)),
                      ),
                      title: Text(u.displayName,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(u.email),
                      trailing: selected
                          ? const Icon(Icons.check_circle,
                              color: Color(0xFF00A884))
                          : const Icon(Icons.circle_outlined,
                              color: Colors.grey),
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _selectedForGroup.remove(u);
                          } else {
                            _selectedForGroup.add(u);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.group_add),
                    label: Text(
                        'إنشاء مجموعة (${_selectedForGroup.length} أعضاء)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A884),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed:
                        _selectedForGroup.isEmpty ? null : _createGroup,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
