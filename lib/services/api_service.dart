import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  // ⚠️ This URL is replaced automatically by GitHub Actions CI/CD
  // using the BACKEND_URL secret. Do not change this placeholder.
  static const String baseUrl = 'https://YOUR_REPLIT_BACKEND_URL/api';

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
    if (res.body.isEmpty) {
      if (res.statusCode >= 200 && res.statusCode < 300) return {};
      throw Exception('Request failed: ${res.statusCode}');
    }
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
  static Future<dynamic> searchUsers(String q) => get('/users/search?q=${Uri.encodeComponent(q)}');
  static Future<dynamic> getContacts() => get('/contacts');
  static Future<dynamic> addContact(int contactUserId) =>
      post('/contacts', {'contactUserId': contactUserId});

  // ─── Conversations ────────────────────────────────────────────────────────
  static Future<dynamic> getConversations() => get('/conversations');

  static Future<dynamic> createConversation({
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
  static Future<dynamic> getMessages(int conversationId, {String? before}) =>
      get('/conversations/$conversationId/messages${before != null ? '?before=${Uri.encodeComponent(before)}' : ''}');

  static Future<dynamic> sendMessage(
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

  // ─── Upload ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> uploadFile(File file, String mimeType) async {
    final token = await AuthService.getIdToken();
    final uri = Uri.parse('$baseUrl/upload');
    final request = http.MultipartRequest('POST', uri);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', file.path,
        filename: file.path.split('/').last));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }
}
