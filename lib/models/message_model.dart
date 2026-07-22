class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String type;
  final String? content;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final String? replyToId;
  final DateTime createdAt;
  final String? senderName;
  final String? senderPhoto;
  final String status;

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
    this.status = 'sent',
  });

  static DateTime _ts(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    try { return (v as dynamic).toDate() as DateTime; } catch (_) { return DateTime.now(); }
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: (json['id'] ?? '') as String,
      conversationId: (json['conversationId'] ?? json['conversation_id'] ?? '').toString(),
      senderId: (json['senderId'] ?? json['sender_id'] ?? '').toString(),
      type: (json['type'] as String? ?? 'text'),
      content: json['content'] as String?,
      fileUrl: (json['fileUrl'] ?? json['file_url']) as String?,
      fileName: (json['fileName'] ?? json['file_name']) as String?,
      fileSize: (json['fileSize'] ?? json['file_size']) as int?,
      mimeType: (json['mimeType'] ?? json['mime_type']) as String?,
      replyToId: (json['replyToId'] ?? json['reply_to_id'])?.toString(),
      createdAt: _ts(json['createdAt'] ?? json['created_at']),
      senderName: (json['senderName'] ?? json['sender_name']) as String?,
      senderPhoto: (json['senderPhoto'] ?? json['sender_photo']) as String?,
      status: (json['status'] as String? ?? 'sent'),
    );
  }
}
