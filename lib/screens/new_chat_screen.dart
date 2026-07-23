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
  final _ctrl = TextEditingController();
  List<UserModel> _results = [];
  bool _loading = false;
  final _selectedForGroup = <UserModel>[];
  final _groupNameCtrl = TextEditingController();
  final _groupDescCtrl = TextEditingController();
  String? _groupPhotoUrl;
  bool _creatingGroup = false;

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
    _groupDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await FirestoreService.searchUsers(q, widget.myUid);
      setState(() { _results = results; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _openDirectChat(UserModel user) async {
    setState(() => _loading = true);
    try {
      final conv = await FirestoreService.createDirectConversation(widget.myUid, user.id);
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => ChatScreen(conversation: conv, myUid: widget.myUid),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _createGroup() async {
    if (_groupNameCtrl.text.trim().isEmpty || _selectedForGroup.isEmpty) return;
    setState(() => _creatingGroup = true);
    try {
      final conv = await FirestoreService.createGroupConversation(
        myUid: widget.myUid,
        memberUids: _selectedForGroup.map((u) => u.id).toList(),
        name: _groupNameCtrl.text.trim(),
        photoUrl: _groupPhotoUrl,
        description: _groupDescCtrl.text.trim().isEmpty ? null : _groupDescCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => ChatScreen(conversation: conv, myUid: widget.myUid),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
    if (mounted) setState(() => _creatingGroup = false);
  }

  Future<void> _pickGroupPhoto() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (p == null) return;
    try {
      final bytes = await File(p.path).readAsBytes();
      final result = await ApiService.uploadFile(
        base64: 'data:image/jpeg;base64,${base64Encode(bytes)}',
        mimeType: 'image/jpeg',
        fileName: 'group_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      setState(() => _groupPhotoUrl = result['url'] as String?);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('محادثة جديدة'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'مباشرة'),
            Tab(text: 'مجموعة'),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // Direct chat tab
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _ctrl,
                  onChanged: _search,
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم أو البريد الإلكتروني...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF00A884)),
                    suffixIcon: _ctrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () { _ctrl.clear(); setState(() => _results = []); })
                        : null,
                    filled: true,
                    fillColor: Colors.grey.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                  ),
                ),
              ),
              if (_loading)
                const Center(child: CircularProgressIndicator(color: Color(0xFF00A884)))
              else if (_results.isEmpty && _ctrl.text.length >= 2)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('لا توجد نتائج', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  ),
                )
              else if (_results.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('ابحث عن شخص للتواصل معه', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                    itemBuilder: (ctx, i) {
                      final u = _results[i];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF00A884).withOpacity(0.2),
                          backgroundImage: u.photoUrl != null ? NetworkImage(u.photoUrl!) : null,
                          child: u.photoUrl == null
                              ? Text(u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold))
                              : null,
                        ),
                        title: Text(u.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(u.email, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (u.isOnline)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
                              ),
                            const Icon(Icons.chat_bubble_outline, color: Color(0xFF00A884), size: 20),
                          ],
                        ),
                        onTap: () => _openDirectChat(u),
                      );
                    },
                  ),
                ),
            ],
          ),

          // Group tab
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _ctrl,
                  onChanged: _search,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن أعضاء المجموعة...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF00A884)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.grey.withOpacity(0.1),
                  ),
                ),
              ),
              // Selected members chips
              if (_selectedForGroup.isNotEmpty)
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _selectedForGroup.map((u) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        avatar: CircleAvatar(
                          backgroundImage: u.photoUrl != null ? NetworkImage(u.photoUrl!) : null,
                          backgroundColor: const Color(0xFF00A884).withOpacity(0.2),
                          child: u.photoUrl == null
                              ? Text(u.displayName[0].toUpperCase(), style: const TextStyle(fontSize: 10))
                              : null,
                        ),
                        label: Text(u.displayName, style: const TextStyle(fontSize: 12)),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => setState(() => _selectedForGroup.remove(u)),
                        backgroundColor: const Color(0xFF00A884).withOpacity(0.1),
                      ),
                    )).toList(),
                  ),
                ),
              Expanded(
                child: _results.isEmpty
                    ? Center(child: Text('ابحث عن أعضاء للإضافة', style: TextStyle(color: Colors.grey[500])))
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                        itemBuilder: (ctx, i) {
                          final u = _results[i];
                          final selected = _selectedForGroup.contains(u);
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFF00A884).withOpacity(0.2),
                              backgroundImage: u.photoUrl != null ? NetworkImage(u.photoUrl!) : null,
                              child: u.photoUrl == null
                                  ? Text(u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : '?',
                                      style: const TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold))
                                  : null,
                            ),
                            title: Text(u.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(u.email),
                            trailing: selected
                                ? const Icon(Icons.check_circle, color: Color(0xFF00A884))
                                : const Icon(Icons.circle_outlined, color: Colors.grey),
                            onTap: () {
                              setState(() {
                                if (selected) _selectedForGroup.remove(u);
                                else _selectedForGroup.add(u);
                              });
                            },
                          );
                        },
                      ),
              ),
              if (_selectedForGroup.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Group photo
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _pickGroupPhoto,
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00A884).withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF00A884).withOpacity(0.3)),
                                image: _groupPhotoUrl != null
                                    ? DecorationImage(image: NetworkImage(_groupPhotoUrl!), fit: BoxFit.cover)
                                    : null,
                              ),
                              child: _groupPhotoUrl == null
                                  ? const Icon(Icons.camera_alt, color: Color(0xFF00A884))
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _groupNameCtrl,
                              decoration: const InputDecoration(
                                hintText: 'اسم المجموعة *',
                                prefixIcon: Icon(Icons.group, color: Color(0xFF00A884)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _groupDescCtrl,
                        decoration: const InputDecoration(
                          hintText: 'وصف المجموعة (اختياري)',
                          prefixIcon: Icon(Icons.info_outline, color: Color(0xFF00A884)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          icon: _creatingGroup
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.group_add),
                          label: Text('إنشاء مجموعة (${_selectedForGroup.length} أعضاء)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00A884),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _creatingGroup || _groupNameCtrl.text.trim().isEmpty ? null : _createGroup,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
