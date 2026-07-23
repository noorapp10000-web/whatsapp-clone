import 'package:cloud_firestore/cloud_firestore.dart';
import 'poll_model.dart';

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String? senderName;
  final String? senderPhoto;
  final String type; // text|image|video|audio|file|listen_together|poll|location|contact|system
  final String? text;
  final String? fileUrl;
  final String? fileName;
  final String? mimeType;
  final int? fileSize;
  final String? sessionId;
  final String? replyToId;
  final String? replyToText;
  final String? replyToSender;
  final DateTime createdAt;
  final Map<String, dynamic>? readBy;
  final bool deleted;
  final bool isEdited;
  final String? editedText;
  final Map<String, String>? reactions;
  final bool isStarred;
  final bool isPinned;
  final String? forwardedFrom;
  final int? disappearAfterSeconds;
  final PollModel? poll;
  final Map<String, dynamic>? location; // {lat, lng, address}
  final Map<String, dynamic>? contact; // {name, phone, email}
  final String? thumbnailUrl;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.senderName,
    this.senderPhoto,
    required this.type,
    this.text,
    this.fileUrl,
    this.fileName,
    this.mimeType,
    this.fileSize,
    this.sessionId,
    this.replyToId,
    this.replyToText,
    this.replyToSender,
    required this.createdAt,
    this.readBy,
    this.deleted = false,
    this.isEdited = false,
    this.editedText,
    this.reactions,
    this.isStarred = false,
    this.isPinned = false,
    this.forwardedFrom,
    this.disappearAfterSeconds,
    this.poll,
    this.location,
    this.contact,
    this.thumbnailUrl,
  });

  String get displayText {
    if (deleted) return '🚫 تم حذف هذه الرسالة';
    if (isEdited && editedText != null) return editedText!;
    if (text != null) return text!;
    switch (type) {
      case 'image': return '📷 صورة';
      case 'video': return '🎥 فيديو';
      case 'audio': return '🎤 رسالة صوتية';
      case 'file': return '📎 ${fileName ?? "ملف"}';
      case 'listen_together': return '🎵 استماع معاً';
      case 'poll': return '📊 ${poll?.question ?? "استطلاع"}';
      case 'location': return '📍 موقع';
      case 'contact': return '👤 ${contact?['name'] ?? "جهة اتصال"}';
      case 'system': return text ?? '';
      default: return '';
    }
  }

  static DateTime _parseTs(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    PollModel? poll;
    if (json['poll'] != null) {
      try { poll = PollModel.fromJson(json['poll'] as Map<String, dynamic>); } catch (_) {}
    }
    return MessageModel(
      id: json['id'] as String? ?? '',
      conversationId: json['conversationId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String?,
      senderPhoto: json['senderPhoto'] as String?,
      type: json['type'] as String? ?? 'text',
      text: json['text'] as String?,
      fileUrl: json['fileUrl'] as String?,
      fileName: json['fileName'] as String?,
      mimeType: json['mimeType'] as String?,
      fileSize: json['fileSize'] as int?,
      sessionId: json['sessionId'] as String?,
      replyToId: json['replyToId'] as String?,
      replyToText: json['replyToText'] as String?,
      replyToSender: json['replyToSender'] as String?,
      createdAt: _parseTs(json['createdAt']),
      readBy: json['readBy'] as Map<String, dynamic>?,
      deleted: json['deleted'] as bool? ?? false,
      isEdited: json['isEdited'] as bool? ?? false,
      editedText: json['editedText'] as String?,
      reactions: json['reactions'] != null
          ? Map<String, String>.from(json['reactions'] as Map)
          : null,
      isStarred: json['isStarred'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false,
      forwardedFrom: json['forwardedFrom'] as String?,
      disappearAfterSeconds: json['disappearAfterSeconds'] as int?,
      poll: poll,
      location: json['location'] as Map<String, dynamic>?,
      contact: json['contact'] as Map<String, dynamic>?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }

  MessageModel copyWith({
    bool? deleted,
    bool? isEdited,
    String? editedText,
    Map<String, String>? reactions,
    bool? isStarred,
    bool? isPinned,
    PollModel? poll,
  }) {
    return MessageModel(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      senderPhoto: senderPhoto,
      type: type,
      text: text,
      fileUrl: fileUrl,
      fileName: fileName,
      mimeType: mimeType,
      fileSize: fileSize,
      sessionId: sessionId,
      replyToId: replyToId,
      replyToText: replyToText,
      replyToSender: replyToSender,
      createdAt: createdAt,
      readBy: readBy,
      deleted: deleted ?? this.deleted,
      isEdited: isEdited ?? this.isEdited,
      editedText: editedText ?? this.editedText,
      reactions: reactions ?? this.reactions,
      isStarred: isStarred ?? this.isStarred,
      isPinned: isPinned ?? this.isPinned,
      forwardedFrom: forwardedFrom,
      disappearAfterSeconds: disappearAfterSeconds,
      poll: poll ?? this.poll,
      location: location,
      contact: contact,
      thumbnailUrl: thumbnailUrl,
    );
  }
}
