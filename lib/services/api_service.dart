import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  static const String _base = 'https://wa-clone-976d4-production.up.railway.app/api';

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    try {
      final r = await http
          .post(Uri.parse('$_base$path'),
              headers: await _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
      final decoded = jsonDecode(r.body);
      if (r.statusCode >= 400) {
        throw Exception(decoded['error'] ?? 'HTTP ${r.statusCode}');
      }
      return decoded;
    } catch (e) {
      rethrow;
    }
  }

  static Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final r = await http
        .put(Uri.parse('$_base$path'),
            headers: await _headers(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    final decoded = jsonDecode(r.body);
    if (r.statusCode >= 400) throw Exception(decoded['error'] ?? 'HTTP ${r.statusCode}');
    return decoded;
  }

  static Future<dynamic> _get(String path) async {
    final r = await http
        .get(Uri.parse('$_base$path'), headers: await _headers())
        .timeout(const Duration(seconds: 30));
    final decoded = jsonDecode(r.body);
    if (r.statusCode >= 400) throw Exception(decoded['error'] ?? 'HTTP ${r.statusCode}');
    return decoded;
  }

  static Future<dynamic> _delete(String path) async {
    final r = await http
        .delete(Uri.parse('$_base$path'), headers: await _headers())
        .timeout(const Duration(seconds: 30));
    final decoded = jsonDecode(r.body);
    if (r.statusCode >= 400) throw Exception(decoded['error'] ?? 'HTTP ${r.statusCode}');
    return decoded;
  }

  // ─── Auth ──────────────────────────────────────────────────────────────────
  static Future<dynamic> login({
    String? displayName,
    String? email,
    String? photoUrl,
    String? fcmToken,
  }) =>
      _post('/auth/login', {
        if (displayName != null) 'displayName': displayName,
        if (email != null) 'email': email,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (fcmToken != null) 'fcmToken': fcmToken,
      });

  static Future<dynamic> logout() => _post('/auth/logout', {});

  // ─── Users ─────────────────────────────────────────────────────────────────
  static Future<dynamic> getMe() => _get('/users/me');

  static Future<dynamic> updateProfile({
    String? displayName,
    String? status,
    String? photoUrl,
    String? fcmToken,
    String? phone,
  }) =>
      _put('/users/me', {
        if (displayName != null) 'displayName': displayName,
        if (status != null) 'status': status,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (fcmToken != null) 'fcmToken': fcmToken,
        if (phone != null) 'phone': phone,
      });

  static Future<dynamic> searchUsers(String q) =>
      _get('/users/search?q=${Uri.encodeComponent(q)}');

  static Future<dynamic> getUser(String uid) => _get('/users/$uid');

  // ─── Upload ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> uploadFile({
    required String base64,
    required String mimeType,
    required String fileName,
  }) async {
    final result = await _post('/upload/base64', {
      'base64': base64,
      'mimeType': mimeType,
      'fileName': fileName,
    });
    return result as Map<String, dynamic>;
  }

  // ─── FCM ───────────────────────────────────────────────────────────────────
  static Future<dynamic> sendPushNotification({
    required String targetUid,
    required String title,
    String? body,
    Map<String, dynamic>? data,
  }) =>
      _post('/fcm/send', {
        'targetUid': targetUid,
        'title': title,
        if (body != null) 'body': body,
        if (data != null) 'data': data,
      });

  // ─── Contacts ──────────────────────────────────────────────────────────────

  /// Get all accepted contacts
  static Future<dynamic> getContacts() => _get('/contacts');

  /// Get pending incoming contact requests
  static Future<dynamic> getContactRequests() => _get('/contacts/requests');

  /// Check contact-request status with a specific user
  /// Returns: { status: 'none'|'pending'|'accepted'|'rejected', direction: 'sent'|'received', requestId? }
  static Future<Map<String, dynamic>> getContactStatus(String uid) async {
    try {
      final res = await _get('/contacts/status/$uid');
      return Map<String, dynamic>.from(res as Map);
    } catch (_) {
      return {'status': 'none'};
    }
  }

  /// Send a contact request to uid
  static Future<dynamic> sendContactRequest(String uid) =>
      _post('/contacts/request/$uid', {});

  /// Accept a contact request from uid
  static Future<dynamic> acceptContactRequest(String uid) =>
      _post('/contacts/accept/$uid', {});

  /// Reject a contact request from uid
  static Future<dynamic> rejectContactRequest(String uid) =>
      _post('/contacts/reject/$uid', {});

  /// Remove a contact
  static Future<dynamic> removeContact(String uid) => _delete('/contacts/$uid');
}
