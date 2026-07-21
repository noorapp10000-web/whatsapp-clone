import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  // Replace with your Replit backend URL after deployment
  static const String baseUrl = 'https://d544ccf9-9d94-4f47-8a3e-a2b8370cf984-00-rqrek6rd6068.janeway.replit.dev/api';

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> get(String path) async {
    final res = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    );
    return _handle(res);
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _handle(res);
  }

  static Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _handle(res);
  }

  static Future<dynamic> delete(String path) async {
    final res = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    );
    return _handle(res);
  }

  static dynamic _handle(http.Response res) {
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body['error'] ?? 'Request failed: ${res.statusCode}');
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login({
    required String displayName,
    required String email,
    String? photoUrl,
    String? fcmToken,
  }) async {
    return await post('/auth/login', {
      'displayName': displayName,
      'email': email,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (fcmToken != null) 'fcmToken': fcmToken,
    });
  }

  // ─── Users ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getMe() => get('/users/me');
  static Future<Map<String, dynamic>> searchUsers(String q) =>
      get('/users/search?q=$q');
  static Future<Map<String, dynamic>> getContacts() => get('/contacts');
  static Future<Map<String, dynamic>> addContact(int contactUserId) =>
      post('/contacts', {'contactUserId': contactUserId});

  // ─── Conversations ────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getConversations() =>
      get('/conversations');

  static Future<Map<String, dynamic>> createConversation({
    required String type,
    required List<int> participantIds,
    String? name,
  }) =>
      post('/conversations', {
        'type': type,
        'participantIds': participantIds,
        if (name != null) 'name': name,
      });

  // ─── Messages ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getMessages(int conversationId,
          {String? before}) =>
      get('/conversations/$conversationId/messages${before != null ? '?before=$before' : ''}');

  static Future<Map<String, dynamic>> sendMessage(
    int conversationId, {
    String type = 'text',
    String? content,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? mimeType,
    int? replyToId,
  }) =>
      post('/conversations/$conversationId/messages', {
        'type': type,
        if (content != null) 'content': content,
        if (fileUrl != null) 'fileUrl': fileUrl,
        if (fileName != null) 'fileName': fileName,
        if (fileSize != null) 'fileSize': fileSize,
        if (mimeType != null) 'mimeType': mimeType,
        if (replyToId != null) 'replyToId': replyToId,
      });

  static Future<dynamic> deleteMessage(int messageId) =>
      delete('/messages/$messageId');

  // ─── Upload ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> uploadFile({
    required String base64,
    String? mimeType,
    String? fileName,
  }) =>
      post('/upload', {
        'base64': base64,
        if (mimeType != null) 'mimeType': mimeType,
        if (fileName != null) 'fileName': fileName,
      });

  // ─── Calls ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> initiateCall({
    required int receiverId,
    required String type,
    int? conversationId,
  }) =>
      post('/calls/initiate', {
        'receiverId': receiverId,
        'type': type,
        if (conversationId != null) 'conversationId': conversationId,
      });

  static Future<Map<String, dynamic>> updateCallStatus(
          int callId, String status) =>
      put('/calls/$callId/status', {'status': status});

  static Future<Map<String, dynamic>> getCallHistory() => get('/calls/history');
}
