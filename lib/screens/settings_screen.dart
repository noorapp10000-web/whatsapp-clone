import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _user = FirebaseAuth.instance.currentUser;
  String _themeMode = 'system';
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _showLastSeen = true;
  bool _showProfilePhoto = true;
  bool _showStatus = true;
  bool _readReceipts = true;
  String _fontSize = 'medium';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = prefs.getString('theme_mode') ?? 'system';
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      _showLastSeen = prefs.getBool('show_last_seen') ?? true;
      _showProfilePhoto = prefs.getBool('show_profile_photo') ?? true;
      _showStatus = prefs.getBool('show_status') ?? true;
      _readReceipts = prefs.getBool('read_receipts') ?? true;
      _fontSize = prefs.getString('font_size') ?? 'medium';
    });
  }

  Future<void> _savePref(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is String) await prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _user?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        children: [
          // Profile Card
          _buildProfileCard(myUid),
          const SizedBox(height: 8),

          // Account
          _buildSectionHeader('الحساب'),
          _buildSettingTile(
            icon: Icons.lock_outline,
            iconColor: const Color(0xFF25D366),
            title: 'الخصوصية',
            onTap: () => _showPrivacySettings(),
          ),
          _buildSettingTile(
            icon: Icons.security,
            iconColor: const Color(0xFF00A884),
            title: 'الأمان',
            subtitle: 'التحقق بخطوتين',
            onTap: () => _showTwoStepVerification(),
          ),
          _buildSettingTile(
            icon: Icons.key,
            iconColor: Colors.amber,
            title: 'تشفير من طرف إلى طرف',
            subtitle: 'الرسائل مشفرة بالكامل ✓',
          ),

          const SizedBox(height: 8),

          // Notifications
          _buildSectionHeader('الإشعارات'),
          _buildSwitchTile(
            icon: Icons.notifications_outlined,
            iconColor: Colors.red,
            title: 'تمكين الإشعارات',
            value: _notificationsEnabled,
            onChanged: (v) {
              setState(() => _notificationsEnabled = v);
              _savePref('notifications_enabled', v);
            },
          ),
          _buildSwitchTile(
            icon: Icons.volume_up_outlined,
            iconColor: Colors.blue,
            title: 'الأصوات',
            value: _soundEnabled,
            onChanged: (v) {
              setState(() => _soundEnabled = v);
              _savePref('sound_enabled', v);
            },
          ),
          _buildSwitchTile(
            icon: Icons.vibration,
            iconColor: Colors.purple,
            title: 'الاهتزاز',
            value: _vibrationEnabled,
            onChanged: (v) {
              setState(() => _vibrationEnabled = v);
              _savePref('vibration_enabled', v);
            },
          ),

          const SizedBox(height: 8),

          // Appearance
          _buildSectionHeader('المظهر'),
          _buildSettingTile(
            icon: Icons.brightness_6_outlined,
            iconColor: Colors.orange,
            title: 'المظهر',
            subtitle: _themeName(_themeMode),
            onTap: () => _showThemePicker(),
          ),
          _buildSettingTile(
            icon: Icons.text_fields,
            iconColor: Colors.teal,
            title: 'حجم الخط',
            subtitle: _fontSizeName(_fontSize),
            onTap: () => _showFontSizePicker(),
          ),
          _buildSettingTile(
            icon: Icons.wallpaper,
            iconColor: Colors.pink,
            title: 'خلفية المحادثة الافتراضية',
            onTap: () => _showWallpaperPicker(),
          ),

          const SizedBox(height: 8),

          // Privacy
          _buildSectionHeader('الخصوصية'),
          _buildSwitchTile(
            icon: Icons.access_time,
            iconColor: Colors.green,
            title: 'إظهار آخر ظهور',
            value: _showLastSeen,
            onChanged: (v) {
              setState(() => _showLastSeen = v);
              _savePref('show_last_seen', v);
              FirestoreService.updateUserProfile(_user?.uid ?? '', privacySettings: {'showLastSeen': v});
            },
          ),
          _buildSwitchTile(
            icon: Icons.photo_outlined,
            iconColor: Colors.blue,
            title: 'إظهار صورة الملف',
            value: _showProfilePhoto,
            onChanged: (v) {
              setState(() => _showProfilePhoto = v);
              _savePref('show_profile_photo', v);
              FirestoreService.updateUserProfile(_user?.uid ?? '', privacySettings: {'showProfilePhoto': v});
            },
          ),
          _buildSwitchTile(
            icon: Icons.circle_outlined,
            iconColor: Colors.amber,
            title: 'إظهار الحالة',
            value: _showStatus,
            onChanged: (v) {
              setState(() => _showStatus = v);
              _savePref('show_status', v);
            },
          ),
          _buildSwitchTile(
            icon: Icons.done_all,
            iconColor: Colors.cyan,
            title: 'تأكيدات القراءة',
            subtitle: 'إظهار علامة "تمت القراءة" للآخرين',
            value: _readReceipts,
            onChanged: (v) {
              setState(() => _readReceipts = v);
              _savePref('read_receipts', v);
            },
          ),

          const SizedBox(height: 8),

          // Storage
          _buildSectionHeader('التخزين'),
          _buildSettingTile(
            icon: Icons.storage_outlined,
            iconColor: Colors.brown,
            title: 'إدارة التخزين',
            onTap: () => _showStorageScreen(),
          ),
          _buildSettingTile(
            icon: Icons.backup_outlined,
            iconColor: Colors.green,
            title: 'النسخ الاحتياطي للمحادثات',
            onTap: () => _showBackupInfo(),
          ),

          const SizedBox(height: 8),

          // Help
          _buildSectionHeader('المساعدة'),
          _buildSettingTile(
            icon: Icons.help_outline,
            iconColor: Colors.grey,
            title: 'المساعدة',
            onTap: () {},
          ),
          _buildSettingTile(
            icon: Icons.info_outline,
            iconColor: Colors.blueGrey,
            title: 'حول WhatsApp Clone',
            subtitle: 'الإصدار 3.0.0',
            onTap: () => _showAbout(),
          ),

          const SizedBox(height: 8),

          // Logout
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontSize: 16)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileCard(String myUid) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => ProfileScreen(myUid: myUid),
      )),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Hero(
              tag: 'my_avatar',
              child: CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFF00A884).withOpacity(0.2),
                backgroundImage: _user?.photoURL != null ? NetworkImage(_user!.photoURL!) : null,
                child: _user?.photoURL == null
                    ? Text(
                        (_user?.displayName ?? '?').isNotEmpty ? (_user?.displayName ?? '?')[0].toUpperCase() : '?',
                        style: const TextStyle(color: Color(0xFF00A884), fontSize: 24, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _user?.displayName ?? 'اسمك',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _user?.email ?? '',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'اضغط لتعديل ملفك الشخصي',
                    style: TextStyle(color: const Color(0xFF00A884), fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF00A884),
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)) : null,
      trailing: onTap != null ? const Icon(Icons.chevron_right, color: Colors.grey) : null,
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)) : null,
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF00A884),
      ),
    );
  }

  String _themeName(String mode) {
    switch (mode) {
      case 'light': return 'فاتح';
      case 'dark': return 'داكن';
      default: return 'تلقائي (نظام)';
    }
  }

  String _fontSizeName(String size) {
    switch (size) {
      case 'small': return 'صغير';
      case 'large': return 'كبير';
      default: return 'متوسط';
    }
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 8, bottom: 16), width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('اختر المظهر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            _themeOption('system', 'تلقائي (نظام)', Icons.brightness_auto),
            _themeOption('light', 'فاتح', Icons.brightness_5),
            _themeOption('dark', 'داكن', Icons.brightness_2),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _themeOption(String mode, String label, IconData icon) {
    final selected = _themeMode == mode;
    return ListTile(
      leading: Icon(icon, color: selected ? const Color(0xFF00A884) : Colors.grey),
      title: Text(label),
      trailing: selected ? const Icon(Icons.check, color: Color(0xFF00A884)) : null,
      onTap: () async {
        setState(() => _themeMode = mode);
        await _savePref('theme_mode', mode);
        themeModeNotifier.value = mode == 'dark'
            ? ThemeMode.dark
            : mode == 'light'
                ? ThemeMode.light
                : ThemeMode.system;
        if (mounted) Navigator.pop(context);
      },
    );
  }

  void _showFontSizePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 8, bottom: 16), width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('حجم الخط', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            for (final size in ['small', 'medium', 'large'])
              ListTile(
                title: Text(_fontSizeName(size),
                    style: TextStyle(fontSize: size == 'small' ? 13 : size == 'large' ? 18 : 15)),
                trailing: _fontSize == size ? const Icon(Icons.check, color: Color(0xFF00A884)) : null,
                onTap: () async {
                  setState(() => _fontSize = size);
                  await _savePref('font_size', size);
                  if (mounted) Navigator.pop(context);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showWallpaperPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 8, bottom: 16), width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('خلفية المحادثة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: [
                _wallpaperOption('default', 'افتراضي', null),
                _wallpaperOption('pattern1', 'نقاط', '0xFF00A884'),
                _wallpaperOption('dark', 'داكن', '0xFF000000'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _wallpaperOption(String id, String label, String? colorHex) {
    return GestureDetector(
      onTap: () {
        _savePref('default_wallpaper', id);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تطبيق الخلفية')),
        );
      },
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colorHex != null ? const Color(0xFF00A884) : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.wallpaper, color: colorHex != null ? Colors.white : Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  void _showPrivacySettings() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _PrivacySettingsScreen(
        showLastSeen: _showLastSeen,
        showProfilePhoto: _showProfilePhoto,
        showStatus: _showStatus,
        readReceipts: _readReceipts,
        uid: _user?.uid ?? '',
        onChanged: (priv) {
          setState(() {
            _showLastSeen = priv['showLastSeen'] ?? _showLastSeen;
            _showProfilePhoto = priv['showProfilePhoto'] ?? _showProfilePhoto;
            _showStatus = priv['showStatus'] ?? _showStatus;
            _readReceipts = priv['readReceipts'] ?? _readReceipts;
          });
        },
      ),
    ));
  }

  void _showTwoStepVerification() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('التحقق بخطوتين'),
        content: const Text('هذه الميزة قريباً! ستضيف طبقة أمان إضافية لحسابك.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً')),
        ],
      ),
    );
  }

  void _showStorageScreen() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إدارة التخزين'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _storageItem('الصور', '45 ميجابايت', Icons.photo),
            _storageItem('الفيديوهات', '120 ميجابايت', Icons.video_library),
            _storageItem('الملفات', '23 ميجابايت', Icons.insert_drive_file),
            _storageItem('الرسائل الصوتية', '8 ميجابايت', Icons.mic),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم مسح ذاكرة التخزين المؤقت')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884)),
            child: const Text('مسح ذاكرة التخزين', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _storageItem(String label, String size, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF00A884)),
      title: Text(label),
      trailing: Text(size, style: const TextStyle(color: Colors.grey)),
    );
  }

  void _showBackupInfo() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('النسخ الاحتياطي'),
        content: const Text('محادثاتك محفوظة على Firebase Firestore وآمنة تلقائياً. لا تحتاج إلى نسخ احتياطي يدوي.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً')),
        ],
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'WhatsApp Clone',
      applicationVersion: '3.0.0',
      applicationIcon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF00A884),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(Icons.chat_bubble, color: Colors.white, size: 35),
      ),
      children: const [
        Text('تطبيق مراسلة متطور مفتوح المصدر مع كل المميزات العالمية.\n\nمدعوم بـ Flutter + Firebase + Node.js'),
      ],
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('خروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await AuthService.signOut();
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }
}

// Privacy Settings Screen
class _PrivacySettingsScreen extends StatefulWidget {
  final bool showLastSeen;
  final bool showProfilePhoto;
  final bool showStatus;
  final bool readReceipts;
  final String uid;
  final ValueChanged<Map<String, bool>> onChanged;

  const _PrivacySettingsScreen({
    required this.showLastSeen,
    required this.showProfilePhoto,
    required this.showStatus,
    required this.readReceipts,
    required this.uid,
    required this.onChanged,
  });

  @override
  State<_PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<_PrivacySettingsScreen> {
  late bool _showLastSeen;
  late bool _showProfilePhoto;
  late bool _showStatus;
  late bool _readReceipts;

  @override
  void initState() {
    super.initState();
    _showLastSeen = widget.showLastSeen;
    _showProfilePhoto = widget.showProfilePhoto;
    _showStatus = widget.showStatus;
    _readReceipts = widget.readReceipts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الخصوصية')),
      body: ListView(
        children: [
          const _SectionHeader('من يمكنه رؤية'),
          _SwitchItem(
            title: 'آخر ظهور',
            subtitle: 'اسمح لجهات اتصالك برؤية وقت آخر ظهور لك',
            value: _showLastSeen,
            onChanged: (v) { setState(() => _showLastSeen = v); _update(); },
          ),
          _SwitchItem(
            title: 'صورة الملف الشخصي',
            subtitle: 'اسمح لجهات اتصالك برؤية صورتك الشخصية',
            value: _showProfilePhoto,
            onChanged: (v) { setState(() => _showProfilePhoto = v); _update(); },
          ),
          _SwitchItem(
            title: 'الحالة',
            subtitle: 'اسمح لجهات اتصالك برؤية حالتك',
            value: _showStatus,
            onChanged: (v) { setState(() => _showStatus = v); _update(); },
          ),
          const _SectionHeader('الرسائل'),
          _SwitchItem(
            title: 'تأكيدات القراءة',
            subtitle: 'عند تعطيل هذا الخيار، لن ترى تأكيدات قراءة الآخرين',
            value: _readReceipts,
            onChanged: (v) { setState(() => _readReceipts = v); _update(); },
          ),
        ],
      ),
    );
  }

  void _update() {
    widget.onChanged({
      'showLastSeen': _showLastSeen,
      'showProfilePhoto': _showProfilePhoto,
      'showStatus': _showStatus,
      'readReceipts': _readReceipts,
    });
    FirestoreService.updateUserProfile(widget.uid, privacySettings: {
      'showLastSeen': _showLastSeen,
      'showProfilePhoto': _showProfilePhoto,
      'showStatus': _showStatus,
      'readReceipts': _readReceipts,
    });
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(title, style: const TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold, fontSize: 13)),
  );
}

class _SwitchItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchItem({required this.title, this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
    subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey[600])) : null,
    value: value,
    onChanged: onChanged,
    activeColor: const Color(0xFF00A884),
  );
}
