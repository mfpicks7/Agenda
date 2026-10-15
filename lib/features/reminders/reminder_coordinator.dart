import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../activities/activity.dart';
import '../activities/activity_repository.dart';
import 'notification_gateway.dart';
import 'reminder_plan.dart';

class ReminderCoordinator extends ChangeNotifier {
  ReminderCoordinator(this.repository, this.gateway,
      {DateTime Function()? clock})
      : clock = clock ?? DateTime.now;
  final ActivityRepository repository;
  final NotificationGateway gateway;
  final DateTime Function() clock;
  NotificationPermissionState permission =
      const NotificationPermissionState(enabled: false, exact: false);
  String? warning;
  String? deviceZone;
  int scheduledCount = 0;
  bool initialized = false;
  bool _disposed = false;
  Future<void>? _initializing;
  Future<void> _queue = Future.value();
  void Function(String)? onTap;

  void _changed() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    try {
      tzdata.initializeTimeZones();
      await gateway.initialize((id) => onTap?.call(id));
      final nativeZone = await gateway.deviceTimeZone();
      deviceZone = canonicalReminderZone(nativeZone);
      reminderLocation(
          deviceZone!); // No sustituir silenciosamente una zona desconocida por UTC.
      initialized = true;
    } catch (_) {
      _initializing = null;
      warning =
          'No pudimos iniciar los avisos. Abre Avisos e inténtalo de nuevo.';
      _changed();
      rethrow;
    }
  }

  Future<Activity> prepare(Activity activity) async {
    if (activity.reminderOffsets.isEmpty) {
      return activity;
    }
    await initialize();
    final zoned = activity.withTimeZone(activity.timeZoneId ?? deviceZone!);
    resolveCivil(zoned);
    return zoned;
  }

  Future<void> requestNotifications() async {
    await initialize();
    await gateway.requestNotifications();
    await synchronize();
  }

  Future<void> requestExact() async {
    await initialize();
    await gateway.requestExact();
    await synchronize();
  }

  Future<void> synchronize() {
    final done = Completer<void>();
    _queue = _queue.then((_) async {
      try {
        await _synchronize();
      } catch (_) {
        scheduledCount = 0;
        warning =
            'Algunos avisos no se pudieron programar. Revisa permisos y vuelve a sincronizar.';
        _changed();
      } finally {
        done.complete();
      }
    });
    return done.future;
  }

  Future<void> _synchronize() async {
    await initialize();
    permission = await gateway.permissions();
    final all = await repository.getAll();
    final hasReminders = all.any((a) => a.reminderOffsets.isNotEmpty);
    final plans = planReminders(all, clock());
    final wanted = <int, PlannedReminder>{};
    await repository.db.transaction(() async {
      for (final plan in plans) {
        await repository.db.customStatement(
            '''INSERT INTO notification_registry
          (activity_id, offset_minutes, scheduled_utc) VALUES (?, ?, ?)
          ON CONFLICT(activity_id, offset_minutes) DO UPDATE SET scheduled_utc=excluded.scheduled_utc''',
            [
              plan.activity.id,
              plan.offset,
              plan.instant.millisecondsSinceEpoch
            ]);
        final rows = await repository.db
            .customSelect(
                'SELECT notification_id, activity_id, offset_minutes FROM notification_registry')
            .get();
        final record = rows.firstWhere((r) =>
            r.read<String>('activity_id') == plan.activity.id &&
            r.read<int>('offset_minutes') == plan.offset);
        wanted[record.read<int>('notification_id')] = plan;
      }
    });
    final pending = await gateway.pendingIds();
    for (final id in pending.where(
        (id) => id != 0 && (!wanted.containsKey(id) || !permission.enabled))) {
      await gateway.cancel(id);
    }
    final registry = await repository.db
        .customSelect('SELECT notification_id FROM notification_registry')
        .get();
    for (final record in registry) {
      final id = record.read<int>('notification_id');
      if (!wanted.containsKey(id)) {
        await repository.db.customStatement(
            'DELETE FROM notification_registry WHERE notification_id = ?',
            [id]);
      }
    }
    scheduledCount = 0;
    var failed = 0;
    if (permission.enabled) {
      for (final entry in wanted.entries) {
        final plan = entry.value;
        try {
          await gateway.schedule(
              entry.key,
              plan.activity.title,
              '${plan.activity.timeLabel} · ${plan.activity.category.label}',
              plan.activity.id,
              plan.instant,
              permission.exact);
          scheduledCount++;
        } catch (_) {
          await gateway.cancel(entry.key);
          failed++;
        }
      }
    }
    warning = !permission.enabled && hasReminders
        ? 'Notificaciones bloqueadas: las actividades se guardaron, pero no recibirás avisos hasta permitirlas.'
        : failed > 0
            ? '$failed aviso(s) no se pudieron programar. Vuelve a sincronizar o reduce los avisos.'
            : !permission.exact && wanted.isNotEmpty
                ? 'Avisos con horario aproximado: Android puede retrasarlos. Activa la precisión en Avisos.'
                : null;
    _changed();
  }

  Future<void> showTest() async {
    await initialize();
    permission = await gateway.permissions();
    if (!permission.enabled) {
      throw StateError('Permite las notificaciones antes de probar.');
    }
    await gateway.showTest();
  }

  Future<void> scheduleTest() async {
    await initialize();
    permission = await gateway.permissions();
    if (!permission.enabled || !permission.exact) {
      throw StateError(
          'Permite notificaciones y precisión para la prueba de 10 segundos.');
    }
    final time = tz.TZDateTime.from(clock().add(const Duration(seconds: 10)),
        reminderLocation(deviceZone!));
    await gateway.schedule(0, 'Aviso programado de prueba',
        'La programación local de Mi Agenda funciona.', null, time, true);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
