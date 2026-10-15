import 'dart:convert';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'dart:io';
import 'package:mi_agenda/core/database/app_database.dart';
import 'package:mi_agenda/features/activities/activity.dart';
import 'package:mi_agenda/features/activities/activity_repository.dart';
import 'package:mi_agenda/features/backup/agenda_backup.dart';

Future<Uint8List> legacyBackup() async {
  final folder = await Directory.systemTemp.createTemp('backup_fixture_');
  try {
    final file = File('${folder.path}/legacy.sqlite');
    final db = sql.sqlite3.open(file.path);
    db.execute(
        'CREATE TABLE activities (id TEXT PRIMARY KEY, title TEXT NOT NULL, category TEXT NOT NULL, local_date TEXT NOT NULL, minute_of_day INTEGER, notes TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)');
    db.execute(
        'CREATE TABLE task_templates (id TEXT PRIMARY KEY, activity_id TEXT NOT NULL REFERENCES activities(id), description TEXT NOT NULL, sort_order INTEGER NOT NULL, is_done INTEGER NOT NULL)');
    db.execute(
        "INSERT INTO activities VALUES ('legacy', 'Actividad original', 'work', '2026-10-20', 600, 'Nota sin recortar  ', 123, 456)");
    db.execute(
        "INSERT INTO task_templates VALUES ('task', 'legacy', 'Tarea original', 0, 1)");
    db.execute('PRAGMA user_version=1');
    db.dispose();
    return await file.readAsBytes();
  } finally {
    await folder.delete(recursive: true);
  }
}

void main() {
  test(
      'TXT completo de aShell restaura v1 conservando IDs, notas, horas y estados',
      () async {
    final bytes = await legacyBackup();
    final text =
        '\$ id\nuid=2000(shell)\n\$ run-as com.miagenda.local base64 files/mi_agenda.sqlite\n${base64Encode(bytes)}\n';
    final backup =
        await AgendaBackup.inspect(Uint8List.fromList(utf8.encode(text)));
    final dest = ActivityRepository(AppDatabase(NativeDatabase.memory()));
    try {
      expect(backup.activities, 1);
      expect(backup.tasks, 1);
      await backup.restoreIntoEmpty(dest);
      final activity = (await dest.getAll()).single;
      expect(activity.id, 'legacy');
      expect(activity.notes, 'Nota sin recortar  ');
      expect(activity.minuteOfDay, 600);
      expect(activity.tasks.single.isDone, true);
      final row = await dest.db
          .customSelect('SELECT created_at, updated_at FROM activities')
          .getSingle();
      expect(row.read<int>('created_at'), 123);
      expect(row.read<int>('updated_at'), 456);
      expect(activity.reminderOffsets, isEmpty);
      // Restaurar dos veces no duplica ni reemplaza los datos.
      await expectLater(backup.restoreIntoEmpty(dest), throwsStateError);
      expect(await dest.getAll(), hasLength(1));
    } finally {
      await backup.close();
      await dest.close();
    }
  });
  test('Rechaza texto truncado o no SQLite sin escribir en la agenda',
      () async {
    await expectLater(
        AgendaBackup.inspect(
            Uint8List.fromList(utf8.encode('archivo inválido'))),
        throwsFormatException);
    final data = await legacyBackup();
    await expectLater(
        AgendaBackup.inspect(data.sublist(0, 120)), throwsA(anything));
    await expectLater(
        AgendaBackup.inspect(Uint8List(0)), throwsFormatException);
  });
  test(
      'Una agenda ocupada conserva todas sus actividades al rechazar restauración',
      () async {
    final backup = await AgendaBackup.inspect(await legacyBackup());
    final dest = ActivityRepository(AppDatabase(NativeDatabase.memory()));
    try {
      await dest.save(Activity(
          id: 'existing',
          title: 'Conservar',
          category: ActivityCategory.personal,
          date: DateTime(2026, 10, 21)));
      await expectLater(backup.restoreIntoEmpty(dest), throwsStateError);
      expect((await dest.getAll()).single.id, 'existing');
    } finally {
      await backup.close();
      await dest.close();
    }
  });
  test(
      'Exportación consistente de v2 conserva avisos y puede volver a importarse',
      () async {
    final source = ActivityRepository(AppDatabase(NativeDatabase.memory()));
    final dest = ActivityRepository(AppDatabase(NativeDatabase.memory()));
    try {
      await source.save(Activity(
          id: 'new',
          title: 'Aviso',
          category: ActivityCategory.work,
          date: DateTime(2026, 11, 20),
          minuteOfDay: 540,
          timeZoneId: 'UTC',
          reminderOffsets: [0, 15]));
      final backup =
          await AgendaBackup.inspect(await AgendaBackup.export(source));
      try {
        await backup.restoreIntoEmpty(dest);
        expect((await dest.getAll()).single.reminderOffsets, [0, 15]);
        expect(
            await dest.db
                .customSelect('SELECT * FROM notification_registry')
                .get(),
            isEmpty);
        expect(await source.getAll(), hasLength(1));
      } finally {
        await backup.close();
      }
    } finally {
      await source.close();
      await dest.close();
    }
  });
}
