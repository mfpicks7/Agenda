import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Drift con SQL explícito: no necesita archivos generados ni build_runner.
// SQLite y Drift son la fuente de verdad; todas las escrituras pasan por el repositorio.
class AppDatabase extends GeneratedDatabase {
  AppDatabase(super.executor);

  factory AppDatabase.device() => AppDatabase(LazyDatabase(() async {
        final folder = await getApplicationSupportDirectory();
        return NativeDatabase.createInBackground(
            File(p.join(folder.path, 'mi_agenda.sqlite')));
      }));

  @override
  int get schemaVersion => 2;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (_) async {
          await customStatement('''CREATE TABLE activities (
            id TEXT PRIMARY KEY NOT NULL,
            title TEXT NOT NULL CHECK(length(trim(title)) > 0),
            category TEXT NOT NULL CHECK(category IN ('work', 'personal')),
            local_date TEXT NOT NULL,
            minute_of_day INTEGER CHECK(minute_of_day BETWEEN 0 AND 1439),
            notes TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )''');
          await customStatement('''CREATE TABLE task_templates (
            id TEXT PRIMARY KEY NOT NULL,
            activity_id TEXT NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
            description TEXT NOT NULL CHECK(length(trim(description)) > 0),
            sort_order INTEGER NOT NULL,
            is_done INTEGER NOT NULL DEFAULT 0 CHECK(is_done IN (0, 1))
          )''');
          await customStatement(
              'CREATE INDEX activities_date_category ON activities(local_date, category)');
          await customStatement(
              'CREATE INDEX tasks_activity_order ON task_templates(activity_id, sort_order)');
          await _createReminders();
        },
        beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
        onUpgrade: (_, from, to) async {
          if (from == 1 && to == 2) {
            await _createReminders();
          } else {
            throw StateError('Migración no disponible: $from → $to.');
          }
        },
      );
  Future<void> _createReminders() async {
    await customStatement(
        "ALTER TABLE activities ADD COLUMN time_zone_id TEXT");
    await customStatement(
        'ALTER TABLE activities ADD COLUMN all_day_reminder_minute INTEGER NOT NULL DEFAULT 540 CHECK(all_day_reminder_minute BETWEEN 0 AND 1439)');
    await customStatement('''CREATE TABLE reminders (
      activity_id TEXT NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
      offset_minutes INTEGER NOT NULL CHECK(offset_minutes BETWEEN 0 AND 525600),
      PRIMARY KEY(activity_id, offset_minutes)
    )''');
    await customStatement('''CREATE TABLE notification_registry (
      notification_id INTEGER PRIMARY KEY AUTOINCREMENT CHECK(notification_id < 2147483647),
      activity_id TEXT NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
      offset_minutes INTEGER NOT NULL,
      scheduled_utc INTEGER NOT NULL,
      UNIQUE(activity_id, offset_minutes)
    )''');
  }
}
