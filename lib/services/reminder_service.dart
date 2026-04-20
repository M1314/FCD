import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ReminderService {
  ReminderService(this._notifications);

  static const int _maxNotificationId = 0x7fffffff;
  final FlutterLocalNotificationsPlugin _notifications;
  final List<Timer> _timers = [];

  int _nextNotificationId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final entropy = _timers.length;
    final value = (now ^ entropy).remainder(_maxNotificationId);
    return value == 0 ? 1 : value;
  }

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _notifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
  }

  Future<String> scheduleInMinutes(int minutes) async {
    final scheduledId = _nextNotificationId();

    late final Timer timer;
    timer = Timer(Duration(minutes: minutes), () async {
      _timers.remove(timer);
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

    final unit = minutes == 1 ? 'minuto' : 'minutos';
    return 'Recordatorio activado para revisar en $minutes $unit.';
  }

  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }
}
