import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ReminderService {
  ReminderService(this._notifications);

  final FlutterLocalNotificationsPlugin _notifications;

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _notifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
  }

  Future<String> scheduleInMinutes(int minutes) async {
    Future<void>.delayed(Duration(minutes: minutes), () async {
      await _notifications.show(
        1001,
        'Círculo Dorado',
        'Momento de continuar tu clase y registrar progreso.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'fcd-reminders',
            'Recordatorios',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    });

    return 'Recordatorio activado para revisar en $minutes minuto(s).';
  }
}
