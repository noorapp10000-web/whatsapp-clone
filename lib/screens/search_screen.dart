import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/conversation_model.dart';
import '../services/firestore_service.dart';
import 'chat_screen.dart';
import 'contact_info_screen.dart';

class SearchScreen extends StatefulWidget {
  final String myUid;
  final String query;

  const SearchScreen({super.key, required this.myUid, required this.query});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<UserModel> _users = [];
  List<ConversationModel> _convs = [];
  bool _loading = false;
  String _lastQuery = '';

  @override
  void didUpdateWidget(SearchScreen old) {
    super.didUpdateWidget(old);
    if (widget.query != old.query) _search(widget.query);
  }

  @override
  void initState() {
    super.initState();
    if (widget.query.isNotEmpty) _search(widget.query);
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() { _users = []; _convs = []; });
      return;
    }
    if (q == _lastQuery) return;
    _lastQuery = q;
    setState(() => _loading = true);
    try {
      final users = await FirestoreService.searchUsers(q, widget.myUid);
      setState(() { _users = users; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.trim().length < 2) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('ابحث عن أشخاص أو محادثات', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00A884)));
    }

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('لا توجد نتائج لـ "${widget.query}"',
                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
          ],
        ),
      );
    }

    return ListView(
      children: [
        if (_users.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('أشخاص', style: TextStyle(
              color: const Color(0xFF00A884),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            )),
          ),
          ..._users.map((user) => ListTile(
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF00A884).withOpacity(0.2),
              backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              child: user.photoUrl == null
                  ? Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold))
                  : null,
            ),
            title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (user.isOnline)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF25D366),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            onTap: () => _openChat(user),
          )),
        ],
      ],
    );
  }

  void _openChat(UserModel user) async {
    final conv = await FirestoreService.createDirectConversation(widget.myUid, user.id);
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(conversation: conv, myUid: widget.myUid),
      ));
    }
  }
}
