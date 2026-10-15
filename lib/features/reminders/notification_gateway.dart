import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationPermissionState {
  const NotificationPermissionState(
      {required this.enabled, required this.exact, this.sound = true});
  final bool enabled;
  final bool exact;
  final bool sound;
}

abstract class NotificationGateway {
  Future<void> initialize(void Function(String) onTap);
  Future<String> deviceTimeZone();
  Future<NotificationPermissionState> permissions();
  Future<void> requestNotifications();
  Future<void> requestExact();
  Future<void> openSettings();
  Future<Set<int>> pendingIds();
  Future<void> cancel(int id);
  Future<void> schedule(int id, String title, String body, String? payload,
      tz.TZDateTime instant, bool exact);
  Future<void> showTest();
  Future<String?> launchActivity();
}

class AndroidNotificationGateway implements NotificationGateway {
  final plugin = FlutterLocalNotificationsPlugin();
  static const platform = MethodChannel('miagenda/platform');
  AndroidFlutterLocalNotificationsPlugin? get android =>
      plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  static const details = NotificationDetails(
      android: AndroidNotificationDetails(
    'agenda_reminders_v1',
    'Avisos de Mi Agenda',
    channelDescription: 'Recordatorios de tus actividades',
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_notification',
    playSound: true,
    enableVibration: true,
    visibility: NotificationVisibility.private,
  ));

  @override
  Future<void> initialize(void Function(String) onTap) async {
    await plugin.initialize(
        const InitializationSettings(
            android: AndroidInitializationSettings('ic_notification')),
        onDidReceiveNotificationResponse: (response) {
      if (response.payload?.isNotEmpty == true) {
        onTap(response.payload!);
      }
    });
    await android?.createNotificationChannel(const AndroidNotificationChannel(
        'agenda_reminders_v1', 'Avisos de Mi Agenda',
        description: 'Recordatorios de tus actividades',
        importance: Importance.high,
        playSound: true,
        enableVibration: true));
  }

  @override
  Future<String> deviceTimeZone() async =>
      (await platform.invokeMethod<String>('timeZone'))!;
  @override
  Future<NotificationPermissionState> permissions() async {
    final channels = await android?.getNotificationChannels() ??
        <AndroidNotificationChannel>[];
    final ours = channels.where((c) => c.id == 'agenda_reminders_v1');
    return NotificationPermissionState(
        enabled: (await android?.areNotificationsEnabled() ?? false) &&
            !ours.any((c) => c.importance == Importance.none),
        exact: await android?.canScheduleExactNotifications() ?? false,
        sound: !ours.any((c) => !c.playSound));
  }

  @override
  Future<void> requestNotifications() async {
    await android?.requestNotificationsPermission();
  }

  @override
  Future<void> requestExact() async {
    await android?.requestExactAlarmsPermission();
  }

  @override
  Future<void> openSettings() async {
    await platform.invokeMethod<void>('notificationSettings');
  }

  @override
  Future<Set<int>> pendingIds() async =>
      (await plugin.pendingNotificationRequests()).map((r) => r.id).toSet();
  @override
  Future<void> cancel(int id) => plugin.cancel(id);
  @override
  Future<void> schedule(int id, String title, String body, String? payload,
          tz.TZDateTime instant, bool exact) =>
      plugin.zonedSchedule(id, title, body, instant, details,
          payload: payload,
          androidScheduleMode: exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle);
  @override
  Future<void> showTest() => plugin.show(0, 'Aviso de prueba',
      'Los avisos de Mi Agenda están habilitados.', details);
  @override
  Future<String?> launchActivity() async =>
      (await plugin.getNotificationAppLaunchDetails())
          ?.notificationResponse
          ?.payload;
}
