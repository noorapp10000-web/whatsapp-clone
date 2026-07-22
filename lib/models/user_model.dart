class UserModel {
  final String id;
  final String firebaseUid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? status;
  final bool isOnline;
  final DateTime? lastSeen;

  UserModel({
    required this.id,
    required this.firebaseUid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.status,
    this.isOnline = false,
    this.lastSeen,
  });

  static DateTime? _ts(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
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
    );
  }
}
