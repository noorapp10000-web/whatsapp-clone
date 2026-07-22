class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String type; // text, image, video, audio, voice, file, listen_together
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
  final Map<String, String>? reactions; // uid → emoji
  final int? durationMs; // for voice/audio

  // Listen Together fields
  final String? ltSessionId;
  final String? ltUrl;
  final String? ltTitle;
  final List<Map<String, dynamic>>? ltPlaylist;

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
    this.reactions,
    this.durationMs,
    this.ltSessionId,
    this.ltUrl,
    this.ltTitle,
    this.ltPlaylist,
  });

  static DateTime _ts(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final reactionsRaw = json['reactions'];
    Map<String, String>? reactions;
    if (reactionsRaw is Map) {
      reactions = reactionsRaw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }

    final ltPlaylistRaw = json['ltPlaylist'];
    List<Map<String, dynamic>>? ltPlaylist;
    if (ltPlaylistRaw is List) {
      ltPlaylist = ltPlaylistRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return MessageModel(
      id: (json['id'] ?? '') as String,
      conversationId:
          (json['conversationId'] ?? json['conversation_id'] ?? '').toString(),
      senderId:
          (json['senderId'] ?? json['sender_id'] ?? '').toString(),
      type: (json['type'] as String? ?? 'text'),
      content: json['content'] as String?,
      fileUrl: (json['fileUrl'] ?? json['file_url']) as String?,
      fileName: (json['fileName'] ?? json['file_name']) as String?,
      fileSize: (json['fileSize'] ?? json['file_size']) as int?,
      mimeType: (json['mimeType'] ?? json['mime_type']) as String?,
      replyToId:
          (json['replyToId'] ?? json['reply_to_id'])?.toString(),
      createdAt: _ts(json['createdAt'] ?? json['created_at']),
      senderName: (json['senderName'] ?? json['sender_name']) as String?,
      senderPhoto:
          (json['senderPhoto'] ?? json['sender_photo']) as String?,
      status: (json['status'] as String? ?? 'sent'),
      reactions: reactions,
      durationMs: json['durationMs'] as int?,
      ltSessionId: json['ltSessionId'] as String?,
      ltUrl: json['ltUrl'] as String?,
      ltTitle: json['ltTitle'] as String?,
      ltPlaylist: ltPlaylist,
    );
  }

  MessageModel copyWith({
    String? status,
    Map<String, String>? reactions,
  }) {
    return MessageModel(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      type: type,
      content: content,
      fileUrl: fileUrl,
      fileName: fileName,
      fileSize: fileSize,
      mimeType: mimeType,
      replyToId: replyToId,
      createdAt: createdAt,
      senderName: senderName,
      senderPhoto: senderPhoto,
      status: status ?? this.status,
      reactions: reactions ?? this.reactions,
      durationMs: durationMs,
      ltSessionId: ltSessionId,
      ltUrl: ltUrl,
      ltTitle: ltTitle,
      ltPlaylist: ltPlaylist,
    );
  }
}
