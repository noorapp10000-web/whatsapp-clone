import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static late FlutterLocalNotificationsPlugin _plugin;

  static Future<void> init(FlutterLocalNotificationsPlugin plugin) async {
    _plugin = plugin;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    // Request permission
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground notifications
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        _showLocal(
          title: notification.title ?? 'New Message',
          body: notification.body ?? '',
        );
      }
    });
  }

  static Future<void> _showLocal({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'whatsapp_clone_channel',
      'Messages',
      channelDescription: 'Message notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
    );
  }
}
