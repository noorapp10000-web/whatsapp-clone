import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String firebaseUid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? status;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? phone;
  final Map<String, dynamic>? privacySettings;
  final List<String> blockedUsers;

  UserModel({
    required this.id,
    required this.firebaseUid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.status,
    this.isOnline = false,
    this.lastSeen,
    this.phone,
    this.privacySettings,
    this.blockedUsers = const [],
  });

  static DateTime? _ts(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    if (v is Timestamp) return v.toDate();
    try { return (v as dynamic).toDate() as DateTime; } catch (_) { return null; }
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final uid = (json['uid'] ?? json['id'] ?? '') as String;
    return UserModel(
      id: uid,
      firebaseUid: uid,
      email: (json['email'] as String? ?? ''),
      displayName: (json['displayName'] ?? json['display_name'] ?? '') as String,
      photoUrl: (json['photoUrl'] ?? json['photo_url']) as String?,
      status: json['status'] as String?,
      isOnline: (json['isOnline'] ?? json['is_online'] ?? false) as bool,
      lastSeen: _ts(json['lastSeen'] ?? json['last_seen']),
      phone: json['phone'] as String?,
      privacySettings: json['privacySettings'] as Map<String, dynamic>?,
      blockedUsers: List<String>.from(json['blockedUsers'] as List? ?? []),
    );
  }

  bool get showLastSeen => privacySettings?['showLastSeen'] as bool? ?? true;
  bool get showProfilePhoto => privacySettings?['showProfilePhoto'] as bool? ?? true;
  bool get showStatus => privacySettings?['showStatus'] as bool? ?? true;
}
