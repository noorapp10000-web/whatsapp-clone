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
      final users =
          await FirestoreService.searchUsers(q.trim(), widget.myUid);
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
          builder: (_) =>
              ChatScreen(conversation: conv, myUid: widget.myUid),
        ),
      );
    } catch (_) {}
  }

  Future<void> _createGroup() async {
    final name = _groupNameCtrl.text.trim();
    if (name.isEmpty || _selectedForGroup.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a group name and add at least one member')));
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
          builder: (_) =>
              ChatScreen(conversation: conv, myUid: widget.myUid),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00A884),
        foregroundColor: Colors.white,
        title: const Text('New Chat',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Direct'),
            Tab(icon: Icon(Icons.group), text: 'New Group'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ── Direct chat ──
          Column(
            children: [
              // Help text
              Container(
                width: double.infinity,
                color: const Color(0xFFF0FFF8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Color(0xFF00A884), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Search by name or email to find friends',
                        style: TextStyle(
                            color: Color(0xFF00A884), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _ctrl,
                  onChanged: _search,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search by name or email…',
                    prefixIcon: const Icon(Icons.search,
                        color: Color(0xFF00A884)),
                    filled: true,
                    fillColor: const Color(0xFFF0F0F0),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                    suffixIcon: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF00A884))))
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: _results.isEmpty && !_loading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_search,
                                size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              _ctrl.text.length < 2
                                  ? 'Type at least 2 characters to search'
                                  : 'No users found',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(
                            height: 1, indent: 72),
                        itemBuilder: (_, i) {
                          final u = _results[i];
                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFF00A884),
                              backgroundImage: u.photoUrl != null
                                  ? NetworkImage(u.photoUrl!)
                                  : null,
                              child: u.photoUrl == null
                                  ? Text(
                                      u.displayName.isNotEmpty
                                          ? u.displayName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold))
                                  : null,
                            ),
                            title: Text(u.displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(u.email,
                                style:
                                    TextStyle(color: Colors.grey[500])),
                            trailing: u.isOnline
                                ? Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                        color: Color(0xFF00A884),
                                        shape: BoxShape.circle))
                                : null,
                            onTap: () => _openChat(u),
                          );
                        },
                      ),
              ),
            ],
          ),

          // ── New Group ──
          Column(
            children: [
              Container(
                color: const Color(0xFFF0FFF8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Color(0xFF00A884), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Search and select members, then set a group name',
                        style: TextStyle(
                            color: Color(0xFF00A884), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectedForGroup.isNotEmpty)
                Container(
                  height: 68,
                  color: Colors.white,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: _selectedForGroup.length,
                    itemBuilder: (_, i) {
                      final u = _selectedForGroup[i];
                      return Padding(
                        padding:
                            const EdgeInsets.only(right: 8),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor:
                                  const Color(0xFF00A884),
                              backgroundImage: u.photoUrl != null
                                  ? NetworkImage(u.photoUrl!)
                                  : null,
                              child: u.photoUrl == null
                                  ? Text(
                                      u.displayName.isNotEmpty
                                          ? u.displayName[0]
                                              .toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: Colors.white))
                                  : null,
                            ),
                            Positioned(
                              top: -4,
                              right: -4,
                              child: GestureDetector(
                                onTap: () => setState(() =>
                                    _selectedForGroup.remove(u)),
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.close,
                                      color: Colors.white,
                                      size: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: TextField(
                  controller: _groupNameCtrl,
                  decoration: InputDecoration(
                    hintText: 'Group name…',
                    prefixIcon: const Icon(Icons.group,
                        color: Color(0xFF00A884)),
                    filled: true,
                    fillColor: const Color(0xFFF0F0F0),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: TextField(
                  onChanged: _search,
                  decoration: InputDecoration(
                    hintText: 'Search members…',
                    prefixIcon: const Icon(Icons.search,
                        color: Color(0xFF00A884)),
                    filled: true,
                    fillColor: const Color(0xFFF0F0F0),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (_, i) {
                    final u = _results[i];
                    final selected = _selectedForGroup.contains(u);
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor:
                            const Color(0xFF00A884),
                        backgroundImage: u.photoUrl != null
                            ? NetworkImage(u.photoUrl!)
                            : null,
                        child: u.photoUrl == null
                            ? Text(
                                u.displayName.isNotEmpty
                                    ? u.displayName[0]
                                        .toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: Colors.white))
                            : null,
                      ),
                      title: Text(u.displayName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
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
                        'Create Group (${_selectedForGroup.length} members)'),
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
