import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/conversation_model.dart';
import '../services/firestore_service.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
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

  // Direct chat tab
  final _searchCtrl = TextEditingController();
  List<UserModel> _searchResults = [];
  List<UserModel> _contacts = [];
  bool _searchLoading = false;
  bool _contactsLoading = true;

  // Group tab
  final _selectedForGroup = <UserModel>[];
  final _groupNameCtrl = TextEditingController();
  final _groupDescCtrl = TextEditingController();
  String? _groupPhotoUrl;
  bool _creatingGroup = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadContacts();
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    _groupNameCtrl.dispose();
    _groupDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() => _contactsLoading = true);
    try {
      final res = await ApiService.getContacts();
      final list = List<Map<String, dynamic>>.from(
          (res['contacts'] as List?) ?? []);
      if (mounted) {
        setState(() {
          _contacts = list.map((c) => UserModel.fromJson(c)).toList();
          _contactsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _contactsLoading = false);
    }
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searchLoading = true);
    try {
      final results =
          await FirestoreService.searchUsers(q, widget.myUid);
      if (mounted) setState(() {
        _searchResults = results;
        _searchLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  Future<void> _openDirectChat(UserModel user) async {
    final conv = await FirestoreService.createDirectConversation(
        widget.myUid, user.id);
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) =>
            ChatScreen(conversation: conv, myUid: widget.myUid),
      ));
    }
  }

  Future<void> _createGroup() async {
    if (_groupNameCtrl.text.trim().isEmpty ||
        _selectedForGroup.isEmpty) return;
    setState(() => _creatingGroup = true);
    try {
      final conv = await FirestoreService.createGroupConversation(
        myUid: widget.myUid,
        memberUids:
            _selectedForGroup.map((u) => u.id).toList(),
        name: _groupNameCtrl.text.trim(),
        photoUrl: _groupPhotoUrl,
        description: _groupDescCtrl.text.trim().isEmpty
            ? null
            : _groupDescCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) =>
              ChatScreen(conversation: conv, myUid: widget.myUid),
        ));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
    if (mounted) setState(() => _creatingGroup = false);
  }

  Future<void> _pickGroupPhoto() async {
    final p = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (p == null) return;
    try {
      final bytes = await File(p.path).readAsBytes();
      final result = await ApiService.uploadFile(
        base64:
            'data:image/jpeg;base64,${base64Encode(bytes)}',
        mimeType: 'image/jpeg',
        fileName:
            'group_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      if (mounted)
        setState(() =>
            _groupPhotoUrl = result['url'] as String?);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('محادثة جديدة'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFF00A884),
          labelColor: const Color(0xFF00A884),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'مباشرة'),
            Tab(icon: Icon(Icons.group), text: 'مجموعة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildDirectTab(isDark),
          _buildGroupTab(isDark),
        ],
      ),
    );
  }

  // ─── Direct Chat Tab ────────────────────────────────────────────
  Widget _buildDirectTab(bool isDark) {
    final showSearch = _searchCtrl.text.trim().length >= 2;
    final displayList =
        showSearch ? _searchResults : _contacts;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (q) {
              setState(() {});
              _search(q);
            },
            decoration: InputDecoration(
              hintText: 'ابحث عن شخص...',
              prefixIcon: const Icon(Icons.search,
                  color: Color(0xFF00A884)),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchResults = []);
                      })
                  : null,
              filled: true,
              fillColor: isDark
                  ? Colors.grey[800]
                  : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
            ),
          ),
        ),

        // Header
        if (!showSearch) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Text(
                  'جهات الاتصال (${_contacts.length})',
                  style: TextStyle(
                    color: const Color(0xFF00A884),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh,
                      size: 18, color: Color(0xFF00A884)),
                  onPressed: _loadContacts,
                  tooltip: 'تحديث',
                ),
              ],
            ),
          ),
        ] else if (_searchLoading) ...[
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF00A884)),
            ),
          ),
        ],

        // List
        Expanded(
          child: _contactsLoading && !showSearch
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF00A884)))
              : displayList.isEmpty
                  ? _emptyState(showSearch)
                  : ListView.builder(
                      itemCount: displayList.length,
                      itemBuilder: (_, i) {
                        final user = displayList[i];
                        // In group tab, allow selection
                        return _ContactTile(
                          user: user,
                          onTap: () => _openDirectChat(user),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _emptyState(bool isSearch) {
    if (isSearch) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off,
                size: 60, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('لا توجد نتائج',
                style: TextStyle(
                    color: Colors.grey[500], fontSize: 15)),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF00A884).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_outline,
                size: 40, color: Color(0xFF00A884)),
          ),
          const SizedBox(height: 16),
          const Text('لا توجد جهات اتصال بعد',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(
            'ابحث عن أشخاص وأضفهم كجهات اتصال\nلتبدأ المحادثة معهم',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ─── Group Chat Tab ─────────────────────────────────────────────
  Widget _buildGroupTab(bool isDark) {
    final availableUsers = _contacts.isNotEmpty
        ? _contacts
        : _searchResults;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group photo + name
          Row(
            children: [
              GestureDetector(
                onTap: _pickGroupPhoto,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A884).withOpacity(0.1),
                    shape: BoxShape.circle,
                    image: _groupPhotoUrl != null
                        ? DecorationImage(
                            image: NetworkImage(_groupPhotoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _groupPhotoUrl == null
                      ? const Icon(Icons.camera_alt,
                          color: Color(0xFF00A884), size: 28)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _groupNameCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'اسم المجموعة *',
                    prefixIcon: const Icon(Icons.group,
                        color: Color(0xFF00A884)),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF00A884), width: 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _groupDescCtrl,
            decoration: InputDecoration(
              hintText: 'وصف المجموعة (اختياري)',
              prefixIcon: const Icon(Icons.info_outline,
                  color: Color(0xFF00A884)),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFF00A884), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Selected members
          if (_selectedForGroup.isNotEmpty) ...[
            Text('الأعضاء المختارون (${_selectedForGroup.length})',
                style: const TextStyle(
                    color: Color(0xFF00A884),
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedForGroup.length,
                itemBuilder: (_, i) {
                  final u = _selectedForGroup[i];
                  return Padding(
                    padding:
                        const EdgeInsets.only(right: 8),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(
                                      0xFF00A884)
                                  .withOpacity(0.15),
                              backgroundImage:
                                  u.photoUrl != null
                                      ? NetworkImage(
                                          u.photoUrl!)
                                      : null,
                              child: u.photoUrl == null
                                  ? Text(
                                      u.displayName
                                          .isNotEmpty
                                          ? u.displayName[0]
                                              .toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: Color(
                                              0xFF00A884),
                                          fontWeight:
                                              FontWeight
                                                  .bold))
                                  : null,
                            ),
                            Positioned(
                              right: -2,
                              top: -2,
                              child: GestureDetector(
                                onTap: () => setState(() =>
                                    _selectedForGroup
                                        .remove(u)),
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration:
                                      const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                      Icons.close,
                                      size: 12,
                                      color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          u.displayName.split(' ').first,
                          style: const TextStyle(
                              fontSize: 11),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Contacts to select
          Text('اختر أعضاء المجموعة من جهات الاتصال:',
              style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          if (_contactsLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                    color: Color(0xFF00A884)),
              ),
            )
          else if (_contacts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'أضف أشخاص كجهات اتصال أولاً\nلتتمكن من إنشاء مجموعة معهم',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 13),
                ),
              ),
            )
          else
            ...availableUsers.map((user) {
              final selected = _selectedForGroup
                  .any((u) => u.id == user.id);
              return CheckboxListTile(
                value: selected,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedForGroup.add(user);
                    } else {
                      _selectedForGroup
                          .removeWhere((u) => u.id == user.id);
                    }
                  });
                },
                activeColor: const Color(0xFF00A884),
                secondary: CircleAvatar(
                  backgroundColor:
                      const Color(0xFF00A884).withOpacity(0.15),
                  backgroundImage: user.photoUrl != null
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null
                      ? Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0]
                                  .toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Color(0xFF00A884),
                              fontWeight: FontWeight.bold))
                      : null,
                ),
                title: Text(user.displayName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600)),
                subtitle: Text(
                    user.status ?? user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
              );
            }),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: _creatingGroup
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2))
                  : const Icon(Icons.group_add),
              label: Text(
                  _creatingGroup
                      ? 'جاري الإنشاء...'
                      : 'إنشاء المجموعة (${_selectedForGroup.length} عضو)',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedForGroup.isEmpty ||
                        _groupNameCtrl.text.trim().isEmpty
                    ? Colors.grey
                    : const Color(0xFF00A884),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _creatingGroup ||
                      _selectedForGroup.isEmpty ||
                      _groupNameCtrl.text.trim().isEmpty
                  ? null
                  : _createGroup,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Contact Tile ─────────────────────────────────────────────────────────────
class _ContactTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;

  const _ContactTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor:
                const Color(0xFF00A884).withOpacity(0.15),
            backgroundImage: user.photoUrl != null
                ? NetworkImage(user.photoUrl!)
                : null,
            child: user.photoUrl == null
                ? Text(
                    user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Color(0xFF00A884),
                        fontWeight: FontWeight.bold,
                        fontSize: 18))
                : null,
          ),
          if (user.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(user.displayName,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(
        user.isOnline
            ? 'متصل الآن'
            : (user.status ?? user.email),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: user.isOnline
              ? const Color(0xFF25D366)
              : Colors.grey[500],
          fontSize: 13,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }
}
