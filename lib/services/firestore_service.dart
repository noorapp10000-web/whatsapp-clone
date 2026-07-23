import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/status_model.dart';
import '../models/poll_model.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  // ─── Users ────────────────────────────────────────────────────────────────
  static Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromJson({'id': doc.id, ...doc.data()!});
  }

  static Stream<UserModel?> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromJson({'id': doc.id, ...doc.data()!});
    });
  }

  static Future<List<UserModel>> searchUsers(String q, String myUid) async {
    if (q.trim().length < 2) return [];
    final snap = await _db.collection('users').limit(300).get();
    final qLow = q.toLowerCase();
    final results = <UserModel>[];
    for (final doc in snap.docs) {
      if (doc.id == myUid) continue;
      final data = doc.data();
      final name = (data['displayName'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      final phone = (data['phone'] ?? '').toString();
      if (name.contains(qLow) || email.contains(qLow) || phone.contains(q)) {
        results.add(UserModel.fromJson({'id': doc.id, ...data}));
        if (results.length >= 30) break;
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

  static Future<void> updateUserProfile(String uid, {
    String? displayName,
    String? status,
    String? photoUrl,
    String? phone,
    Map<String, dynamic>? privacySettings,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (displayName != null) updates['displayName'] = displayName;
    if (status != null) updates['status'] = status;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (phone != null) updates['phone'] = phone;
    if (privacySettings != null) updates['privacySettings'] = privacySettings;
    await _db.collection('users').doc(uid).update(updates);
  }

  // Block / Unblock
  static Future<void> blockUser(String myUid, String targetUid) async {
    await _db.collection('users').doc(myUid).update({
      'blockedUsers': FieldValue.arrayUnion([targetUid]),
    });
  }

  static Future<void> unblockUser(String myUid, String targetUid) async {
    await _db.collection('users').doc(myUid).update({
      'blockedUsers': FieldValue.arrayRemove([targetUid]),
    });
  }

  static Future<List<String>> getBlockedUsers(String myUid) async {
    final doc = await _db.collection('users').doc(myUid).get();
    return List<String>.from(doc.data()?['blockedUsers'] as List? ?? []);
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
      'isArchived': false,
      'isMuted': false,
      'pinnedMessageIds': [],
      'blockedBy': [],
    });
    final convDoc = await ref.get();
    return ConversationModel.fromJson({'id': convDoc.id, ...convDoc.data()!});
  }

  static Future<ConversationModel> createGroupConversation({
    required String myUid,
    required List<String> memberUids,
    required String name,
    String? photoUrl,
    String? description,
  }) async {
    final allUids = [myUid, ...memberUids];
    final participantDocs = await Future.wait(
        allUids.map((uid) => _db.collection('users').doc(uid).get()));
    final now = Timestamp.now();
    final ref = await _db.collection('conversations').add({
      'type': 'group',
      'name': name,
      if (photoUrl != null) 'groupPhotoUrl': photoUrl,
      if (description != null) 'description': description,
      'participantIds': allUids,
      'participants': participantDocs
          .map((d) => {'uid': d.id, ...d.data() ?? {}})
          .toList(),
      'adminIds': [myUid],
      'lastMessageAt': now,
      'createdAt': now,
      'createdBy': myUid,
      'isArchived': false,
      'isMuted': false,
      'onlyAdminsCanMessage': false,
      'pinnedMessageIds': [],
      'blockedBy': [],
    });
    // System message
    await ref.collection('messages').add({
      'type': 'system',
      'text': 'تم إنشاء المجموعة "$name"',
      'senderId': myUid,
      'conversationId': ref.id,
      'createdAt': now,
      'deleted': false,
    });
    final convDoc = await ref.get();
    return ConversationModel.fromJson({'id': convDoc.id, ...convDoc.data()!});
  }

  static Future<void> updateConversation(String convId, Map<String, dynamic> data) async {
    await _db.collection('conversations').doc(convId).update(data);
  }

  static Future<void> archiveConversation(String convId, bool archive) async {
    await _db.collection('conversations').doc(convId).update({'isArchived': archive});
  }

  static Future<void> muteConversation(String convId, bool mute, {DateTime? until}) async {
    await _db.collection('conversations').doc(convId).update({
      'isMuted': mute,
      if (until != null) 'mutedUntil': Timestamp.fromDate(until),
    });
  }

  static Future<void> setDisappearingMessages(String convId, int? seconds) async {
    await _db.collection('conversations').doc(convId).update({
      'disappearingSeconds': seconds,
    });
  }

  static Future<void> setChatWallpaper(String convId, String? wallpaper) async {
    await _db.collection('conversations').doc(convId).update({'wallpaper': wallpaper});
  }

  static Future<void> pinMessage(String convId, String msgId, bool pin) async {
    await _db.collection('conversations').doc(convId).update({
      'pinnedMessageIds': pin
          ? FieldValue.arrayUnion([msgId])
          : FieldValue.arrayRemove([msgId]),
    });
    await _db.collection('conversations').doc(convId)
        .collection('messages').doc(msgId).update({'isPinned': pin});
  }

  static Future<void> addGroupMember(String convId, String uid) async {
    final userDoc = await _db.collection('users').doc(uid).get();
    await _db.collection('conversations').doc(convId).update({
      'participantIds': FieldValue.arrayUnion([uid]),
      'participants': FieldValue.arrayUnion([{'uid': uid, ...userDoc.data() ?? {}}]),
    });
  }

  static Future<void> removeGroupMember(String convId, String uid) async {
    final convDoc = await _db.collection('conversations').doc(convId).get();
    final participants = List<Map<String, dynamic>>.from(
        (convDoc.data()?['participants'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
    final updated = participants.where((p) => (p['uid'] ?? '') != uid).toList();
    await _db.collection('conversations').doc(convId).update({
      'participantIds': FieldValue.arrayRemove([uid]),
      'participants': updated,
      'adminIds': FieldValue.arrayRemove([uid]),
    });
  }

  static Future<void> promoteToAdmin(String convId, String uid) async {
    await _db.collection('conversations').doc(convId).update({
      'adminIds': FieldValue.arrayUnion([uid]),
    });
  }

  static Future<void> demoteAdmin(String convId, String uid) async {
    await _db.collection('conversations').doc(convId).update({
      'adminIds': FieldValue.arrayRemove([uid]),
    });
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
            .map((doc) => MessageModel.fromJson({'id': doc.id, ...doc.data()}))
            .toList());
  }

  static Future<String> sendMessage(
    String convId,
    String senderId, {
    String type = 'text',
    String? text,
    String? fileUrl,
    String? fileName,
    String? mimeType,
    int? fileSize,
    String? sessionId,
    String? replyToId,
    String? replyToText,
    String? replyToSender,
    String? senderName,
    String? senderPhoto,
    int? disappearAfterSeconds,
    PollModel? poll,
    Map<String, dynamic>? location,
    Map<String, dynamic>? contact,
    String? forwardedFrom,
    String? thumbnailUrl,
  }) async {
    final now = Timestamp.now();
    final msgData = <String, dynamic>{
      'conversationId': convId,
      'senderId': senderId,
      if (senderName != null) 'senderName': senderName,
      if (senderPhoto != null) 'senderPhoto': senderPhoto,
      'type': type,
      if (text != null) 'text': text,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
      if (mimeType != null) 'mimeType': mimeType,
      if (fileSize != null) 'fileSize': fileSize,
      if (sessionId != null) 'sessionId': sessionId,
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToText != null) 'replyToText': replyToText,
      if (replyToSender != null) 'replyToSender': replyToSender,
      if (forwardedFrom != null) 'forwardedFrom': forwardedFrom,
      if (disappearAfterSeconds != null) 'disappearAfterSeconds': disappearAfterSeconds,
      if (poll != null) 'poll': poll.toJson(),
      if (location != null) 'location': location,
      if (contact != null) 'contact': contact,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      'createdAt': now,
      'deleted': false,
      'isEdited': false,
      'isStarred': false,
      'isPinned': false,
      'reactions': {},
    };
    final ref = await _db
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .add(msgData);

    // Update conversation last message
    final convRef = _db.collection('conversations').doc(convId);
    final convDoc = await convRef.get();
    final participantIds = List<String>.from(convDoc.data()?['participantIds'] as List? ?? []);
    final unreadUpdates = <String, dynamic>{};
    for (final uid in participantIds) {
      if (uid != senderId) {
        unreadUpdates['unreadCounts.$uid'] = FieldValue.increment(1);
      }
    }
    await convRef.update({
      'lastMessage': text ?? _typeEmoji(type),
      'lastMessageType': type,
      'lastMessageSenderId': senderId,
      'lastMessageAt': now,
      ...unreadUpdates,
    });

    return ref.id;
  }

  static String _typeEmoji(String type) {
    switch (type) {
      case 'image': return '📷 صورة';
      case 'video': return '🎥 فيديو';
      case 'audio': return '🎤 رسالة صوتية';
      case 'file': return '📎 ملف';
      case 'poll': return '📊 استطلاع';
      case 'location': return '📍 موقع';
      case 'contact': return '👤 جهة اتصال';
      default: return '';
    }
  }

  static Future<void> markMessagesRead(String convId, String myUid) async {
    await _db.collection('conversations').doc(convId).update({
      'unreadCounts.$myUid': 0,
    });
    final unread = await _db
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .where('readBy.$myUid', isEqualTo: null)
        .limit(100)
        .get();
    final batch = _db.batch();
    for (final doc in unread.docs) {
      if ((doc.data()['senderId'] ?? '') != myUid) {
        batch.update(doc.reference, {'readBy.$myUid': Timestamp.now()});
      }
    }
    await batch.commit();
  }

  static Future<void> deleteMessage(String convId, String msgId, {bool forEveryone = false}) async {
    if (forEveryone) {
      await _db.collection('conversations').doc(convId)
          .collection('messages').doc(msgId).update({
        'deleted': true,
        'text': null,
        'fileUrl': null,
      });
    } else {
      await _db.collection('conversations').doc(convId)
          .collection('messages').doc(msgId).update({
        'deletedFor': FieldValue.arrayUnion([]), // soft delete per user
      });
    }
  }

  static Future<void> editMessage(String convId, String msgId, String newText) async {
    await _db.collection('conversations').doc(convId)
        .collection('messages').doc(msgId).update({
      'isEdited': true,
      'editedText': newText,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> reactToMessage(
      String convId, String msgId, String uid, String emoji) async {
    await _db.collection('conversations').doc(convId)
        .collection('messages').doc(msgId).update({
      'reactions.$uid': emoji,
    });
  }

  static Future<void> removeReaction(String convId, String msgId, String uid) async {
    await _db.collection('conversations').doc(convId)
        .collection('messages').doc(msgId).update({
      'reactions.$uid': FieldValue.delete(),
    });
  }

  static Future<void> starMessage(String convId, String msgId, bool star) async {
    await _db.collection('conversations').doc(convId)
        .collection('messages').doc(msgId).update({'isStarred': star});
  }

  static Stream<List<MessageModel>> starredMessagesStream(String myUid) {
    // We search starred messages across all conversations the user is in
    return _db
        .collectionGroup('messages')
        .where('isStarred', isEqualTo: true)
        .where('senderId', isEqualTo: myUid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MessageModel.fromJson({'id': doc.id, ...doc.data()}))
            .toList());
  }

  static Future<void> votePoll(
      String convId, String msgId, int optionIndex, String uid) async {
    // Remove vote from all options first, then add
    final msgDoc = await _db.collection('conversations').doc(convId)
        .collection('messages').doc(msgId).get();
    final pollData = msgDoc.data()?['poll'] as Map<String, dynamic>?;
    if (pollData == null) return;
    final options = List<Map<String, dynamic>>.from(
        (pollData['options'] as List).map((o) => Map<String, dynamic>.from(o as Map)));
    for (int i = 0; i < options.length; i++) {
      final votes = List<String>.from(options[i]['votes'] as List? ?? []);
      votes.remove(uid);
      if (i == optionIndex) votes.add(uid);
      options[i] = {...options[i], 'votes': votes};
    }
    await _db.collection('conversations').doc(convId)
        .collection('messages').doc(msgId).update({
      'poll.options': options,
    });
  }

  // ─── Calls ────────────────────────────────────────────────────────────────
  static Stream<List<Map<String, dynamic>>> callsStream(String myUid) {
    return _db
        .collection('calls')
        .where('participants', arrayContains: myUid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  static Future<String> logCall(
      String callerUid, String calleeUid, String type) async {
    final ref = await _db.collection('calls').add({
      'callerUid': callerUid,
      'calleeUid': calleeUid,
      'participants': [callerUid, calleeUid],
      'type': type,
      'status': 'calling',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  static Future<void> updateCallStatus(String callId, String status, {int? durationSeconds}) async {
    final updates = <String, dynamic>{'status': status};
    if (durationSeconds != null) updates['durationSeconds'] = durationSeconds;
    if (status == 'ended' || status == 'missed') {
      updates['endedAt'] = FieldValue.serverTimestamp();
    }
    await _db.collection('calls').doc(callId).update(updates);
  }

  // ─── Status / Stories ─────────────────────────────────────────────────────
  static Future<void> createStatus(StatusModel status) async {
    await _db.collection('statuses').doc(status.id).set(status.toJson());
  }

  static Stream<List<StatusModel>> statusesStream(List<String> participantIds) {
    final cutoff = Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24)));
    return _db
        .collection('statuses')
        .where('uid', whereIn: participantIds.isEmpty ? ['__none__'] : participantIds.take(10).toList())
        .where('createdAt', isGreaterThan: cutoff)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => StatusModel.fromJson({'id': doc.id, ...doc.data()}))
            .where((s) => !s.isExpired)
            .toList());
  }

  static Future<List<StatusModel>> getMyStatuses(String myUid) async {
    final cutoff = Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24)));
    final snap = await _db
        .collection('statuses')
        .where('uid', isEqualTo: myUid)
        .where('createdAt', isGreaterThan: cutoff)
        .orderBy('createdAt', descending: false)
        .get();
    return snap.docs
        .map((doc) => StatusModel.fromJson({'id': doc.id, ...doc.data()}))
        .where((s) => !s.isExpired)
        .toList();
  }

  static Future<void> viewStatus(String statusId, String viewerUid) async {
    await _db.collection('statuses').doc(statusId).update({
      'viewedBy': FieldValue.arrayUnion([viewerUid]),
    });
  }

  static Future<void> deleteStatus(String statusId) async {
    await _db.collection('statuses').doc(statusId).delete();
  }

  static Future<void> reactToStatus(String statusId, String uid, String emoji) async {
    await _db.collection('statuses').doc(statusId).update({
      'reactions.$uid': emoji,
    });
  }

  // ─── Listen Together ──────────────────────────────────────────────────────
  static Future<void> updateListenSessionData(
      String sessionId, Map<String, dynamic> data) async {
    await _db.collection('listenSessions').doc(sessionId).set(data, SetOptions(merge: true));
  }

  static Future<Map<String, dynamic>?> getListenSession(String sessionId) async {
    final doc = await _db.collection('listenSessions').doc(sessionId).get();
    return doc.exists ? doc.data() : null;
  }

  // ─── Notifications / Settings ─────────────────────────────────────────────
  static Future<void> saveUserSettings(String uid, Map<String, dynamic> settings) async {
    await _db.collection('userSettings').doc(uid).set(settings, SetOptions(merge: true));
  }

  static Future<Map<String, dynamic>> getUserSettings(String uid) async {
    final doc = await _db.collection('userSettings').doc(uid).get();
    return doc.data() ?? {};
  }

  // ─── Broadcast Lists ──────────────────────────────────────────────────────
  static Future<void> createBroadcast({
    required String myUid,
    required String name,
    required List<String> recipientUids,
  }) async {
    await _db.collection('broadcasts').add({
      'name': name,
      'createdBy': myUid,
      'recipientUids': recipientUids,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<List<Map<String, dynamic>>> broadcastsStream(String myUid) {
    return _db
        .collection('broadcasts')
        .where('createdBy', isEqualTo: myUid)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }
}
