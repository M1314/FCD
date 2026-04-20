import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ReminderService {
  ReminderService(this._notifications);

  final FlutterLocalNotificationsPlugin _notifications;
  final List<Timer> _timers = [];

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _notifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
  }

  Future<String> scheduleInMinutes(int minutes) async {
    final scheduledId = DateTime.now().millisecondsSinceEpoch.remainder(1 << 20);

    final timer = Timer(Duration(minutes: minutes), () async {
      await _notifications.show(
        scheduledId,
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
    _timers.add(timer);

    return 'Recordatorio activado para revisar en $minutes minuto(s).';
  }

  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }
}
