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

  Future<void> notifyUploadStarted(String? title) async {
    const androidDetails = AndroidNotificationDetails(
      'vidalis_uploads',
      'Subidas de Video',
      channelDescription: 'Notificaciones cuando un video termina de subirse',
      importance: Importance.low,
      priority: Priority.low,
      icon: '@mipmap/launcher_icon',
      ongoing: true,
      autoCancel: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: false,
    );

    await _plugin.show(
      0,
      'Subiendo video...',
      title != null 
          ? '"$title" está en proceso. Por favor, no cierres la app.' 
          : 'Por favor, no cierres la app.',
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  Future<void> notifyUploadFailed(String? title, String error) async {
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
      'Fallo al subir video',
      title != null ? 'Fallo al subir "$title".' : 'Hubo un error al subir.',
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }
}
