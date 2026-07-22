import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  // ⚠️ Replaced by CI/CD via BACKEND_URL secret
  static const String _base = 'https://YOUR_REPLIT_BACKEND_URL/api';

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final r = await http.post(Uri.parse('$_base$path'),
        headers: await _headers(), body: jsonEncode(body));
    return jsonDecode(r.body);
  }

  static Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final r = await http.put(Uri.parse('$_base$path'),
        headers: await _headers(), body: jsonEncode(body));
    return jsonDecode(r.body);
  }

  static Future<dynamic> _get(String path) async {
    final r = await http.get(Uri.parse('$_base$path'), headers: await _headers());
    return jsonDecode(r.body);
  }

  // Auth
  static Future<dynamic> login({String? displayName, String? email, String? photoUrl, String? fcmToken}) =>
      _post('/auth/login', {
        if (displayName != null) 'displayName': displayName,
        if (email       != null) 'email':       email,
        if (photoUrl    != null) 'photoUrl':    photoUrl,
        if (fcmToken    != null) 'fcmToken':    fcmToken,
      });

  static Future<dynamic> logout() => _post('/auth/logout', {});

  // Profile
  static Future<dynamic> getMe() => _get('/users/me');
  static Future<dynamic> updateProfile({String? displayName, String? status, String? photoUrl, String? fcmToken}) =>
      _put('/users/me', {
        if (displayName != null) 'displayName': displayName,
        if (status      != null) 'status':      status,
        if (photoUrl    != null) 'photoUrl':    photoUrl,
        if (fcmToken    != null) 'fcmToken':    fcmToken,
      });

  // Upload
  static Future<dynamic> uploadFile({required String base64, required String mimeType, required String fileName}) =>
      _post('/upload/base64', {'base64': base64, 'mimeType': mimeType, 'fileName': fileName});

  // FCM
  static Future<dynamic> sendNotification({
    required String targetUid,
    required String title,
    String? body,
    Map<String, String>? data,
  }) =>
      _post('/fcm/send', {
        'targetUid': targetUid,
        'title': title,
        if (body != null) 'body': body,
        if (data != null) 'data': data,
      });
}
