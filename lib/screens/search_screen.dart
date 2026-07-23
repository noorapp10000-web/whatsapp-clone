import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/conversation_model.dart';
import '../services/firestore_service.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';
import 'contact_info_screen.dart';

// Contact relationship status
enum _ContactStatus { none, sentPending, receivedPending, accepted }

class SearchScreen extends StatefulWidget {
  final String myUid;
  final String query;

  const SearchScreen({super.key, required this.myUid, required this.query});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<UserModel> _users = [];
  bool _loading = false;
  String _lastQuery = '';

  // Cache of contact statuses uid -> status
  final Map<String, _ContactStatus> _contactStatuses = {};
  final Map<String, bool> _actionLoading = {};

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
      setState(() {
        _users = [];
      });
      return;
    }
    if (q == _lastQuery) return;
    _lastQuery = q;
    setState(() => _loading = true);
    try {
      final users = await FirestoreService.searchUsers(q, widget.myUid);
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
      // Load contact statuses in background
      _loadContactStatuses(users);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadContactStatuses(List<UserModel> users) async {
    for (final user in users) {
      try {
        final res = await ApiService.getContactStatus(user.id);
        if (!mounted) return;
        final status = _parseStatus(res['status'] as String?, res['direction'] as String?);
        setState(() => _contactStatuses[user.id] = status);
      } catch (_) {}
    }
  }

  _ContactStatus _parseStatus(String? status, String? direction) {
    if (status == 'accepted') return _ContactStatus.accepted;
    if (status == 'pending' && direction == 'sent') return _ContactStatus.sentPending;
    if (status == 'pending' && direction == 'received') return _ContactStatus.receivedPending;
    return _ContactStatus.none;
  }

  Future<void> _sendRequest(UserModel user) async {
    setState(() => _actionLoading[user.id] = true);
    try {
      final res = await ApiService.sendContactRequest(user.id);
      final accepted = res['accepted'] == true;
      if (mounted) {
        setState(() {
          _contactStatuses[user.id] =
              accepted ? _ContactStatus.accepted : _ContactStatus.sentPending;
          _actionLoading[user.id] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(accepted ? '✅ تم إضافة جهة الاتصال' : '✅ تم إرسال طلب الإضافة'),
          backgroundColor: const Color(0xFF00A884),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actionLoading[user.id] = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _acceptRequest(UserModel user) async {
    setState(() => _actionLoading[user.id] = true);
    try {
      await ApiService.acceptContactRequest(user.id);
      if (mounted) {
        setState(() {
          _contactStatuses[user.id] = _ContactStatus.accepted;
          _actionLoading[user.id] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ تم قبول طلب الإضافة'),
          backgroundColor: Color(0xFF00A884),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actionLoading[user.id] = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
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
            Text('ابحث عن أشخاص',
                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
            const SizedBox(height: 8),
            Text('اكتب اسم الشخص أو بريده الإلكتروني',
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    }

    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF00A884)));
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
      padding: const EdgeInsets.only(top: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text('أشخاص',
              style: TextStyle(
                color: const Color(0xFF00A884),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              )),
        ),
        ..._users.map((user) => _UserTile(
              user: user,
              status: _contactStatuses[user.id] ?? _ContactStatus.none,
              actionLoading: _actionLoading[user.id] ?? false,
              onSendRequest: () => _sendRequest(user),
              onAcceptRequest: () => _acceptRequest(user),
              onOpenChat: () => _openChat(user),
              onViewProfile: () => _viewProfile(user),
            )),
      ],
    );
  }

  void _openChat(UserModel user) async {
    final conv =
        await FirestoreService.createDirectConversation(widget.myUid, user.id);
    if (mounted) {
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ChatScreen(conversation: conv, myUid: widget.myUid),
          ));
    }
  }

  void _viewProfile(UserModel user) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContactInfoScreen(
            uid: user.id,
            myUid: widget.myUid,
          ),
        ));
  }
}

// ─── User Tile ────────────────────────────────────────────────────────────────
class _UserTile extends StatelessWidget {
  final UserModel user;
  final _ContactStatus status;
  final bool actionLoading;
  final VoidCallback onSendRequest;
  final VoidCallback onAcceptRequest;
  final VoidCallback onOpenChat;
  final VoidCallback onViewProfile;

  const _UserTile({
    required this.user,
    required this.status,
    required this.actionLoading,
    required this.onSendRequest,
    required this.onAcceptRequest,
    required this.onOpenChat,
    required this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: GestureDetector(
        onTap: onViewProfile,
        child: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF00A884).withOpacity(0.15),
              backgroundImage:
                  user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
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
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
      title: Text(user.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(
        user.status ?? user.email,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      ),
      trailing: _buildTrailing(context),
      onTap: status == _ContactStatus.accepted ? onOpenChat : onViewProfile,
    );
  }

  Widget _buildTrailing(BuildContext context) {
    if (actionLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: Color(0xFF00A884)),
      );
    }

    switch (status) {
      case _ContactStatus.none:
        return _ActionButton(
          label: 'إضافة',
          icon: Icons.person_add_outlined,
          color: const Color(0xFF00A884),
          onTap: onSendRequest,
        );
      case _ContactStatus.sentPending:
        return _ActionButton(
          label: 'تم الإرسال',
          icon: Icons.schedule,
          color: Colors.orange,
          onTap: null,
        );
      case _ContactStatus.receivedPending:
        return _ActionButton(
          label: 'قبول',
          icon: Icons.check_circle_outline,
          color: Colors.blue,
          onTap: onAcceptRequest,
        );
      case _ContactStatus.accepted:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionButton(
              label: 'دردشة',
              icon: Icons.chat_bubble_outline,
              color: const Color(0xFF00A884),
              onTap: onOpenChat,
            ),
          ],
        );
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: onTap != null ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: onTap != null ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14, color: onTap != null ? color : Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: onTap != null ? color : Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
