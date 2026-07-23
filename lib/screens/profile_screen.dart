import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  final String myUid;
  const ProfileScreen({super.key, required this.myUid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _statusCtrl = TextEditingController();
  UserModel? _user;
  bool _loading = true;
  bool _saving = false;
  String? _newPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _loading = true);
    final user = await FirestoreService.getUser(widget.myUid);
    if (user != null && mounted) {
      setState(() {
        _user = user;
        _nameCtrl.text = user.displayName;
        _statusCtrl.text = user.status ?? 'مرحباً! أنا أستخدم WhatsApp Clone.';
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (p == null) return;
    setState(() => _saving = true);
    try {
      final bytes = await File(p.path).readAsBytes();
      final result = await ApiService.uploadFile(
        base64: 'data:image/jpeg;base64,${base64Encode(bytes)}',
        mimeType: 'image/jpeg',
        fileName: 'avatar_${widget.myUid}.jpg',
      );
      setState(() => _newPhotoUrl = result['url'] as String?);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _saveProfile() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ApiService.updateProfile(
        displayName: _nameCtrl.text.trim(),
        status: _statusCtrl.text.trim(),
        photoUrl: _newPhotoUrl,
      );
      await FirestoreService.updateUserProfile(
        widget.myUid,
        displayName: _nameCtrl.text.trim(),
        status: _statusCtrl.text.trim(),
        photoUrl: _newPhotoUrl,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم حفظ الملف الشخصي'), backgroundColor: Color(0xFF00A884)));
        _loadUser();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
    if (mounted) setState(() => _saving = false);
  }

  void _showQRCode() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('مشاركة ملفي الشخصي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: 'whatsapp-clone://user/${widget.myUid}',
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 12),
            Text(_user?.displayName ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('امسح الرمز للتواصل معي', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF00A884))));
    }

    final photoUrl = _newPhotoUrl ?? _user?.photoUrl;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: _showQRCode,
            tooltip: 'رمز QR',
          ),
          IconButton(
            icon: _saving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check),
            onPressed: _saving ? null : _saveProfile,
            tooltip: 'حفظ',
          ),
        ],
      ),
      body: ListView(
        children: [
          // Hero avatar
          Container(
            color: isDark ? const Color(0xFF1F2C34) : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Stack(
                    children: [
                      Hero(
                        tag: 'my_avatar',
                        child: CircleAvatar(
                          radius: 56,
                          backgroundColor: const Color(0xFF00A884).withOpacity(0.2),
                          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null
                              ? Text(
                                  (_user?.displayName ?? '?').isNotEmpty
                                      ? (_user?.displayName ?? '?')[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(color: Color(0xFF00A884), fontSize: 40, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00A884),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _user?.email ?? '',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Name field
          Container(
            color: isDark ? const Color(0xFF1F2C34) : Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('اسمك', style: TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  maxLength: 50,
                  decoration: const InputDecoration(
                    hintText: 'اسمك',
                    prefixIcon: Icon(Icons.person_outline, color: Color(0xFF00A884)),
                  ),
                ),
                Text(
                  'هذا الاسم سيظهر لجهات اتصالك',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Status field
          Container(
            color: isDark ? const Color(0xFF1F2C34) : Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('نص الحالة', style: TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: _statusCtrl,
                  maxLength: 139,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'اكتب حالتك...',
                    prefixIcon: Icon(Icons.info_outline, color: Color(0xFF00A884)),
                  ),
                ),
                // Quick status suggestions
                Wrap(
                  spacing: 8,
                  children: [
                    '📵 لا أتوفر',
                    '📚 في الدراسة',
                    '🏋️ في الرياضة',
                    '💤 نائم',
                    '💼 في العمل',
                  ].map((s) => GestureDetector(
                    onTap: () => setState(() => _statusCtrl.text = s),
                    child: Chip(
                      label: Text(s, style: const TextStyle(fontSize: 11)),
                      backgroundColor: const Color(0xFF00A884).withOpacity(0.1),
                      side: const BorderSide(color: Color(0xFF00A884), width: 0.5),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Account info
          Container(
            color: isDark ? const Color(0xFF1F2C34) : Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.email_outlined, color: Color(0xFF00A884)),
                  title: const Text('البريد الإلكتروني'),
                  subtitle: Text(_user?.email ?? ''),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.badge_outlined, color: Color(0xFF00A884)),
                  title: const Text('معرف المستخدم'),
                  subtitle: Text(widget.myUid, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                  trailing: const Icon(Icons.copy, size: 16, color: Colors.grey),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ المعرف')));
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // QR Code section
          GestureDetector(
            onTap: _showQRCode,
            child: Container(
              color: isDark ? const Color(0xFF1F2C34) : Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A884).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.qr_code, color: Color(0xFF00A884), size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('رمز QR', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        Text('شارك ملفك الشخصي عبر رمز QR', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: _saving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A884),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('حفظ التغييرات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
