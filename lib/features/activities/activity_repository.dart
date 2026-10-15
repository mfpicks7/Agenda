import 'dart:async';
import '../../core/database/app_database.dart';
import 'activity.dart';

class ActivityRepository {
  ActivityRepository(this.db);
  final AppDatabase db;
  final _changes = StreamController<void>.broadcast();

  // La suscripción precede a la lectura inicial para no perder escrituras.
  // asyncMap serializa lecturas y evita que una consulta antigua reemplace otra nueva.
  Stream<List<Activity>> watchAll() => Stream<void>.multi((controller) {
        final subscription = _changes.stream.listen(
          controller.addSync,
          onError: controller.addErrorSync,
          onDone: controller.closeSync,
        );
        controller.addSync(null);
        controller.onCancel = subscription.cancel;
      }).asyncMap((_) => getAll());

  Future<List<Activity>> getAll() async {
    return db.transaction(() async {
      final rows = await db
          .customSelect(
            'SELECT * FROM activities ORDER BY local_date, COALESCE(minute_of_day, -1), created_at, id',
          )
          .get();
      final taskRows = await db
          .customSelect(
            'SELECT * FROM task_templates ORDER BY sort_order, id',
          )
          .get();
      final tasks = <String, List<AgendaTask>>{};
      for (final row in taskRows) {
        tasks
            .putIfAbsent(row.read<String>('activity_id'), () => [])
            .add(AgendaTask(
              id: row.read<String>('id'),
              description: row.read<String>('description'),
              isDone: row.read<int>('is_done') == 1,
            ));
      }
      return rows
          .map((row) => Activity(
                id: row.read<String>('id'),
                title: row.read<String>('title'),
                category: ActivityCategory.values
                    .byName(row.read<String>('category')),
                date: DateTime.parse(row.read<String>('local_date')),
                minuteOfDay: row.readNullable<int>('minute_of_day'),
                notes: row.read<String>('notes'),
                tasks: tasks[row.read<String>('id')] ?? [],
              ))
          .toList();
    });
  }

  Future<void> save(Activity activity) async {
    final error = activity.validate();
    if (error != null) throw ArgumentError(error);
    await db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.customStatement('''INSERT INTO activities
        (id, title, category, local_date, minute_of_day, notes, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET title=excluded.title,
        category=excluded.category, local_date=excluded.local_date,
        minute_of_day=excluded.minute_of_day, notes=excluded.notes,
        updated_at=excluded.updated_at''', [
        activity.id,
        activity.title.trim(),
        activity.category.name,
        dateKey(activity.date),
        activity.minuteOfDay,
        activity.notes,
        now,
        now,
      ]);
      await db.customStatement(
          'DELETE FROM task_templates WHERE activity_id = ?', [activity.id]);
      for (var i = 0; i < activity.tasks.length; i++) {
        final task = activity.tasks[i];
        await db.customStatement(
            '''INSERT INTO task_templates
          (id, activity_id, description, sort_order, is_done) VALUES (?, ?, ?, ?, ?)''',
            [
              task.id,
              activity.id,
              task.description.trim(),
              i,
              task.isDone ? 1 : 0
            ]);
      }
    });
    _changes.add(null);
  }

  Future<void> setTaskDone(String activityId, String taskId, bool done) async {
    await db.customStatement(
      'UPDATE task_templates SET is_done = ? WHERE id = ? AND activity_id = ?',
      [done ? 1 : 0, taskId, activityId],
    );
    _changes.add(null);
  }

  Future<void> delete(String id) async {
    await db.transaction(() async {
      await db.customStatement('DELETE FROM activities WHERE id = ?', [id]);
    });
    _changes.add(null);
  }

  Future<void> close() async {
    await _changes.close();
    await db.close();
  }
}
