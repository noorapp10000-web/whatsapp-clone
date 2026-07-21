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

  // Event listeners map: event-type → list of callbacks
  static final Map<String, List<Function(Map<String, dynamic>)>> _listeners =
      {};

  static bool get isConnected => _connected;

  /// Register a callback for a specific WebSocket event type.
  static void on(String event, Function(Map<String, dynamic>) callback) {
    _listeners.putIfAbsent(event, () => []).add(callback);
  }

  /// Remove a specific callback for an event type.
  static void off(String event, Function(Map<String, dynamic>) callback) {
    _listeners[event]?.remove(callback);
  }

  static void _dispatch(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    if (type == null) return;
    // Normalise underscore vs hyphen (server uses underscores, screens may use hyphens)
    final normalised = type.replaceAll('_', '-');
    for (final key in [type, normalised]) {
      final callbacks = List<Function(Map<String, dynamic>)>.from(
          _listeners[key] ?? []);
      for (final cb in callbacks) {
        cb(msg);
      }
    }
  }

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
            _dispatch(msg);
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
    _listeners.clear();
  }

  // ─── Typed senders ────────────────────────────────────────────────────────
  static void sendTyping(int conversationId, [int? targetUserId]) {
    send({'type': 'typing', 'conversationId': conversationId});
  }

  static void markRead(int messageId, int conversationId) {
    send({
      'type': 'message_read',
      'messageId': messageId,
      'conversationId': conversationId
    });
  }

  static void sendCallOffer(int targetUserId, Map<String, dynamic> sdp) {
    send({'type': 'call_offer', 'targetUserId': targetUserId, 'sdp': sdp});
  }

  static void sendCallAnswer(int targetUserId, Map<String, dynamic> sdp) {
    send({'type': 'call_answer', 'targetUserId': targetUserId, 'sdp': sdp});
  }

  static void sendIceCandidate(int targetUserId, Map<String, dynamic> candidate) {
    send({
      'type': 'call_ice',
      'targetUserId': targetUserId,
      'candidate': candidate
    });
  }

  static void sendCallEnd(int targetUserId) {
    send({'type': 'call_end', 'targetUserId': targetUserId});
  }

  /// Alias for [sendCallEnd] — kept for backwards compatibility.
  static void endCall(int targetUserId) => sendCallEnd(targetUserId);

  static void sendCallReject(int targetUserId) {
    send({'type': 'call_reject', 'targetUserId': targetUserId});
  }

  /// Alias for [sendCallReject] — kept for backwards compatibility.
  static void rejectCall(int targetUserId) => sendCallReject(targetUserId);

  static void sendScreenShareOffer(
      int targetUserId, Map<String, dynamic> data) {
    send({
      'type': 'call_offer',
      'targetUserId': targetUserId,
      'sdp': data,
      'isScreenShare': true,
    });
  }
}
