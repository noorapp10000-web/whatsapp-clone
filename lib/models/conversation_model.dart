import 'message_model.dart';

class ConversationModel {
  final int id;
  final String type;
  final String? name;
  final String? groupPhotoUrl;
  final DateTime lastMessageAt;
  final DateTime createdAt;
  final List<Map<String, dynamic>> participants;
  final MessageModel? lastMessage;
  final int unreadCount;

  ConversationModel({
    required this.id,
    required this.type,
    this.name,
    this.groupPhotoUrl,
    required this.lastMessageAt,
    required this.createdAt,
    required this.participants,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    // Handle both snake_case (from server) and camelCase keys
    final updatedAt = json['updated_at'] ?? json['updatedAt'] ?? json['created_at'] ?? json['createdAt'];
    final createdAt = json['created_at'] ?? json['createdAt'] ?? updatedAt;
    final lastMessageData = json['last_message'] ?? json['lastMessage'];
    final unreadCount = json['unread_count'] ?? json['unreadCount'] ?? 0;

    return ConversationModel(
      id: json['id'] as int,
      type: (json['type'] as String? ?? 'direct'),
      name: json['name'] as String?,
      groupPhotoUrl: (json['avatar_url'] ?? json['groupPhotoUrl']) as String?,
      lastMessageAt: DateTime.parse(updatedAt as String),
      createdAt: DateTime.parse(createdAt as String),
      participants: List<Map<String, dynamic>>.from(
          json['participants'] as List? ?? []),
      lastMessage: lastMessageData != null
          ? MessageModel.fromJson(
              lastMessageData as Map<String, dynamic>)
          : null,
      unreadCount: int.tryParse(unreadCount.toString()) ?? 0,
    );
  }

  String displayName(int myUserId) {
    if (type == 'group') return name ?? 'Group';
    final other = participants.firstWhere(
      (p) => (p['id'] ?? p['userId']) != myUserId,
      orElse: () => participants.isNotEmpty ? participants.first : {},
    );
    return (other['displayName'] ?? other['display_name'] ?? 'Unknown')
        as String;
  }

  String? displayPhoto(int myUserId) {
    if (type == 'group') return groupPhotoUrl;
    final other = participants.firstWhere(
      (p) => (p['id'] ?? p['userId']) != myUserId,
      orElse: () => <String, dynamic>{},
    );
    return (other['photoUrl'] ?? other['photo_url']) as String?;
  }

  bool isOtherOnline(int myUserId) {
    if (type == 'group') return false;
    final other = participants.firstWhere(
      (p) => (p['id'] ?? p['userId']) != myUserId,
      orElse: () => <String, dynamic>{},
    );
    return (other['isOnline'] ?? false) as bool;
  }
}
