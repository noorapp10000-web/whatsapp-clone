import 'package:cloud_firestore/cloud_firestore.dart';

class StatusModel {
  final String id;
  final String uid;
  final String userName;
  final String? userPhoto;
  final String type; // 'text' | 'image' | 'video'
  final String? content; // text content or caption
  final String? mediaUrl;
  final String? backgroundColor; // for text statuses
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> viewedBy;
  final Map<String, String> reactions; // uid → emoji

  StatusModel({
    required this.id,
    required this.uid,
    required this.userName,
    this.userPhoto,
    required this.type,
    this.content,
    this.mediaUrl,
    this.backgroundColor,
    required this.createdAt,
    required this.expiresAt,
    this.viewedBy = const [],
    this.reactions = const {},
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory StatusModel.fromJson(Map<String, dynamic> json) {
    DateTime parseTs(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return StatusModel(
      id: json['id'] as String? ?? '',
      uid: json['uid'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      userPhoto: json['userPhoto'] as String?,
      type: json['type'] as String? ?? 'text',
      content: json['content'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      backgroundColor: json['backgroundColor'] as String?,
      createdAt: parseTs(json['createdAt']),
      expiresAt: parseTs(json['expiresAt']),
      viewedBy: List<String>.from(json['viewedBy'] as List? ?? []),
      reactions: Map<String, String>.from(json['reactions'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'userName': userName,
        if (userPhoto != null) 'userPhoto': userPhoto,
        'type': type,
        if (content != null) 'content': content,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (backgroundColor != null) 'backgroundColor': backgroundColor,
        'createdAt': Timestamp.fromDate(createdAt),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'viewedBy': viewedBy,
        'reactions': reactions,
      };
}

class UserStatuses {
  final String uid;
  final String userName;
  final String? userPhoto;
  final List<StatusModel> statuses;

  UserStatuses({
    required this.uid,
    required this.userName,
    this.userPhoto,
    required this.statuses,
  });

  bool get hasUnviewed => statuses.any((s) => !s.viewedBy.contains(uid));
  StatusModel get latest => statuses.last;
}
