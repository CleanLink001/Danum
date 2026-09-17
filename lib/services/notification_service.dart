import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'web_helper.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (kIsWeb) {
      // Request HTML5 Browser Notification Permission inside Chrome via safe web helper
      webEval("""
        if ('Notification' in window) {
          if (Notification.permission !== 'granted' && Notification.permission !== 'denied') {
            Notification.requestPermission();
          }
        }
      """);
      return;
    }

    // Android/iOS initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(settings: initializationSettings);
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) {
      webEval("""
        if ('Notification' in window) {
          Notification.requestPermission();
        }
      """);
      return true;
    }

    final androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      return granted ?? true;
    }
    return true;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) {
      // Trigger Native Web Browser Notification in Chrome via safe web helper
      webEval("""
        if ('Notification' in window && Notification.permission === 'granted') {
          new Notification('${title.replaceAll("'", "\\'")}', {
            body: '${body.replaceAll("'", "\\'")}',
            icon: 'favicon.png'
          });
        } else {
          console.log('Browser notifications not allowed or supported.');
        }
      """);
      return;
    }

    // Mobile implementation
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'water_alerts',
      'Water Quality Alerts',
      channelDescription: 'Notifications for critical water quality levels',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }
}
