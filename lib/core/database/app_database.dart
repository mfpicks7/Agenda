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
  int get schemaVersion => 1;

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
        },
        beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
        onUpgrade: (_, from, to) async {
          throw StateError(
              'Migración de base de datos no disponible: $from → $to.');
        },
      );
}
