class UserModel {
  final int id;
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

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Handle both snake_case (from server) and camelCase keys
    final firebaseUid = json['firebase_uid'] ?? json['firebaseUid'] ?? '';
    final displayName = json['display_name'] ?? json['displayName'] ?? '';
    final photoUrl = json['photo_url'] ?? json['photoUrl'];
    final lastSeen = json['last_seen'] ?? json['lastSeen'];

    return UserModel(
      id: json['id'] as int,
      firebaseUid: firebaseUid as String,
      email: (json['email'] as String? ?? ''),
      displayName: displayName as String,
      photoUrl: photoUrl as String?,
      status: json['status'] as String?,
      isOnline: (json['isOnline'] ?? json['is_online'] ?? false) as bool,
      lastSeen: lastSeen != null
          ? DateTime.tryParse(lastSeen as String)
          : null,
    );
  }
}
