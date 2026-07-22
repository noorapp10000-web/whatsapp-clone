import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'auth_service.dart';

class WebSocketService {
  // Replaced by CI/CD via BACKEND_WS_URL secret
  static const String _wsBase = 'wss://YOUR_REPLIT_BACKEND_URL/ws';

  static WebSocketChannel? _channel;
  static bool _connected = false;
  static Timer? _reconnectTimer;
  static Timer? _pingTimer;
  static final Map<String, List<Function(Map<String, dynamic>)>> _listeners =
      {};

  static bool get isConnected => _connected;

  static void on(String event, Function(Map<String, dynamic>) cb) =>
      _listeners.putIfAbsent(event, () => []).add(cb);

  static void off(String event, Function(Map<String, dynamic>) cb) =>
      _listeners[event]?.remove(cb);

  static void _dispatch(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    if (type == null) return;
    final listeners = List.from(_listeners[type] ?? []);
    for (final cb in listeners) {
      cb(msg);
    }
  }

  static Future<void> connect() async {
    if (_connected) return;
    final token = await AuthService.getIdToken();
    if (token == null) return;
    try {
      final uri = Uri.parse('$_wsBase?token=${Uri.encodeComponent(token)}');
      _channel = WebSocketChannel.connect(uri);
      _connected = true;
      _channel!.stream.listen(
        (data) {
          try {
            _dispatch(jsonDecode(data as String) as Map<String, dynamic>);
          } catch (_) {}
        },
        onError: (_) {
          _connected = false;
          _pingTimer?.cancel();
          _scheduleReconnect();
        },
        onDone: () {
          _connected = false;
          _pingTimer?.cancel();
          _scheduleReconnect();
        },
      );
      // Keep-alive ping every 25s
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        if (_connected) send({'type': 'ping'});
      });
    } catch (_) {
      _connected = false;
      _scheduleReconnect();
    }
  }

  static void send(Map<String, dynamic> data) {
    if (_connected && _channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  static void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), connect);
  }

  static void disconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _connected = false;
    _listeners.clear();
  }

  // ─── Call Signaling ───────────────────────────────────────────────────────
  static void sendCallOffer(String targetUid, Map<String, dynamic> sdp,
          {bool isVideo = false}) =>
      send({
        'type': 'call_offer',
        'targetUid': targetUid,
        'sdp': sdp,
        'callType': isVideo ? 'video' : 'voice'
      });

  static void sendCallAnswer(String targetUid, Map<String, dynamic> sdp) =>
      send({'type': 'call_answer', 'targetUid': targetUid, 'sdp': sdp});

  static void sendIceCandidate(
          String targetUid, Map<String, dynamic> candidate) =>
      send({'type': 'call_ice', 'targetUid': targetUid, 'candidate': candidate});

  static void sendCallEnd(String targetUid) =>
      send({'type': 'call_end', 'targetUid': targetUid});

  static void sendCallReject(String targetUid) =>
      send({'type': 'call_reject', 'targetUid': targetUid});

  static void sendScreenShareOffer(String targetUid) =>
      send({'type': 'screen_share_offer', 'targetUid': targetUid});

  // ─── Listen Together Signaling ────────────────────────────────────────────
  static void sendLTInvite(String targetUid, String sessionId) =>
      send({'type': 'lt_invite', 'targetUid': targetUid, 'sessionId': sessionId});

  static void sendLTAccept(String targetUid, String sessionId) =>
      send({'type': 'lt_accept', 'targetUid': targetUid, 'sessionId': sessionId});

  static void sendLTReject(String targetUid, String sessionId) =>
      send({'type': 'lt_reject', 'targetUid': targetUid, 'sessionId': sessionId});

  static void sendLTPlay(String targetUid, String sessionId, int positionMs) =>
      send({
        'type': 'lt_play',
        'targetUid': targetUid,
        'sessionId': sessionId,
        'positionMs': positionMs
      });

  static void sendLTPause(String targetUid, String sessionId, int positionMs) =>
      send({
        'type': 'lt_pause',
        'targetUid': targetUid,
        'sessionId': sessionId,
        'positionMs': positionMs
      });

  static void sendLTSeek(String targetUid, String sessionId, int positionMs) =>
      send({
        'type': 'lt_seek',
        'targetUid': targetUid,
        'sessionId': sessionId,
        'positionMs': positionMs
      });

  static void sendLTNext(String targetUid, String sessionId, int index) =>
      send({
        'type': 'lt_next',
        'targetUid': targetUid,
        'sessionId': sessionId,
        'index': index
      });

  static void sendLTEnd(String targetUid, String sessionId) =>
      send({'type': 'lt_end', 'targetUid': targetUid, 'sessionId': sessionId});

  // ─── Typing Indicator ─────────────────────────────────────────────────────
  static void sendTyping(String targetUid, {bool isTyping = true}) =>
      send({
        'type': isTyping ? 'typing_start' : 'typing_stop',
        'targetUid': targetUid
      });
}
