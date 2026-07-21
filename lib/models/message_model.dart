class MessageModel {
  final int id;
  final int conversationId;
  final int senderId;
  final String type;
  final String? content;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final int? replyToId;
  final DateTime createdAt;
  final String? senderName;
  final String? senderPhoto;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    this.content,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.replyToId,
    required this.createdAt,
    this.senderName,
    this.senderPhoto,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    // Handle both snake_case (from server) and camelCase keys
    final conversationId = json['conversation_id'] ?? json['conversationId'];
    final senderId = json['sender_id'] ?? json['senderId'];
    final fileUrl = json['file_url'] ?? json['fileUrl'];
    final fileName = json['file_name'] ?? json['fileName'];
    final fileSize = json['file_size'] ?? json['fileSize'];
    final mimeType = json['mime_type'] ?? json['mimeType'];
    final replyToId = json['reply_to_id'] ?? json['replyToId'];
    final createdAt = json['created_at'] ?? json['createdAt'];
    final senderName = json['sender_name'] ?? json['senderName'];
    final senderPhoto = json['sender_photo'] ?? json['senderPhoto'];

    return MessageModel(
      id: json['id'] as int,
      conversationId: conversationId as int? ?? 0,
      senderId: senderId as int? ?? 0,
      type: (json['type'] as String? ?? 'text'),
      content: json['content'] as String?,
      fileUrl: fileUrl as String?,
      fileName: fileName as String?,
      fileSize: fileSize as int?,
      mimeType: mimeType as String?,
      replyToId: replyToId as int?,
      createdAt: DateTime.parse(createdAt as String),
      senderName: senderName as String?,
      senderPhoto: senderPhoto as String?,
    );
  }
}
