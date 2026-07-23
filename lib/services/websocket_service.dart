import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'auth_service.dart';

typedef WsHandler = void Function(Map<String, dynamic> msg);

class WebSocketService {
  static WebSocketChannel? _channel;
  static final Map<String, List<WsHandler>> _handlers = {};
  static Timer? _pingTimer;
  static Timer? _reconnectTimer;
  static bool _connected = false;
  static bool _shouldReconnect = true;

  static const String _wsBase = 'wss://wa-clone-976d4-production.up.railway.app/ws';

  static bool get isConnected => _connected;

  static Future<void> connect() async {
    _shouldReconnect = true;
    await _doConnect();
  }

  static Future<void> _doConnect() async {
    try {
      final token = await AuthService.getIdToken();
      if (token == null) return;
      final uri = Uri.parse('$_wsBase?token=$token');
      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen(
        _onMessage,
        onDone: _onDisconnect,
        onError: _onError,
        cancelOnError: false,
      );
      _connected = true;
      _startPing();
    } catch (e) {
      _scheduleReconnect();
    }
  }

  static void _onMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw.toString()) as Map<String, dynamic>;
      final type = data['type'] as String? ?? '';
      if (type == 'pong') return;
      final handlers = _handlers[type];
      if (handlers != null) {
        for (final h in List.from(handlers)) {
          h(data);
        }
      }
    } catch (_) {}
  }

  static void _onDisconnect() {
    _connected = false;
    _pingTimer?.cancel();
    if (_shouldReconnect) _scheduleReconnect();
  }

  static void _onError(dynamic _) {
    _connected = false;
    _pingTimer?.cancel();
    if (_shouldReconnect) _scheduleReconnect();
  }

  static void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_shouldReconnect) _doConnect();
    });
  }

  static void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      send({'type': 'ping'});
    });
  }

  static void disconnect() {
    _shouldReconnect = false;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _connected = false;
  }

  static void on(String type, WsHandler handler) {
    _handlers.putIfAbsent(type, () => []).add(handler);
  }

  static void off(String type, WsHandler handler) {
    _handlers[type]?.remove(handler);
  }

  static void send(Map<String, dynamic> data) {
    try {
      if (_connected) {
        _channel?.sink.add(jsonEncode(data));
      }
    } catch (_) {}
  }

  // ─── Call Signaling ───────────────────────────────────────────────────────
  static void sendCallOffer(String targetUid, Map<String, dynamic> sdp, {bool isVideo = false}) =>
      send({'type': 'call_offer', 'targetUid': targetUid, 'sdp': sdp, 'callType': isVideo ? 'video' : 'voice'});

  static void sendCallAnswer(String targetUid, Map<String, dynamic> sdp) =>
      send({'type': 'call_answer', 'targetUid': targetUid, 'sdp': sdp});

  static void sendCallIce(String targetUid, Map<String, dynamic> candidate) =>
      send({'type': 'call_ice', 'targetUid': targetUid, 'candidate': candidate});

  static void sendCallEnd(String targetUid) =>
      send({'type': 'call_end', 'targetUid': targetUid});

  static void sendCallReject(String targetUid) =>
      send({'type': 'call_reject', 'targetUid': targetUid});

  static void sendCallSignal({
    required String callId,
    required String targetUid,
    required String type,
    required String action,
  }) {
    final messageType = switch (action) {
      'initiate' => 'call_offer',
      'accept' => 'call_answer',
      'reject' => 'call_reject',
      _ => 'call_$action',
    };
    send({
      'type': messageType,
      'targetUid': targetUid,
      'callId': callId,
      'callType': type,
    });
  }

  static void sendToggleVideo(String targetUid, bool enabled) =>
      send({'type': 'call_toggle_video', 'targetUid': targetUid, 'enabled': enabled});

  // ─── Typing ───────────────────────────────────────────────────────────────
  static void sendTyping(String targetUid, {bool isTyping = true}) =>
      send({'type': isTyping ? 'typing_start' : 'typing_stop', 'targetUid': targetUid});

  // ─── Message Delivery Status ──────────────────────────────────────────────
  static void sendDelivered(String targetUid, String convId, String msgId) =>
      send({'type': 'msg_delivered', 'targetUid': targetUid, 'convId': convId, 'msgId': msgId});

  static void sendRead(String targetUid, String convId) =>
      send({'type': 'msg_read', 'targetUid': targetUid, 'convId': convId});

  // ─── Listen Together ──────────────────────────────────────────────────────
  static void sendLTInvite(String targetUid, String sessionId) =>
      send({'type': 'lt_invite', 'targetUid': targetUid, 'sessionId': sessionId});

  static void sendLTAccept(String targetUid, String sessionId) =>
      send({'type': 'lt_accept', 'targetUid': targetUid, 'sessionId': sessionId});

  static void sendLTReject(String targetUid, String sessionId) =>
      send({'type': 'lt_reject', 'targetUid': targetUid, 'sessionId': sessionId});

  static void sendLTPlay(String targetUid, String sessionId, int positionMs) =>
      send({'type': 'lt_play', 'targetUid': targetUid, 'sessionId': sessionId, 'positionMs': positionMs});

  static void sendLTPause(String targetUid, String sessionId, int positionMs) =>
      send({'type': 'lt_pause', 'targetUid': targetUid, 'sessionId': sessionId, 'positionMs': positionMs});

  static void sendLTSeek(String targetUid, String sessionId, int positionMs) =>
      send({'type': 'lt_seek', 'targetUid': targetUid, 'sessionId': sessionId, 'positionMs': positionMs});

  static void sendLTNext(String targetUid, String sessionId, int index) =>
      send({'type': 'lt_next', 'targetUid': targetUid, 'sessionId': sessionId, 'index': index});

  static void sendLTEnd(String targetUid, String sessionId) =>
      send({'type': 'lt_end', 'targetUid': targetUid, 'sessionId': sessionId});

  // ─── Reactions / Status ───────────────────────────────────────────────────
  static void sendReaction(String targetUid, String convId, String msgId, String emoji) =>
      send({'type': 'reaction', 'targetUid': targetUid, 'convId': convId, 'msgId': msgId, 'emoji': emoji});

  static void sendOnlineStatus(String targetUid, bool isOnline) =>
      send({'type': 'online_status', 'targetUid': targetUid, 'isOnline': isOnline});
}
