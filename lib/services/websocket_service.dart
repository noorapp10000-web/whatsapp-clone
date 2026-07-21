import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'auth_service.dart';

typedef MessageHandler = void Function(Map<String, dynamic> message);

class WebSocketService {
  static const String _wsBaseUrl = 'wss://d544ccf9-9d94-4f47-8a3e-a2b8370cf984-00-rqrek6rd6068.janeway.replit.dev/ws';

  static WebSocketChannel? _channel;
  static StreamSubscription? _subscription;
  static final Map<String, List<MessageHandler>> _handlers = {};
  static Timer? _reconnectTimer;
  static bool _shouldReconnect = true;

  static Future<void> connect() async {
    final token = await AuthService.getIdToken();
    if (token == null) return;

    _shouldReconnect = true;
    _doConnect(token);
  }

  static void _doConnect(String token) {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$_wsBaseUrl?token=$token'),
      );

      _subscription = _channel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            final type = msg['type'] as String?;
            if (type != null && _handlers.containsKey(type)) {
              for (final handler in _handlers[type]!) {
                handler(msg);
              }
            }
          } catch (_) {}
        },
        onDone: _onDisconnect,
        onError: (_) => _onDisconnect(),
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  static void _onDisconnect() {
    if (_shouldReconnect) _scheduleReconnect();
  }

  static void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      final token = await AuthService.getIdToken();
      if (token != null) _doConnect(token);
    });
  }

  static void on(String type, MessageHandler handler) {
    _handlers.putIfAbsent(type, () => []).add(handler);
  }

  static void off(String type, MessageHandler handler) {
    _handlers[type]?.remove(handler);
  }

  static void send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  // ─── Typed senders ────────────────────────────────────────────────────────
  static void sendTyping(int conversationId, int toUserId) {
    send({'type': 'typing', 'conversationId': conversationId, 'toUserId': toUserId});
  }

  static void sendCallOffer(int toUserId, Map<String, dynamic> sdp) {
    send({'type': 'call-offer', 'toUserId': toUserId, 'sdp': sdp});
  }

  static void sendCallAnswer(int toUserId, Map<String, dynamic> sdp) {
    send({'type': 'call-answer', 'toUserId': toUserId, 'sdp': sdp});
  }

  static void sendIceCandidate(int toUserId, Map<String, dynamic> candidate) {
    send({'type': 'call-ice', 'toUserId': toUserId, 'candidate': candidate});
  }

  static void sendCallReject(int toUserId) {
    send({'type': 'call-reject', 'toUserId': toUserId});
  }

  static void sendCallEnd(int toUserId) {
    send({'type': 'call-end', 'toUserId': toUserId});
  }

  static void sendScreenShareOffer(int toUserId, Map<String, dynamic> sdp) {
    send({'type': 'screen-share-offer', 'toUserId': toUserId, 'sdp': sdp});
  }

  static void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
