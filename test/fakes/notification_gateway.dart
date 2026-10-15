import 'package:timezone/timezone.dart' as tz;
import 'package:mi_agenda/features/reminders/notification_gateway.dart';

class FakeGateway implements NotificationGateway {
  String zone = 'America/New_York';
  bool enabled = true;
  bool exact = true;
  bool fail = false;
  final scheduled = <int, tz.TZDateTime>{};
  final modes = <bool>[];
  final cancelled = <int>[];
  @override
  Future<void> initialize(void Function(String) callback) async {}
  @override
  Future<String> deviceTimeZone() async => zone;
  @override
  Future<NotificationPermissionState> permissions() async =>
      NotificationPermissionState(enabled: enabled, exact: exact);
  @override
  Future<void> requestNotifications() async {}
  @override
  Future<void> requestExact() async {}
  @override
  Future<void> openSettings() async {}
  @override
  Future<Set<int>> pendingIds() async => scheduled.keys.toSet();
  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }

  @override
  Future<void> schedule(int id, String title, String body, String? payload,
      tz.TZDateTime instant, bool exact) async {
    if (fail) {
      throw StateError('Fallo de plataforma');
    }
    scheduled[id] = instant;
    modes.add(exact);
  }

  @override
  Future<void> showTest() async {}
  @override
  Future<String?> launchActivity() async => null;
}
