import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init({void Function(NotificationResponse)? onTap}) async {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: onTap,
    );

    const channel = AndroidNotificationChannel(
      'vidalis_uploads',
      'Subidas de Video',
      description: 'Notificaciones cuando un video termina de subirse',
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> notifyUploadComplete(String? title) async {
    const androidDetails = AndroidNotificationDetails(
      'vidalis_uploads',
      'Subidas de Video',
      channelDescription: 'Notificaciones cuando un video termina de subirse',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    await _plugin.show(
      0,
      '¡Video subido exitosamente!',
      title != null
          ? '"$title" ya está listo para publicar.'
          : 'Tu video está listo para publicar.',
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }
}
