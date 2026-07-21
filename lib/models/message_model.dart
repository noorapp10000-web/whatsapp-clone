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

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
        id: json['id'],
        conversationId: json['conversationId'],
        senderId: json['senderId'],
        type: json['type'] ?? 'text',
        content: json['content'],
        fileUrl: json['fileUrl'],
        fileName: json['fileName'],
        fileSize: json['fileSize'],
        mimeType: json['mimeType'],
        replyToId: json['replyToId'],
        createdAt: DateTime.parse(json['createdAt']),
        senderName: json['senderName'],
        senderPhoto: json['senderPhoto'],
      );
}
