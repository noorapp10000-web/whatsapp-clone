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
      final name = (data['displayName'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      if (name.contains(qLow) || email.contains(qLow)) {
        results.add(UserModel.fromJson({'id': doc.id, ...data}));
        if (results.length >= 20) break;
      }
    }
    return results;
  }

  static Future<void> updateUserOnline(String uid, bool isOnline) async {
    await _db.collection('users').doc(uid).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  // ─── Conversations ────────────────────────────────────────────────────────
  static Stream<List<ConversationModel>> conversationsStream(String myUid) {
    return _db
        .collection('conversations')
        .where('participantIds', arrayContains: myUid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) =>
                ConversationModel.fromJson({'id': doc.id, ...doc.data()}))
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

    final myDoc = await _db.collection('users').doc(myUid).get();
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

  static Future<ConversationModel> createGroupConversation({
    required String myUid,
    required List<String> memberUids,
    required String name,
    String? photoUrl,
  }) async {
    final allUids = [myUid, ...memberUids];
    final participantDocs = await Future.wait(
        allUids.map((uid) => _db.collection('users').doc(uid).get()));

    final now = Timestamp.now();
    final ref = await _db.collection('conversations').add({
      'type': 'group',
      'name': name,
      if (photoUrl != null) 'groupPhotoUrl': photoUrl,
      'participantIds': allUids,
      'participants': participantDocs
          .map((d) => {'uid': d.id, ...d.data() ?? {}})
          .toList(),
      'adminIds': [myUid],
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

  static Future<String> sendMessage(
    String convId,
    String senderUid, {
    required String type,
    String? content,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? mimeType,
    String? replyToId,
    int? durationMs,
    // Listen Together
    String? ltSessionId,
    String? ltUrl,
    String? ltTitle,
    List<Map<String, dynamic>>? ltPlaylist,
  }) async {
    final now = FieldValue.serverTimestamp();
    final msgRef = _db
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .doc();

    await msgRef.set({
      'senderId': senderUid,
      'type': type,
      if (content != null) 'content': content,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
      if (fileSize != null) 'fileSize': fileSize,
      if (mimeType != null) 'mimeType': mimeType,
      if (replyToId != null) 'replyToId': replyToId,
      if (durationMs != null) 'durationMs': durationMs,
      if (ltSessionId != null) 'ltSessionId': ltSessionId,
      if (ltUrl != null) 'ltUrl': ltUrl,
      if (ltTitle != null) 'ltTitle': ltTitle,
      if (ltPlaylist != null) 'ltPlaylist': ltPlaylist,
      'status': 'sent',
      'createdAt': now,
    });

    await _db.collection('conversations').doc(convId).update({
      'lastMessage': {
        'id': msgRef.id,
        'content': content ??
            (type == 'voice'
                ? '🎤 Voice message'
                : type == 'listen_together'
                    ? '🎵 Listen Together: ${ltTitle ?? 'Music'}'
                    : fileName ?? ''),
        'type': type,
        'senderId': senderUid,
        'createdAt': DateTime.now().toIso8601String(),
      },
      'lastMessageAt': now,
    });

    return msgRef.id;
  }

  static Future<void> markMessagesRead(String convId, String myUid) async {
    final unread = await _db
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .where('senderId', isNotEqualTo: myUid)
        .where('status', isEqualTo: 'sent')
        .limit(30)
        .get();

    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'status': 'read'});
    }
    await batch.commit();
  }

  static Future<void> addReaction(
      String convId, String msgId, String myUid, String emoji) async {
    await _db
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .doc(msgId)
        .update({'reactions.$myUid': emoji});
  }

  static Future<void> removeReaction(
      String convId, String msgId, String myUid) async {
    await _db
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .doc(msgId)
        .update({'reactions.$myUid': FieldValue.delete()});
  }

  static Future<void> deleteMessage(String convId, String msgId) async {
    await _db
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .doc(msgId)
        .delete();
  }

  // ─── Listen Together Sessions ─────────────────────────────────────────────
  static Future<String> createListenSession({
    required String creatorUid,
    required List<String> participantUids,
    required List<Map<String, dynamic>> playlist,
  }) async {
    final ref = await _db.collection('listen_sessions').add({
      'creatorUid': creatorUid,
      'participants': [creatorUid, ...participantUids],
      'playlist': playlist,
      'currentIndex': 0,
      'isPlaying': false,
      'positionMs': 0,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
      'lastUpdatedBy': creatorUid,
    });
    return ref.id;
  }

  static Future<void> updateListenSession(
      String sessionId, Map<String, dynamic> data, String updaterUid) async {
    await _db.collection('listen_sessions').doc(sessionId).update({
      ...data,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
      'lastUpdatedBy': updaterUid,
    });
  }

  static Stream<Map<String, dynamic>?> listenSessionStream(String sessionId) {
    return _db
        .collection('listen_sessions')
        .doc(sessionId)
        .snapshots()
        .map((doc) => doc.exists ? {'id': doc.id, ...doc.data()!} : null);
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

  // ─── Additional helpers ───────────────────────────────────────────────────

  /// Create a listen session with a known ID (host-generated)
  static Future<void> createListenSessionById(
      String sessionId, Map<String, dynamic> data) async {
    await _db.collection('listen_sessions').doc(sessionId).set({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get a listen session by ID (one-shot read)
  static Future<Map<String, dynamic>?> getListenSession(
      String sessionId) async {
    final doc =
        await _db.collection('listen_sessions').doc(sessionId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data()!};
  }

  /// Update session fields (updaterUid optional)
  static Future<void> updateListenSessionData(
      String sessionId, Map<String, dynamic> data) async {
    await _db.collection('listen_sessions').doc(sessionId).update({
      ...data,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Alias: react to a message
  static Future<void> reactToMessage(
      String convId, String msgId, String myUid, String emoji) =>
      addReaction(convId, msgId, myUid, emoji);

  /// Online status stream for a user
  static Stream<bool> onlineStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => (doc.data()?['isOnline'] as bool?) ?? false);
  }
}
