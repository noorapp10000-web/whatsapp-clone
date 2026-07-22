import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  // ─── Users ────────────────────────────────────────────────────────────────
  static Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromJson({'id': doc.id, ...doc.data()!});
  }

  static Future<List<UserModel>> searchUsers(String q, String myUid) async {
    if (q.trim().length < 2) return [];
    final snap = await _db.collection('users').limit(200).get();
    final qLow = q.toLowerCase();
    final results = <UserModel>[];
    for (final doc in snap.docs) {
      if (doc.id == myUid) continue;
      final data = doc.data();
      final name  = (data['displayName'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      if (name.contains(qLow) || email.contains(qLow)) {
        results.add(UserModel.fromJson({'id': doc.id, ...data}));
        if (results.length >= 20) break;
      }
    }
    return results;
  }

  // ─── Conversations ────────────────────────────────────────────────────────
  static Stream<List<ConversationModel>> conversationsStream(String myUid) {
    return _db
        .collection('conversations')
        .where('participantIds', arrayContains: myUid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ConversationModel.fromJson({'id': doc.id, ...doc.data()}))
            .toList());
  }

  static Future<ConversationModel> createDirectConversation(
      String myUid, String otherUid) async {
    final existing = await _db
        .collection('conversations')
        .where('type', isEqualTo: 'direct')
        .where('participantIds', arrayContains: myUid)
        .get();

    for (final doc in existing.docs) {
      final ids = List<String>.from(doc.data()['participantIds'] ?? []);
      if (ids.contains(otherUid)) {
        return ConversationModel.fromJson({'id': doc.id, ...doc.data()});
      }
    }

    final myDoc    = await _db.collection('users').doc(myUid).get();
    final otherDoc = await _db.collection('users').doc(otherUid).get();
    final now = Timestamp.now();

    final ref = await _db.collection('conversations').add({
      'type': 'direct',
      'participantIds': [myUid, otherUid],
      'participants': [
        {'uid': myUid, ...(myDoc.data() ?? {})},
        {'uid': otherUid, ...(otherDoc.data() ?? {})},
      ],
      'lastMessageAt': now,
      'createdAt': now,
      'createdBy': myUid,
    });
    final convDoc = await ref.get();
    return ConversationModel.fromJson({'id': convDoc.id, ...convDoc.data()!});
  }

  // ─── Messages ─────────────────────────────────────────────────────────────
  static Stream<List<MessageModel>> messagesStream(String convId) {
    return _db
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MessageModel.fromJson(
                {'id': doc.id, 'conversationId': convId, ...doc.data()}))
            .toList());
  }

  static Future<void> sendMessage(
    String convId,
    String senderUid, {
    required String type,
    String? content,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? mimeType,
    String? replyToId,
  }) async {
    final now = FieldValue.serverTimestamp();
    final msgRef =
        _db.collection('conversations').doc(convId).collection('messages').doc();
    await msgRef.set({
      'senderId': senderUid,
      'type': type,
      if (content  != null) 'content':  content,
      if (fileUrl  != null) 'fileUrl':  fileUrl,
      if (fileName != null) 'fileName': fileName,
      if (fileSize != null) 'fileSize': fileSize,
      if (mimeType != null) 'mimeType': mimeType,
      if (replyToId != null) 'replyToId': replyToId,
      'status': 'sent',
      'createdAt': now,
    });
    await _db.collection('conversations').doc(convId).update({
      'lastMessage': {
        'id': msgRef.id,
        'content': content ?? fileName ?? '',
        'type': type,
        'senderId': senderUid,
        'createdAt': DateTime.now().toIso8601String(),
      },
      'lastMessageAt': now,
    });
  }

  static Future<void> deleteMessage(String convId, String msgId) async {
    await _db
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .doc(msgId)
        .delete();
  }

  // ─── Calls ────────────────────────────────────────────────────────────────
  static Future<String> logCall(
      String callerId, String receiverId, String type) async {
    final ref = await _db.collection('calls').add({
      'callerId': callerId,
      'receiverId': receiverId,
      'type': type,
      'status': 'calling',
      'participantIds': [callerId, receiverId],
      'startedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  static Future<void> updateCall(String callId, String status) async {
    await _db.collection('calls').doc(callId).update({
      'status': status,
      if (['ended', 'rejected', 'missed'].contains(status))
        'endedAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<List<Map<String, dynamic>>> callsStream(String myUid) {
    return _db
        .collection('calls')
        .where('participantIds', arrayContains: myUid)
        .orderBy('startedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }
}
