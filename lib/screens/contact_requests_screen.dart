import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import 'contact_info_screen.dart';
import 'chat_screen.dart';
import '../services/firestore_service.dart';

class ContactRequestsScreen extends StatefulWidget {
  final String myUid;
  const ContactRequestsScreen({super.key, required this.myUid});

  @override
  State<ContactRequestsScreen> createState() => _ContactRequestsScreenState();
}

class _ContactRequestsScreenState extends State<ContactRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات الاتصال'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFF00A884),
          labelColor: const Color(0xFF00A884),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.inbox), text: 'واردة'),
            Tab(icon: Icon(Icons.send), text: 'مُرسَلة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _IncomingRequests(myUid: widget.myUid),
          _SentRequests(myUid: widget.myUid),
        ],
      ),
    );
  }
}

// ─── Incoming Requests ────────────────────────────────────────────────────────
class _IncomingRequests extends StatelessWidget {
  final String myUid;
  const _IncomingRequests({required this.myUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('contactRequests')
          .where('toUid', isEqualTo: myUid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00A884)));
        }
        if (snap.hasError) {
          return Center(child: Text('خطأ: ${snap.error}'));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyState(
            icon: Icons.inbox_outlined,
            message: 'لا توجد طلبات واردة',
            subtitle: 'عندما يضيفك أحد ستظهر طلباته هنا',
          );
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final fromUid = data['fromUid'] as String? ?? '';
            return _IncomingTile(
              requestId: docs[i].id,
              fromUid: fromUid,
              myUid: myUid,
            );
          },
        );
      },
    );
  }
}

class _IncomingTile extends StatefulWidget {
  final String requestId;
  final String fromUid;
  final String myUid;

  const _IncomingTile({
    required this.requestId,
    required this.fromUid,
    required this.myUid,
  });

  @override
  State<_IncomingTile> createState() => _IncomingTileState();
}

class _IncomingTileState extends State<_IncomingTile> {
  UserModel? _user;
  bool _loading = true;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await FirestoreService.getUser(widget.fromUid);
    if (mounted) setState(() { _user = user; _loading = false; });
  }

  Future<void> _accept() async {
    setState(() => _actionLoading = true);
    try {
      await ApiService.acceptContactRequest(widget.fromUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ تم قبول طلب الاتصال'),
          backgroundColor: Color(0xFF00A884),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actionLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _reject() async {
    setState(() => _actionLoading = true);
    try {
      await ApiService.rejectContactRequest(widget.fromUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم رفض الطلب'),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actionLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ListTile(
        leading: CircleAvatar(child: Icon(Icons.person)),
        title: LinearProgressIndicator(),
      );
    }
    final user = _user;
    if (user == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ContactInfoScreen(
                  uid: user.id, myUid: widget.myUid),
              )),
              child: Stack(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF00A884).withOpacity(0.15),
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
                    right: 0, bottom: 0,
                    child: Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(user.status ?? user.email,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 10),
                  if (_actionLoading)
                    const Center(
                        child: SizedBox(height: 24, width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00A884))))
                  else
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _reject,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                          ),
                          child: const Text('رفض',
                              style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _accept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00A884),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                          ),
                          child: const Text('قبول', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                    ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sent Requests ────────────────────────────────────────────────────────────
class _SentRequests extends StatelessWidget {
  final String myUid;
  const _SentRequests({required this.myUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('contactRequests')
          .where('fromUid', isEqualTo: myUid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00A884)));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyState(
            icon: Icons.send_outlined,
            message: 'لا توجد طلبات مُرسَلة',
            subtitle: 'ابحث عن أشخاص وأضفهم من شاشة البحث',
          );
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final toUid = data['toUid'] as String? ?? '';
            return _SentTile(
              requestId: docs[i].id,
              toUid: toUid,
              myUid: myUid,
            );
          },
        );
      },
    );
  }
}

class _SentTile extends StatefulWidget {
  final String requestId;
  final String toUid;
  final String myUid;

  const _SentTile({
    required this.requestId,
    required this.toUid,
    required this.myUid,
  });

  @override
  State<_SentTile> createState() => _SentTileState();
}

class _SentTileState extends State<_SentTile> {
  UserModel? _user;
  bool _loading = true;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    FirestoreService.getUser(widget.toUid).then((u) {
      if (mounted) setState(() { _user = u; _loading = false; });
    });
  }

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      await ApiService.removeContact(widget.toUid);
    } catch (_) {}
    if (mounted) setState(() => _cancelling = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ListTile(
          leading: CircleAvatar(child: Icon(Icons.person)),
          title: LinearProgressIndicator());
    }
    final user = _user;
    if (user == null) return const SizedBox.shrink();

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: const Color(0xFF00A884).withOpacity(0.15),
        backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
        child: user.photoUrl == null
            ? Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                style: const TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold))
            : null,
      ),
      title: Text(user.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: const Text('في انتظار الرد...',
          style: TextStyle(color: Colors.orange, fontSize: 12)),
      trailing: _cancelling
          ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
          : TextButton(
              onPressed: _cancel,
              child: const Text('إلغاء', style: TextStyle(color: Colors.red, fontSize: 12)),
            ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subtitle;

  const _EmptyState({required this.icon, required this.message, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF00A884).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: const Color(0xFF00A884)),
          ),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ],
      ),
    );
  }
}
