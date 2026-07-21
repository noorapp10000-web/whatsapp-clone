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

  factory ConversationModel.fromJson(Map<String, dynamic> json) =>
      ConversationModel(
        id: json['id'],
        type: json['type'] ?? 'private',
        name: json['name'],
        groupPhotoUrl: json['groupPhotoUrl'],
        lastMessageAt: DateTime.parse(json['lastMessageAt']),
        createdAt: DateTime.parse(json['createdAt']),
        participants: List<Map<String, dynamic>>.from(json['participants'] ?? []),
        lastMessage: json['lastMessage'] != null
            ? MessageModel.fromJson(json['lastMessage'])
            : null,
        unreadCount: json['unreadCount'] ?? 0,
      );

  String displayName(int myUserId) {
    if (type == 'group') return name ?? 'Group';
    final other = participants.firstWhere(
      (p) => p['userId'] != myUserId,
      orElse: () => participants.isNotEmpty ? participants.first : {},
    );
    return other['displayName'] ?? 'Unknown';
  }

  String? displayPhoto(int myUserId) {
    if (type == 'group') return groupPhotoUrl;
    final other = participants.firstWhere(
      (p) => p['userId'] != myUserId,
      orElse: () => <String, dynamic>{},
    );
    return other['photoUrl'];
  }

  bool isOtherOnline(int myUserId) {
    if (type == 'group') return false;
    final other = participants.firstWhere(
      (p) => p['userId'] != myUserId,
      orElse: () => <String, dynamic>{},
    );
    return other['isOnline'] ?? false;
  }
}
