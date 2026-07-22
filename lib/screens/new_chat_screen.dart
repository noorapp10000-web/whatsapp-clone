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

class _NewChatScreenState extends State<NewChatScreen> {
  final _ctrl = TextEditingController();
  List<UserModel> _results = [];
  bool _loading = false;

  Future<void> _search(String q) async {
    if (q.trim().length < 2) { setState(() => _results = []); return; }
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
      final conv = await FirestoreService.createDirectConversation(widget.myUid, user.id);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversation: conv, myUid: widget.myUid),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00A884),
        title: const Text('New Chat',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _ctrl,
            onChanged: _search,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search by name or email…',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF00A884)),
              filled: true, fillColor: const Color(0xFFF0F0F0),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF00A884))))
                  : null,
            ),
          ),
        ),
        Expanded(
          child: _results.isEmpty && !_loading
              ? Center(
                  child: Text(
                    _ctrl.text.length < 2
                        ? 'Type at least 2 characters to search'
                        : 'No users found',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final u = _results[i];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF00A884),
                        backgroundImage: u.photoUrl != null ? NetworkImage(u.photoUrl!) : null,
                        child: u.photoUrl == null
                            ? Text(u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontSize: 18))
                            : null,
                      ),
                      title: Text(u.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(u.email,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      onTap: () => _openChat(u),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
