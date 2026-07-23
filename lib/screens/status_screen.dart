import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/status_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/api_service.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Status Screen (Main Tab)
// ──────────────────────────────────────────────────────────────────────────────
class StatusScreen extends StatefulWidget {
  final String myUid;
  final String myName;
  final String? myPhoto;

  const StatusScreen(
      {super.key,
      required this.myUid,
      required this.myName,
      this.myPhoto});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  List<StatusModel> _myStatuses = [];
  // contactUid -> statuses list
  final Map<String, List<StatusModel>> _othersStatuses = {};
  final Map<String, UserModel> _contactUsers = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    setState(() => _loading = true);
    try {
      // Load my statuses
      _myStatuses = await FirestoreService.getMyStatuses(widget.myUid);

      // Load contacts' statuses
      await _loadContactsStatuses();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadContactsStatuses() async {
    try {
      final res = await ApiService.getContacts();
      final contactsList =
          List<Map<String, dynamic>>.from((res['contacts'] as List?) ?? []);

      final newStatuses = <String, List<StatusModel>>{};
      final newUsers = <String, UserModel>{};

      for (final contactData in contactsList) {
        final user = UserModel.fromJson(contactData);
        final statuses = await FirestoreService.getUserStatuses(user.id);
        if (statuses.isNotEmpty) {
          newStatuses[user.id] = statuses;
          newUsers[user.id] = user;
        }
      }

      if (mounted) {
        setState(() {
          _othersStatuses
            ..clear()
            ..addAll(newStatuses);
          _contactUsers
            ..clear()
            ..addAll(newUsers);
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RefreshIndicator(
      onRefresh: _loadStatuses,
      color: const Color(0xFF00A884),
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00A884)))
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                // My Status
                _buildMyStatus(isDark),

                // Others' recent statuses
                if (_othersStatuses.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text(
                      'تحديثات أخيرة',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ..._buildOthersStatuses(isDark),
                ],

                // Empty contacts state
                if (_othersStatuses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF00A884).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.circle_outlined,
                              size: 40, color: Color(0xFF00A884)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد تحديثات حالة',
                          style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'حالات جهات اتصالك ستظهر هنا\nأضف أشخاص من البحث لترى حالاتهم',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildMyStatus(bool isDark) {
    final hasStatus = _myStatuses.isNotEmpty;
    return InkWell(
      onTap: hasStatus
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ViewStatusScreen(
                    statuses: _myStatuses,
                    isMe: true,
                    myUid: widget.myUid,
                  ),
                ),
              ).then((_) => _loadStatuses())
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateStatusScreen(
                    myUid: widget.myUid,
                    myName: widget.myName,
                    myPhoto: widget.myPhoto,
                  ),
                ),
              ).then((_) => _loadStatuses()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      const Color(0xFF00A884).withOpacity(0.15),
                  backgroundImage: widget.myPhoto != null
                      ? NetworkImage(widget.myPhoto!)
                      : null,
                  child: widget.myPhoto == null
                      ? Text(
                          widget.myName.isNotEmpty
                              ? widget.myName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00A884)),
                        )
                      : null,
                ),
                if (hasStatus)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF00A884), width: 2.5),
                      ),
                    ),
                  ),
                if (!hasStatus)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00A884),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add,
                          size: 14, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('حالتي',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    hasStatus
                        ? 'اضغط لعرض حالتك'
                        : 'اضغط لإضافة تحديث حالة',
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              onSelected: (v) {
                if (v == 'add') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateStatusScreen(
                        myUid: widget.myUid,
                        myName: widget.myName,
                        myPhoto: widget.myPhoto,
                      ),
                    ),
                  ).then((_) => _loadStatuses());
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'add',
                    child: Row(children: [
                      Icon(Icons.add_circle_outline,
                          color: Color(0xFF00A884)),
                      SizedBox(width: 8),
                      Text('إضافة حالة'),
                    ])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOthersStatuses(bool isDark) {
    return _othersStatuses.entries.map((entry) {
      final uid = entry.key;
      final statuses = entry.value;
      final user = _contactUsers[uid];
      if (user == null) return const SizedBox.shrink();
      final latest = statuses.first;
      final allViewed = statuses.every((s) => s.viewedBy.contains(widget.myUid));

      return InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViewStatusScreen(
              statuses: statuses,
              isMe: false,
              myUid: widget.myUid,
            ),
          ),
        ).then((_) => _loadStatuses()),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: allViewed
                        ? Colors.grey.shade400
                        : const Color(0xFF00A884),
                    width: 2.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: CircleAvatar(
                    radius: 25,
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
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00A884)))
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      _timeAgo(latest.createdAt),
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'أمس';
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Create Status Screen
// ──────────────────────────────────────────────────────────────────────────────
class CreateStatusScreen extends StatefulWidget {
  final String myUid;
  final String myName;
  final String? myPhoto;

  const CreateStatusScreen(
      {super.key,
      required this.myUid,
      required this.myName,
      this.myPhoto});

  @override
  State<CreateStatusScreen> createState() => _CreateStatusScreenState();
}

class _CreateStatusScreenState extends State<CreateStatusScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _textCtrl = TextEditingController();
  Color _bgColor = const Color(0xFF00A884);
  bool _uploading = false;

  static const _bgColors = [
    Color(0xFF00A884),
    Color(0xFF1A237E),
    Color(0xFFB71C1C),
    Color(0xFF1B5E20),
    Color(0xFF4A148C),
    Color(0xFFE65100),
    Color(0xFF880E4F),
    Color(0xFF006064),
    Color(0xFF37474F),
    Color(0xFF212121),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _postTextStatus() async {
    if (_textCtrl.text.trim().isEmpty) return;
    setState(() => _uploading = true);
    try {
      final colorHex =
          _bgColor.value.toRadixString(16).substring(2).toUpperCase();
      await FirestoreService.createStatusFromParams(
        uid: widget.myUid,
        userName: widget.myName,
        userPhoto: widget.myPhoto,
        type: 'text',
        content: _textCtrl.text.trim(),
        backgroundColor: colorHex,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ تم نشر الحالة'),
          backgroundColor: Color(0xFF00A884),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _pickAndPostImageStatus() async {
    final p = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (p == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await File(p.path).readAsBytes();
      final result = await ApiService.uploadFile(
        base64: 'data:image/jpeg;base64,${base64Encode(bytes)}',
        mimeType: 'image/jpeg',
        fileName: 'status_${const Uuid().v4()}.jpg',
      );
      final url = result['url'] as String?;
      if (url == null) throw Exception('Upload failed');
      await FirestoreService.createStatusFromParams(
        uid: widget.myUid,
        userName: widget.myName,
        userPhoto: widget.myPhoto,
        type: 'image',
        mediaUrl: url,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ تم نشر الحالة'),
          backgroundColor: Color(0xFF00A884),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة حالة'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFF00A884),
          labelColor: const Color(0xFF00A884),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.text_fields), text: 'نص'),
            Tab(icon: Icon(Icons.image), text: 'صورة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildTextTab(),
          _buildImageTab(),
        ],
      ),
    );
  }

  Widget _buildTextTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            height: 250,
            width: double.infinity,
            color: _bgColor,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(32),
            child: Text(
              _textCtrl.text.isEmpty ? 'معاينة النص هنا...' : _textCtrl.text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _textCtrl,
              maxLines: 4,
              maxLength: 700,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'اكتب حالتك...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF00A884), width: 2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _bgColors
                  .map((c) => GestureDetector(
                        onTap: () => setState(() => _bgColor = c),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _bgColor == c
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4)
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: _uploading ? null : _postTextStatus,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              label: Text(_uploading ? 'جاري النشر...' : 'نشر الحالة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A884),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildImageTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF00A884).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_photo_alternate,
                size: 50, color: Color(0xFF00A884)),
          ),
          const SizedBox(height: 20),
          const Text('اختر صورة من المعرض',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('ستُنشر الصورة كحالة لمدة 24 ساعة',
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(height: 24),
          _uploading
              ? const CircularProgressIndicator(color: Color(0xFF00A884))
              : ElevatedButton.icon(
                  onPressed: _pickAndPostImageStatus,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('اختر من المعرض'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A884),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                  ),
                ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// View Status Screen
// ──────────────────────────────────────────────────────────────────────────────
class ViewStatusScreen extends StatefulWidget {
  final List<StatusModel> statuses;
  final bool isMe;
  final String myUid;

  const ViewStatusScreen(
      {super.key,
      required this.statuses,
      required this.isMe,
      required this.myUid});

  @override
  State<ViewStatusScreen> createState() => _ViewStatusScreenState();
}

class _ViewStatusScreenState extends State<ViewStatusScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  int _current = 0;
  static const _duration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: _duration)
      ..forward()
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          if (_current < widget.statuses.length - 1) {
            setState(() {
              _current++;
              _anim
                ..reset()
                ..forward();
            });
          } else {
            if (mounted) Navigator.pop(context);
          }
        }
      });
    _markViewed();
  }

  void _markViewed() {
    final status = widget.statuses[_current];
    if (!status.viewedBy.contains(widget.myUid)) {
      FirestoreService.markStatusViewed(status.id, widget.myUid).ignore();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _prev() {
    if (_current > 0) {
      setState(() {
        _current--;
        _anim
          ..reset()
          ..forward();
      });
      _markViewed();
    }
  }

  void _next() {
    if (_current < widget.statuses.length - 1) {
      setState(() {
        _current++;
        _anim
          ..reset()
          ..forward();
      });
      _markViewed();
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.statuses[_current];
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (d) {
          final x = d.globalPosition.dx;
          final w = MediaQuery.of(context).size.width;
          if (x < w / 2) {
            _prev();
          } else {
            _next();
          }
        },
        child: Stack(
          children: [
            // Content
            Positioned.fill(child: _buildContent(status)),
            // Progress bars
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 8,
              child: Row(
                children: List.generate(widget.statuses.length, (i) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 2,
                      child: i < _current
                          ? Container(color: Colors.white)
                          : i == _current
                              ? AnimatedBuilder(
                                  animation: _anim,
                                  builder: (_, __) => LinearProgressIndicator(
                                    value: _anim.value,
                                    backgroundColor:
                                        Colors.white.withOpacity(0.3),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                    minHeight: 2,
                                  ),
                                )
                              : Container(
                                  color: Colors.white.withOpacity(0.3)),
                    ),
                  );
                }),
              ),
            ),
            // Top bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    if (widget.isMe)
                      IconButton(
                        icon:
                            const Icon(Icons.delete, color: Colors.white),
                        onPressed: () async {
                          await FirestoreService.deleteStatus(status.id);
                          if (mounted) Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(StatusModel status) {
    if (status.type == 'image' && status.mediaUrl != null) {
      return Image.network(
        status.mediaUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image,
                color: Colors.white, size: 60)),
      );
    } else if (status.type == 'text') {
      Color bgColor = const Color(0xFF00A884);
      if (status.backgroundColor != null) {
        try {
          bgColor = Color(int.parse(
              'FF${status.backgroundColor!.toUpperCase()}',
              radix: 16));
        } catch (_) {}
      }
      return Container(
        color: bgColor,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(40),
        child: Text(
          status.content ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w500),
        ),
      );
    }
    return const Center(
        child: Icon(Icons.circle, color: Colors.white, size: 60));
  }
}
