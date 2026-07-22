import 'message_model.dart';

class ConversationModel {
  final String id;
  final String type;
  final String? name;
  final String? groupPhotoUrl;
  final List<String> participantIds;
  final List<Map<String, dynamic>> participants;
  final DateTime lastMessageAt;
  final DateTime createdAt;
  final MessageModel? lastMessage;
  final int unreadCount;

  ConversationModel({
    required this.id,
    required this.type,
    this.name,
    this.groupPhotoUrl,
    required this.participantIds,
    required this.participants,
    required this.lastMessageAt,
    required this.createdAt,
    this.lastMessage,
    this.unreadCount = 0,
  });

  static DateTime _ts(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    try { return (v as dynamic).toDate() as DateTime; } catch (_) { return DateTime.now(); }
  }

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final lastMsgRaw = json['lastMessage'] ?? json['last_message'];
    return ConversationModel(
      id: (json['id'] ?? '') as String,
      type: (json['type'] as String? ?? 'direct'),
      name: json['name'] as String?,
      groupPhotoUrl: (json['groupPhotoUrl'] ?? json['avatar_url']) as String?,
      participantIds: List<String>.from(json['participantIds'] ?? json['participant_ids'] ?? []),
      participants: List<Map<String, dynamic>>.from(json['participants'] ?? []),
      lastMessageAt: _ts(json['lastMessageAt'] ?? json['updated_at']),
      createdAt: _ts(json['createdAt'] ?? json['created_at']),
      lastMessage: lastMsgRaw != null
          ? MessageModel.fromJson(lastMsgRaw as Map<String, dynamic>)
          : null,
      unreadCount: int.tryParse((json['unreadCount'] ?? json['unread_count'] ?? 0).toString()) ?? 0,
    );
  }

  String displayName(String myUid) {
    if (type == 'group') return name ?? 'Group';
    final other = participants.firstWhere(
      (p) => (p['uid'] ?? p['id'] ?? '') != myUid,
      orElse: () => participants.isNotEmpty ? participants.first : {},
    );
    return (other['displayName'] ?? other['display_name'] ?? 'Unknown') as String;
  }

  String? displayPhoto(String myUid) {
    if (type == 'group') return groupPhotoUrl;
    final other = participants.firstWhere(
      (p) => (p['uid'] ?? p['id'] ?? '') != myUid,
      orElse: () => <String, dynamic>{},
    );
    return (other['photoUrl'] ?? other['photo_url']) as String?;
  }

  String otherUid(String myUid) =>
      participantIds.firstWhere((id) => id != myUid, orElse: () => '');

  Map<String, dynamic> otherParticipant(String myUid) =>
      participants.firstWhere(
        (p) => (p['uid'] ?? p['id'] ?? '') != myUid,
        orElse: () => <String, dynamic>{},
      );
}
