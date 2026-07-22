import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
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
          const SnackBar(content: Text('✅ Profile updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
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
        title: const Text('My Profile',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (!_loading && !_saving)
            TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00A884)))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Header
                  Container(
                    color: const Color(0xFF00A884),
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                    child: Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.white30,
                            backgroundImage: _user?.photoUrl != null
                                ? NetworkImage(_user!.photoUrl!)
                                : null,
                            child: _user?.photoUrl == null
                                ? Text(
                                    _user?.displayName.isNotEmpty == true
                                        ? _user!.displayName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _saving ? null : _updatePhoto,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 6)
                                  ],
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

                  // Fields
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('YOUR NAME',
                            style: TextStyle(
                                color: Color(0xFF00A884),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            hintText: 'Enter your name',
                            filled: true,
                            fillColor: const Color(0xFFF8F8F8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.person,
                                color: Color(0xFF00A884)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('ABOUT',
                            style: TextStyle(
                                color: Color(0xFF00A884),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _statusCtrl,
                          maxLength: 100,
                          decoration: InputDecoration(
                            hintText: 'e.g. Hey there! I am using WhatsApp Clone.',
                            filled: true,
                            fillColor: const Color(0xFFF8F8F8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.info_outline,
                                color: Color(0xFF00A884)),
                          ),
                        ),
                        if (_user?.email.isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          const Text('EMAIL',
                              style: TextStyle(
                                  color: Color(0xFF00A884),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F8F8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.email,
                                    color: Colors.grey, size: 20),
                                const SizedBox(width: 12),
                                Text(_user!.email,
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 15)),
                              ],
                            ),
                          ),
                        ],
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
                              child: const Text('Save Changes',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
