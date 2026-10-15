import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:drift/native.dart';
import '../activities/activity_repository.dart';
import '../../core/database/app_database.dart';

class AgendaBackup {
  AgendaBackup._(this.repository, this.folder);
  final ActivityRepository repository;
  final Directory folder;
  int get activities => _activities;
  int get tasks => _tasks;
  int _activities = 0;
  int _tasks = 0;

  static Future<AgendaBackup> inspect(Uint8List input) async {
    if (input.isEmpty || input.length > 16 * 1024 * 1024) {
      throw const FormatException('El respaldo está vacío o supera 16 MB.');
    }
    var bytes = input;
    if (!_isSqlite(bytes)) {
      final text = utf8.decode(input);
      const marker = 'run-as com.miagenda.local base64 files/mi_agenda.sqlite';
      final payload =
          (text.contains(marker) ? text.split(marker).last : text).trim();
      if (!RegExp(r'^[A-Za-z0-9+/=\s]+$').hasMatch(payload)) {
        throw const FormatException(
            'No se reconoce el respaldo. Selecciona el TXT original de aShellYou o un archivo SQLite.');
      }
      bytes = base64Decode(payload.replaceAll(RegExp(r'\s'), ''));
    }
    if (!_isSqlite(bytes)) {
      throw const FormatException(
          'El archivo no contiene una base de datos SQLite.');
    }
    final folder = await Directory.systemTemp.createTemp('miagenda_backup_');
    final file = File('${folder.path}/backup.sqlite');
    await file.writeAsBytes(bytes, flush: true);
    final repository = ActivityRepository(AppDatabase(NativeDatabase(file)));
    final backup = AgendaBackup._(repository, folder);
    try {
      // Se migra únicamente esta copia temporal, nunca el documento elegido.
      final db = repository.db;
      final integrity = await db.customSelect('PRAGMA integrity_check').get();
      if (integrity.length != 1 ||
          integrity.single.data.values.single != 'ok') {
        throw const FormatException(
            'El respaldo no superó la comprobación de integridad.');
      }
      if ((await db.customSelect('PRAGMA foreign_key_check').get())
          .isNotEmpty) {
        throw const FormatException(
            'Hay tareas o avisos sin actividad en el respaldo.');
      }
      final all = await repository.getAll();
      if (all.any((a) =>
          a.validate() != null ||
          (a.reminderOffsets.isNotEmpty && a.timeZoneId == null))) {
        throw const FormatException(
            'Hay actividades inválidas en el respaldo.');
      }
      backup._activities = all.length;
      backup._tasks = all.fold(0, (n, a) => n + a.tasks.length);
      return backup;
    } catch (_) {
      await backup.close();
      rethrow;
    }
  }

  static bool _isSqlite(List<int> bytes) =>
      bytes.length >= 100 &&
      ascii.decode(bytes.take(16).toList(), allowInvalid: true) ==
          'SQLite format 3\u0000';

  Future<void> restoreIntoEmpty(ActivityRepository destination) async {
    final records = <String, List<Map<String, Object?>>>{};
    for (final table in ['activities', 'task_templates', 'reminders']) {
      records[table] =
          (await repository.db.customSelect('SELECT * FROM $table').get())
              .map((r) => r.data)
              .toList();
    }
    await destination.db.transaction(() async {
      for (final table in [
        'activities',
        'task_templates',
        'reminders',
        'notification_registry'
      ]) {
        final rows = await destination.db
            .customSelect('SELECT COUNT(*) AS n FROM $table')
            .getSingle();
        if (rows.read<int>('n') != 0) {
          throw StateError(
              'Esta agenda ya contiene datos. No se reemplazó nada.');
        }
      }
      const columns = {
        'activities': [
          'id',
          'title',
          'category',
          'local_date',
          'minute_of_day',
          'notes',
          'created_at',
          'updated_at',
          'time_zone_id',
          'all_day_reminder_minute'
        ],
        'task_templates': [
          'id',
          'activity_id',
          'description',
          'sort_order',
          'is_done'
        ],
        'reminders': ['activity_id', 'offset_minutes'],
      };
      for (final entry in columns.entries) {
        final fields = entry.value;
        for (final row in records[entry.key]!) {
          await destination.db.customStatement(
              'INSERT INTO ${entry.key} (${fields.join(',')}) VALUES (${List.filled(fields.length, '?').join(',')})',
              fields.map((f) => row[f]).toList());
        }
      }
    });
  }

  static Future<Uint8List> export(ActivityRepository repository) async {
    final folder = await Directory.systemTemp.createTemp('miagenda_export_');
    try {
      final path = '${folder.path}/agenda.sqlite';
      await repository.db.customStatement('VACUUM INTO ?', [path]);
      return await File(path).readAsBytes();
    } finally {
      await folder.delete(recursive: true);
    }
  }

  Future<void> close() async {
    await repository.close();
    await folder.delete(recursive: true);
  }
}
