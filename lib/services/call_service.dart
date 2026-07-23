import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'websocket_service.dart';
import 'api_service.dart';

class CallService {
  static Future<Map<String, dynamic>> initiateCall({
    required String calleeUid,
    required String calleeName,
    required bool isVideo,
    String? calleePhoto,
  }) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) throw Exception('غير مسجل الدخول');

    final callDoc = await FirebaseFirestore.instance.collection('calls').add({
      'callerUid': myUid,
      'calleeUid': calleeUid,
      'type': isVideo ? 'video' : 'voice',
      'status': 'calling',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Notify via WebSocket
    WebSocketService.instance.sendCallSignal(
      callId: callDoc.id,
      toUid: calleeUid,
      type: isVideo ? 'video' : 'voice',
      action: 'initiate',
    );

    // Send push notification
    try {
      await ApiService.sendPushNotification(
        toUid: calleeUid,
        title: isVideo ? '📹 مكالمة فيديو واردة' : '📞 مكالمة واردة',
        body: 'يتصل بك ${FirebaseAuth.instance.currentUser?.displayName ?? 'شخص ما'}',
        data: {'callId': callDoc.id, 'type': isVideo ? 'video' : 'voice'},
      );
    } catch (_) {}

    return {'callId': callDoc.id};
  }

  static Future<void> endCall(String callId, {int? durationSeconds}) async {
    await FirebaseFirestore.instance.collection('calls').doc(callId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
    });
  }

  static Future<void> acceptCall(String callId, String callerUid) async {
    await FirebaseFirestore.instance.collection('calls').doc(callId).update({
      'status': 'active',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
    WebSocketService.instance.sendCallSignal(
      callId: callId,
      toUid: callerUid,
      type: 'accept',
      action: 'accept',
    );
  }

  static Future<void> rejectCall(String callId, String callerUid) async {
    await FirebaseFirestore.instance.collection('calls').doc(callId).update({
      'status': 'rejected',
      'endedAt': FieldValue.serverTimestamp(),
    });
    WebSocketService.instance.sendCallSignal(
      callId: callId,
      toUid: callerUid,
      type: 'reject',
      action: 'reject',
    );
  }

  static Stream<DocumentSnapshot> callStream(String callId) {
    return FirebaseFirestore.instance.collection('calls').doc(callId).snapshots();
  }
}
