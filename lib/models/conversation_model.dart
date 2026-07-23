import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final String type; // 'direct' | 'group' | 'broadcast'
  final String? name;
  final String? groupPhotoUrl;
  final String? description;
  final List<Map<String, dynamic>> participants;
  final List<String> participantIds;
  final List<String> adminIds;
  final String? lastMessage;
  final String? lastMessageType;
  final String? lastMessageSenderId;
  final DateTime lastMessageAt;
  final Map<String, int>? unreadCounts;
  final bool isArchived;
  final bool isMuted;
  final DateTime? mutedUntil;
  final int? disappearingSeconds;
  final String? wallpaper;
  final String? groupLink;
  final bool onlyAdminsCanMessage;
  final List<String> pinnedMessageIds;
  final String? draftText;
  final List<String> blockedBy;

  ConversationModel({
    required this.id,
    required this.type,
    this.name,
    this.groupPhotoUrl,
    this.description,
    required this.participants,
    required this.participantIds,
    this.adminIds = const [],
    this.lastMessage,
    this.lastMessageType,
    this.lastMessageSenderId,
    required this.lastMessageAt,
    this.unreadCounts,
    this.isArchived = false,
    this.isMuted = false,
    this.mutedUntil,
    this.disappearingSeconds,
    this.wallpaper,
    this.groupLink,
    this.onlyAdminsCanMessage = false,
    this.pinnedMessageIds = const [],
    this.draftText,
    this.blockedBy = const [],
  });

  bool isGroup() => type == 'group';
  bool isDirect() => type == 'direct';

  String displayName(String myUid) {
    if (type == 'group' || type == 'broadcast') return name ?? 'مجموعة';
    final other = otherParticipant(myUid);
    return (other['displayName'] ?? other['name'] ?? 'مجهول') as String;
  }

  String? displayPhoto(String myUid) {
    if (type == 'group' || type == 'broadcast') return groupPhotoUrl;
    final other = otherParticipant(myUid);
    return other['photoUrl'] as String?;
  }

  String otherUid(String myUid) =>
      participantIds.firstWhere((id) => id != myUid, orElse: () => '');

  Map<String, dynamic> otherParticipant(String myUid) =>
      participants.firstWhere(
        (p) => (p['uid'] ?? p['id'] ?? '') != myUid,
        orElse: () => <String, dynamic>{},
      );

  int unreadCount(String myUid) => unreadCounts?[myUid] ?? 0;

  bool isAdmin(String uid) => adminIds.contains(uid);

  bool isMutedNow() {
    if (!isMuted) return false;
    if (mutedUntil == null) return true;
    return DateTime.now().isBefore(mutedUntil!);
  }

  static DateTime _parseTs(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'direct',
      name: json['name'] as String?,
      groupPhotoUrl: json['groupPhotoUrl'] as String?,
      description: json['description'] as String?,
      participants: List<Map<String, dynamic>>.from(
          (json['participants'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map))),
      participantIds: List<String>.from(json['participantIds'] as List? ?? []),
      adminIds: List<String>.from(json['adminIds'] as List? ?? []),
      lastMessage: json['lastMessage'] as String?,
      lastMessageType: json['lastMessageType'] as String?,
      lastMessageSenderId: json['lastMessageSenderId'] as String?,
      lastMessageAt: _parseTs(json['lastMessageAt']),
      unreadCounts: json['unreadCounts'] != null
          ? Map<String, int>.from(
              (json['unreadCounts'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
          : null,
      isArchived: json['isArchived'] as bool? ?? false,
      isMuted: json['isMuted'] as bool? ?? false,
      mutedUntil: json['mutedUntil'] != null ? _parseTs(json['mutedUntil']) : null,
      disappearingSeconds: json['disappearingSeconds'] as int?,
      wallpaper: json['wallpaper'] as String?,
      groupLink: json['groupLink'] as String?,
      onlyAdminsCanMessage: json['onlyAdminsCanMessage'] as bool? ?? false,
      pinnedMessageIds: List<String>.from(json['pinnedMessageIds'] as List? ?? []),
      draftText: json['draftText'] as String?,
      blockedBy: List<String>.from(json['blockedBy'] as List? ?? []),
    );
  }
}
