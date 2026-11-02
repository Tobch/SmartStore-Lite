import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(initSettings);
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidDetails(
      'smartstore_channel',
      'SmartStore Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _notifications.show(id, title, body, details);
  }
}

class AndroidDetails extends AndroidNotificationDetails {
  const AndroidDetails(super.channelId, super.channelName, {super.importance, super.priority});
}