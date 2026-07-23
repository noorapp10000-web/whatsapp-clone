import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  final String myUid;
  const ProfileScreen({super.key, required this.myUid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;
  bool _loading = true;
  bool _saving = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _statusCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _statusCtrl = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final user = await FirestoreService.getUser(widget.myUid);
    if (mounted && user != null) {
      setState(() {
        _user = user;
        _nameCtrl.text = user.displayName;
        _statusCtrl.text = user.status ?? '';
        _loading = false;
      });
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updatePhoto() async {
    final p = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (p == null) return;
    if (mounted) setState(() => _saving = true);
    try {
      final bytes = await File(p.path).readAsBytes();
      final result = await ApiService.uploadFile(
        base64: 'data:image/jpeg;base64,${base64Encode(bytes)}',
        mimeType: 'image/jpeg',
        fileName: 'avatar_${widget.myUid}.jpg',
      );
      await ApiService.updateProfile(photoUrl: result['url'] as String);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم تحديث الصورة الشخصية'),
            backgroundColor: Color(0xFF00A884),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ApiService.updateProfile(
        displayName: name,
        status: _statusCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ التغييرات'),
            backgroundColor: Color(0xFF00A884),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _statusCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00A884),
        foregroundColor: Colors.white,
        title: const Text('الملف الشخصي',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (!_loading && !_saving)
            TextButton(
              onPressed: _save,
              child: const Text('حفظ',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00A884)))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Header with avatar
                  Container(
                    color: const Color(0xFF00A884),
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                    child: Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 56,
                            backgroundColor: Colors.white,
                            backgroundImage: _user?.photoUrl != null
                                ? NetworkImage(_user!.photoUrl!)
                                : null,
                            child: _user?.photoUrl == null
                                ? Text(
                                    _user?.displayName.isNotEmpty == true
                                        ? _user!.displayName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF00A884)),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _updatePhoto,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt,
                                    color: Color(0xFF00A884), size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('الاسم'),
                        _field(
                          controller: _nameCtrl,
                          hint: 'اسمك الكامل',
                          icon: Icons.person,
                        ),
                        const SizedBox(height: 16),
                        _label('الحالة'),
                        _field(
                          controller: _statusCtrl,
                          hint: 'ما الذي يشغل بالك؟',
                          icon: Icons.info_outline,
                        ),
                        const SizedBox(height: 16),
                        _label('البريد الإلكتروني'),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.email,
                                  color: Colors.grey, size: 20),
                              const SizedBox(width: 12),
                              Text(_user?.email ?? '',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 15)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (_saving)
                          const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF00A884)))
                        else
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00A884),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('حفظ التغييرات',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFF00A884),
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      );

  Widget _field(
      {required TextEditingController controller,
      required String hint,
      required IconData icon}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: Icon(icon, color: const Color(0xFF00A884), size: 20),
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF00A884), width: 1.5),
        ),
      ),
    );
  }
}
