import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/status_model.dart';
import '../services/firestore_service.dart';
import '../services/api_service.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Status Screen (Main Tab)
// ──────────────────────────────────────────────────────────────────────────────
class StatusScreen extends StatefulWidget {
  final String myUid;
  final String myName;
  final String? myPhoto;

  const StatusScreen({super.key, required this.myUid, required this.myName, this.myPhoto});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  List<StatusModel> _myStatuses = [];
  final Map<String, List<StatusModel>> _othersStatuses = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    setState(() => _loading = true);
    try {
      _myStatuses = await FirestoreService.getMyStatuses(widget.myUid);
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RefreshIndicator(
      onRefresh: _loadStatuses,
      color: const Color(0xFF00A884),
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00A884)))
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                // My Status
                _buildMyStatus(isDark),
                // Divider
                if (_myStatuses.isNotEmpty || _othersStatuses.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'تحديثات أخيرة',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                // Others' statuses (demo with recent conversations participants)
                ..._buildOthersStatuses(isDark),
                // Empty state
                if (_othersStatuses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.circle_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          'لا توجد تحديثات حالة',
                          style: TextStyle(color: Colors.grey[500], fontSize: 15),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'حالات جهات اتصالك ستظهر هنا',
                          style: TextStyle(color: Colors.grey[400], fontSize: 13),
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
          ? () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ViewStatusScreen(
                  statuses: _myStatuses,
                  isMe: true,
                  myUid: widget.myUid,
                ),
              )).then((_) => _loadStatuses())
          : () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => CreateStatusScreen(
                  myUid: widget.myUid,
                  myName: widget.myName,
                  myPhoto: widget.myPhoto,
                ),
              )).then((_) => _loadStatuses()),
      child: Container(
        color: isDark ? const Color(0xFF1F2C34) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF00A884).withOpacity(0.2),
                  backgroundImage: widget.myPhoto != null ? NetworkImage(widget.myPhoto!) : null,
                  child: widget.myPhoto == null
                      ? Text(
                          widget.myName.isNotEmpty ? widget.myName[0].toUpperCase() : '؟',
                          style: const TextStyle(fontSize: 20, color: Color(0xFF00A884), fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                if (hasStatus)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _StatusRingPainter(
                        viewed: _myStatuses.every((s) => s.viewedBy.contains(widget.myUid)),
                        count: _myStatuses.length,
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
                      child: const Icon(Icons.add, color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('حالتي', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(
                    hasStatus
                        ? 'انقر لعرض حالتك — ${_myStatuses.length} تحديث'
                        : 'انقر لإضافة تحديث للحالة',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey[600]),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (v) {
                if (v == 'add') {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => CreateStatusScreen(
                      myUid: widget.myUid,
                      myName: widget.myName,
                      myPhoto: widget.myPhoto,
                    ),
                  )).then((_) => _loadStatuses());
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'add', child: Text('إضافة حالة')),
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
      if (statuses.isEmpty) return const SizedBox.shrink();
      final first = statuses.first;
      final allViewed = statuses.every((s) => s.viewedBy.contains(widget.myUid));
      return InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ViewStatusScreen(
            statuses: statuses,
            isMe: false,
            myUid: widget.myUid,
          ),
        )).then((_) => _loadStatuses()),
        child: Container(
          color: isDark ? const Color(0xFF1F2C34) : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundImage: first.userPhoto != null ? NetworkImage(first.userPhoto!) : null,
                    backgroundColor: const Color(0xFF00A884).withOpacity(0.2),
                    child: first.userPhoto == null
                        ? Text(first.userName.isNotEmpty ? first.userName[0].toUpperCase() : '?',
                            style: const TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold))
                        : null,
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _StatusRingPainter(viewed: allViewed, count: statuses.length),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(first.userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(
                      _timeAgo(first.createdAt),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
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

// Ring painter for status
class _StatusRingPainter extends CustomPainter {
  final bool viewed;
  final int count;
  _StatusRingPainter({required this.viewed, required this.count});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = viewed ? Colors.grey[400]! : const Color(0xFF00A884)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    if (count <= 1) {
      canvas.drawCircle(center, radius, paint);
    } else {
      final gap = 0.1;
      final segmentAngle = (2 * 3.14159 - count * gap) / count;
      for (int i = 0; i < count; i++) {
        final startAngle = -3.14159 / 2 + i * (segmentAngle + gap);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          segmentAngle,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StatusRingPainter old) => old.viewed != viewed || old.count != count;
}

// ──────────────────────────────────────────────────────────────────────────────
// Create Status Screen
// ──────────────────────────────────────────────────────────────────────────────
class CreateStatusScreen extends StatefulWidget {
  final String myUid;
  final String myName;
  final String? myPhoto;

  const CreateStatusScreen({super.key, required this.myUid, required this.myName, this.myPhoto});

  @override
  State<CreateStatusScreen> createState() => _CreateStatusScreenState();
}

class _CreateStatusScreenState extends State<CreateStatusScreen> {
  String _mode = 'text'; // 'text' | 'image'
  final _textCtrl = TextEditingController();
  Color _bgColor = const Color(0xFF00A884);
  XFile? _pickedImage;
  bool _uploading = false;
  final _uuid = const Uuid();

  final List<Color> _bgColors = [
    const Color(0xFF00A884),
    const Color(0xFF1877F2),
    const Color(0xFFE91E63),
    const Color(0xFF9C27B0),
    const Color(0xFFFF5722),
    const Color(0xFF607D8B),
    const Color(0xFF795548),
    const Color(0xFF212121),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _mode == 'text' ? _bgColor : Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_mode == 'text')
            TextButton(
              onPressed: _textCtrl.text.trim().isEmpty ? null : _publishText,
              child: const Text('نشر', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _mode == 'text' ? _buildTextMode() : _buildImageMode(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _modeButton(Icons.text_fields, 'نص', 'text'),
              const SizedBox(width: 16),
              _modeButton(Icons.photo_camera, 'صورة', 'image'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeButton(IconData icon, String label, String mode) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () async {
        if (mode == 'image') {
          final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
          if (img != null) {
            setState(() {
              _pickedImage = img;
              _mode = 'image';
            });
          }
        } else {
          setState(() => _mode = mode);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextMode() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: TextField(
                controller: _textCtrl,
                maxLines: null,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500),
                decoration: const InputDecoration(
                  hintText: 'اكتب تحديث حالتك...',
                  hintStyle: TextStyle(color: Colors.white54, fontSize: 22),
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
        ),
        // Color picker
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _bgColors.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final c = _bgColors[i];
              final selected = c == _bgColor;
              return GestureDetector(
                onTap: () => setState(() => _bgColor = c),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildImageMode() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_pickedImage != null)
          Image.file(File(_pickedImage!.path), fit: BoxFit.contain),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black45,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'أضف تعليقاً...',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
                _uploading
                    ? const CircularProgressIndicator(color: Color(0xFF00A884))
                    : IconButton(
                        icon: const Icon(Icons.send, color: Color(0xFF00A884), size: 30),
                        onPressed: _publishImage,
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _publishText() async {
    if (_textCtrl.text.trim().isEmpty) return;
    setState(() => _uploading = true);
    try {
      final now = DateTime.now();
      final status = StatusModel(
        id: _uuid.v4(),
        uid: widget.myUid,
        userName: widget.myName,
        userPhoto: widget.myPhoto,
        type: 'text',
        content: _textCtrl.text.trim(),
        backgroundColor: _bgColor.value.toRadixString(16),
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
        viewedBy: [],
      );
      await FirestoreService.createStatus(status);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _publishImage() async {
    if (_pickedImage == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await File(_pickedImage!.path).readAsBytes();
      final result = await ApiService.uploadFile(
        base64: 'data:image/jpeg;base64,${base64Encode(bytes)}',
        mimeType: 'image/jpeg',
        fileName: 'status_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final now = DateTime.now();
      final status = StatusModel(
        id: const Uuid().v4(),
        uid: widget.myUid,
        userName: widget.myName,
        userPhoto: widget.myPhoto,
        type: 'image',
        content: _textCtrl.text.trim().isEmpty ? null : _textCtrl.text.trim(),
        mediaUrl: result['url'] as String,
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
        viewedBy: [],
      );
      await FirestoreService.createStatus(status);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
    if (mounted) setState(() => _uploading = false);
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// View Status Screen
// ──────────────────────────────────────────────────────────────────────────────
class ViewStatusScreen extends StatefulWidget {
  final List<StatusModel> statuses;
  final bool isMe;
  final String myUid;

  const ViewStatusScreen({super.key, required this.statuses, required this.isMe, required this.myUid});

  @override
  State<ViewStatusScreen> createState() => _ViewStatusScreenState();
}

class _ViewStatusScreenState extends State<ViewStatusScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _progressCtrl;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _progressCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) _next();
    });
    _startCurrent();
  }

  void _startCurrent() {
    _progressCtrl.reset();
    _progressCtrl.forward();
    // Mark as viewed
    if (!widget.isMe) {
      FirestoreService.viewStatus(widget.statuses[_currentIndex].id, widget.myUid).ignore();
    }
  }

  void _next() {
    if (_currentIndex < widget.statuses.length - 1) {
      setState(() => _currentIndex++);
      _startCurrent();
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _startCurrent();
    }
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.statuses[_currentIndex];
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final w = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < w / 2) {
            _prev();
          } else {
            _next();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Content
            _buildContent(status),
            // Progress bars
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 8,
              child: Row(
                children: List.generate(widget.statuses.length, (i) {
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: i < _currentIndex
                            ? Container(color: Colors.white)
                            : i == _currentIndex
                                ? AnimatedBuilder(
                                    animation: _progressCtrl,
                                    builder: (_, __) => FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: _progressCtrl.value,
                                      child: Container(color: Colors.white),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Header
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: status.userPhoto != null ? NetworkImage(status.userPhoto!) : null,
                      backgroundColor: const Color(0xFF00A884),
                      child: status.userPhoto == null
                          ? Text(status.userName.isNotEmpty ? status.userName[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white))
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(status.userName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text(_timeAgo(status.createdAt),
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    if (widget.isMe)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.white),
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
      return Image.network(status.mediaUrl!, fit: BoxFit.contain, errorBuilder: (_, __, ___) =>
          const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 60)));
    } else if (status.type == 'text') {
      Color bgColor = const Color(0xFF00A884);
      if (status.backgroundColor != null) {
        try {
          bgColor = Color(int.parse('FF${status.backgroundColor!.toUpperCase()}', radix: 16));
        } catch (_) {}
      }
      return Container(
        color: bgColor,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(40),
        child: Text(
          status.content ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w500),
        ),
      );
    }
    return const Center(child: Icon(Icons.circle, color: Colors.white, size: 60));
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'أمس';
  }
}
