import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'auth_service.dart';

class WebSocketService {
  // ⚠️ This URL is replaced automatically by GitHub Actions CI/CD
  // using the BACKEND_WS_URL secret. Do not change this placeholder.
  static const String _wsBase = 'wss://YOUR_REPLIT_BACKEND_URL/ws';

  static WebSocketChannel? _channel;
  static StreamController<Map<String, dynamic>>? _controller;
  static bool _connected = false;
  static Timer? _reconnectTimer;

  static Stream<Map<String, dynamic>>? get stream => _controller?.stream;
  static bool get isConnected => _connected;

  static Future<void> connect() async {
    if (_connected) return;

    final token = await AuthService.getIdToken();
    if (token == null) return;

    _controller ??= StreamController<Map<String, dynamic>>.broadcast();

    try {
      final uri = Uri.parse('$_wsBase?token=${Uri.encodeComponent(token)}');
      _channel = WebSocketChannel.connect(uri);
      _connected = true;

      _channel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            _controller?.add(msg);
          } catch (_) {}
        },
        onError: (e) {
          _connected = false;
          _scheduleReconnect();
        },
        onDone: () {
          _connected = false;
          _scheduleReconnect();
        },
      );
    } catch (e) {
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
    _channel?.sink.close();
    _channel = null;
    _connected = false;
  }

  // ─── Typed senders ────────────────────────────────────────────────────────
  static void sendTyping(int conversationId) {
    send({'type': 'typing', 'conversationId': conversationId});
  }

  static void markRead(int messageId, int conversationId) {
    send({'type': 'message_read', 'messageId': messageId, 'conversationId': conversationId});
  }

  static void sendCallOffer(int targetUserId, Map<String, dynamic> sdp) {
    send({'type': 'call_offer', 'targetUserId': targetUserId, 'sdp': sdp});
  }

  static void sendCallAnswer(int targetUserId, Map<String, dynamic> sdp) {
    send({'type': 'call_answer', 'targetUserId': targetUserId, 'sdp': sdp});
  }

  static void sendIceCandidate(int targetUserId, Map<String, dynamic> candidate) {
    send({'type': 'call_ice', 'targetUserId': targetUserId, 'candidate': candidate});
  }

  static void endCall(int targetUserId) {
    send({'type': 'call_end', 'targetUserId': targetUserId});
  }

  static void rejectCall(int targetUserId) {
    send({'type': 'call_reject', 'targetUserId': targetUserId});
  }
}
