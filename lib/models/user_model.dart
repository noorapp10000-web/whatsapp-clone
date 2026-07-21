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

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        firebaseUid: json['firebaseUid'] ?? '',
        email: json['email'] ?? '',
        displayName: json['displayName'] ?? '',
        photoUrl: json['photoUrl'],
        status: json['status'],
        isOnline: json['isOnline'] ?? false,
        lastSeen:
            json['lastSeen'] != null ? DateTime.parse(json['lastSeen']) : null,
      );
}
