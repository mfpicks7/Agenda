import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:mi_agenda/core/database/app_database.dart';
import 'package:mi_agenda/features/activities/activity.dart';
import 'package:mi_agenda/features/activities/activity_repository.dart';
import 'fakes/notification_gateway.dart';
import 'package:mi_agenda/features/reminders/reminder_coordinator.dart';
import 'package:mi_agenda/features/reminders/reminder_plan.dart';


Activity event({String id = 'a', DateTime? date, int minute = 600, List<int> offsets = const [0, 15], String? zone = 'America/New_York'}) =>
  Activity(id: id, title: 'Actividad', category: ActivityCategory.work, date: date ?? DateTime(2026, 10, 20),
    minuteOfDay: minute, timeZoneId: zone, reminderOffsets: offsets);

void main() {
  setUpAll(tzdata.initializeTimeZones);
  test('Horario de verano: no normaliza horas inexistentes y elige primer instante ambiguo', () {
    expect(() => resolveCivil(event(date: DateTime(2026, 3, 8), minute: 150)), throwsFormatException);
    expect(resolveCivil(event(date: DateTime(2026, 11, 1), minute: 90)).toUtc(), DateTime.utc(2026, 11, 1, 5, 30));
    expect(resolveCivil(event(date: DateTime(2026, 10, 20), minute: 600)).toUtc(), DateTime.utc(2026, 10, 20, 14));
  });
  test('Avisos pasados no se programan; offsets se restan como duración real', () {
    final plans = planReminders([event()], DateTime.utc(2026, 10, 20, 13, 50));
    expect(plans.length, 1);
    expect(plans.single.offset, 0);
    final allDay = Activity(id: 'day', title: 'Día', category: ActivityCategory.personal, date: DateTime(2026, 10, 20),
      timeZoneId: 'America/New_York', reminderOffsets: [0], allDayReminderMinute: 540);
    expect(resolveCivil(allDay).hour, 9);
  });

  late ActivityRepository repo;
  late FakeGateway gateway;
  late ReminderCoordinator service;
  setUp(() {
    repo = ActivityRepository(AppDatabase(NativeDatabase.memory()));
    gateway = FakeGateway();
    service = ReminderCoordinator(repo, gateway, clock: () => DateTime.utc(2026, 10, 19));
  });
  tearDown(() async { service.dispose(); await repo.close(); });

  test('Persistencia de avisos y IDs estables; editar reprograma y borrar cancela', () async {
    await repo.save(event());
    await service.synchronize();
    expect(gateway.scheduled.length, 2);
    final ids = gateway.scheduled.keys.toSet();
    final times = gateway.scheduled.values.map((t) => t.millisecondsSinceEpoch).toSet();
    await repo.save(event(minute: 660));
    await service.synchronize();
    expect(gateway.scheduled.keys.toSet(), ids);
    expect(gateway.scheduled.values.map((t) => t.millisecondsSinceEpoch).toSet(), isNot(times));
    expect((await repo.getAll()).single.reminderOffsets, [0, 15]);
    await repo.save(event(offsets: [0]));
    await service.synchronize();
    expect(gateway.scheduled.length, 1);
    await repo.delete('a');
    await service.synchronize();
    expect(gateway.scheduled, isEmpty);
    expect(await repo.db.customSelect('SELECT * FROM reminders').get(), isEmpty);
    expect(await repo.db.customSelect('SELECT * FROM notification_registry').get(), isEmpty);
  });
  test('Denegación, alternativa inexacta y recuperación sin perder actividades', () async {
    await repo.save(event());
    gateway.enabled = false;
    await service.synchronize();
    expect(gateway.scheduled, isEmpty);
    expect(service.warning, contains('bloqueadas'));
    gateway.enabled = true;
    gateway.exact = false;
    await service.synchronize();
    expect(gateway.scheduled.length, 2);
    expect(gateway.modes.every((mode) => !mode), isTrue);
    expect(service.warning, contains('aproximado'));
    gateway.enabled = false;
    await service.synchronize();
    expect(gateway.scheduled, isEmpty);
    expect((await repo.getAll()).single.reminderOffsets.length, 2);
    gateway.enabled = true;
    gateway.exact = true;
    await service.synchronize();
    expect(gateway.scheduled.length, 2);
    expect(service.warning, isNull);
  });
  test('Error al programar no se presenta como éxito y elimina el aviso viejo', () async {
    await repo.save(event());
    await service.synchronize();
    gateway.fail = true;
    await service.synchronize();
    expect(service.scheduledCount, 0);
    expect(service.warning, contains('no se pudieron'));
    expect(gateway.scheduled, isEmpty);
  });
  test('Recupera tras reinicio y cancela huérfanos de una eliminación interrumpida', () async {
    await repo.save(event());
    await service.synchronize();
    gateway.scheduled[999] = tz.TZDateTime(tz.UTC, 2026, 10, 20);
    final restarted = ReminderCoordinator(repo, gateway, clock: () => DateTime.utc(2026, 10, 19));
    await restarted.synchronize();
    expect(gateway.cancelled, contains(999));
    expect(gateway.scheduled.length, 2);
    restarted.dispose();
  });
  test('Normaliza GMT a IANA sin sustituir zonas desconocidas', () async {
    for (final alias in ['GMT', 'UTC', 'Etc/UTC', 'Etc/GMT']) {
      expect(reminderLocation(alias), tz.UTC);
      expect(resolveCivil(event(zone: alias)).location, tz.UTC);
    }
    gateway.zone = 'Etc/UTC';
    expect((await service.prepare(event(zone: null))).timeZoneId, 'UTC');
    final invalid = FakeGateway()..zone = 'Invalid/Unknown';
    final broken = ReminderCoordinator(repo, invalid);
    await expectLater(broken.prepare(event(zone: null)), throwsA(anything));
    expect(broken.initialized, isFalse);
    broken.dispose();
  });
  test('Prepara zona del teléfono y valida recordatorios duplicados o excesivos', () async {
    expect((await service.prepare(event(zone: null))).timeZoneId, 'America/New_York');
    expect(event(offsets: [0, 0]).validate(), isNotNull);
    expect(event(offsets: [-1]).validate(), isNotNull);
    expect(event(offsets: List.generate(9, (i) => i)).validate(), isNotNull);
  });
  test('Migración v1 conserva notas, fecha y tareas completadas', () async {
    final folder = await Directory.systemTemp.createTemp('agenda_migration_');
    final path = '${folder.path}/old.sqlite';
    final old = sql.sqlite3.open(path);
    old.execute('CREATE TABLE activities (id TEXT PRIMARY KEY, title TEXT NOT NULL, category TEXT NOT NULL, local_date TEXT NOT NULL, minute_of_day INTEGER, notes TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)');
    old.execute('CREATE TABLE task_templates (id TEXT PRIMARY KEY, activity_id TEXT NOT NULL REFERENCES activities(id) ON DELETE CASCADE, description TEXT NOT NULL, sort_order INTEGER NOT NULL, is_done INTEGER NOT NULL)');
    old.execute("INSERT INTO activities VALUES ('old','Antes','work','2026-10-20',600,'Conservar nota',1,1)");
    old.execute("INSERT INTO task_templates VALUES ('t','old','Completada',0,1)");
    old.execute('PRAGMA user_version = 1');
    old.dispose();
    final migrated = ActivityRepository(AppDatabase(NativeDatabase(File(path))));
    try {
      final loaded = (await migrated.getAll()).single;
      expect(loaded.notes, 'Conservar nota');
      expect(loaded.tasks.single.isDone, isTrue);
      expect(loaded.reminderOffsets, isEmpty);
      expect(loaded.allDayReminderMinute, 540);
      expect(loaded.date, DateTime(2026, 10, 20));
      final configured = Activity(id: loaded.id, title: loaded.title, category: loaded.category, date: loaded.date,
        minuteOfDay: loaded.minuteOfDay, notes: loaded.notes, tasks: loaded.tasks,
        timeZoneId: 'America/New_York', reminderOffsets: [0, 15]);
      await migrated.save(configured);
      expect((await migrated.getAll()).single.reminderOffsets, [0, 15]);
    } finally { await migrated.close(); await folder.delete(recursive: true); }
  });
}
