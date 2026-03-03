import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  static Future<void> showAwaitingPickup(
    String robotName,
    String robotId,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'awaiting_pickup',
      'Awaiting Pickup',
      channelDescription: 'Notifies when a robot is ready for collection',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      robotId.hashCode,
      '🤖 Robot ready for pickup!',
      '$robotName has finished cleaning. Time to collect!',
      details,
    );
  }
}