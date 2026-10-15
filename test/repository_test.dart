import 'dart:async';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_agenda/core/database/app_database.dart';
import 'package:mi_agenda/features/activities/activity.dart';
import 'package:mi_agenda/features/activities/activity_repository.dart';

Activity example(
        {String id = 'a',
        String title = 'Reunión',
        ActivityCategory category = ActivityCategory.work,
        DateTime? date,
        int? minute = 540,
        String notes = 'Preparar informe',
        List<AgendaTask>? tasks}) =>
    Activity(
      id: id,
      title: title,
      category: category,
      date: date ?? DateTime(2028, 2, 29),
      minuteOfDay: minute,
      notes: notes,
      tasks: tasks ??
          const [
            AgendaTask(id: 't1', description: 'Informe'),
            AgendaTask(id: 't2', description: 'Enviar')
          ],
    );

void main() {
  late ActivityRepository repo;
  setUp(() {
    repo = ActivityRepository(AppDatabase(NativeDatabase.memory()));
  });
  tearDown(() async {
    await repo.close();
  });

  test('Valida título, hora, fecha y pendientes; notas vacías válidas', () {
    expect(example(title: '  ').validate(), isNotNull);
    expect(example(minute: 1440).validate(), isNotNull);
    expect(example(date: DateTime(1800)).validate(), isNotNull);
    expect(
        example(tasks: [const AgendaTask(id: 'x', description: ' ')])
            .validate(),
        isNotNull);
    expect(example(notes: '', tasks: []).validate(), isNull);
    expect(example(minute: null).timeLabel, 'Todo el día');
    expect(example(minute: 65).timeLabel, '01:05');
  });

  test('Crear, editar, ordenar por hora y eliminar sin huérfanos', () async {
    await repo.save(example());
    await repo.save(example(
        id: 'b', minute: null, category: ActivityCategory.personal, tasks: []));
    expect((await repo.getAll()).map((a) => a.id), ['b', 'a']);
    await repo.setTaskDone('a', 't1', true);
    final old = (await repo.getAll()).last;
    await repo.save(example(
        title: 'Editada',
        category: ActivityCategory.personal,
        date: DateTime(2028, 3, 1),
        minute: 780,
        tasks: old.tasks.reversed.toList()));
    final changed = (await repo.getAll()).last;
    expect(changed.title, 'Editada');
    expect(changed.category, ActivityCategory.personal);
    expect(changed.date, DateTime(2028, 3, 1));
    expect(changed.minuteOfDay, 780);
    expect(changed.tasks.first.id, 't2');
    expect(changed.tasks.last.isDone, isTrue);
    await repo.delete('a');
    expect((await repo.getAll()).map((a) => a.id), ['b']);
    expect(await repo.db.customSelect('SELECT * FROM task_templates').get(),
        isEmpty);
  });

  test('Persistencia real al cerrar y reabrir SQLite en disco', () async {
    final folder = await Directory.systemTemp.createTemp('mi_agenda_test_');
    final file = File('${folder.path}/agenda.sqlite');
    final first = ActivityRepository(AppDatabase(NativeDatabase(file)));
    try {
      await first.save(example());
      await first.setTaskDone('a', 't1', true);
    } finally {
      await first.close();
    }
    final reopened = ActivityRepository(AppDatabase(NativeDatabase(file)));
    try {
      final loaded = (await reopened.getAll()).single;
      expect(loaded.notes, 'Preparar informe');
      expect(loaded.tasks.first.isDone, isTrue);
      expect(loaded.tasks.last.isDone, isFalse);
      expect(
          await reopened.db
              .customSelect('PRAGMA user_version')
              .getSingle()
              .then((r) => r.read<int>('user_version')),
          1);
    } finally {
      await reopened.close();
      await folder.delete(recursive: true);
    }
  });

  test('Una transacción fallida conserva actividad y tareas anteriores',
      () async {
    await repo.save(example());
    await repo.save(example(
        id: 'b', tasks: [const AgendaTask(id: 'other', description: 'Otra')]));
    await expectLater(
        repo.save(example(title: 'No debe guardarse', tasks: [
          const AgendaTask(
              id: 'other', description: 'Colisión con otra actividad'),
        ])),
        throwsA(anything));
    final original = (await repo.getAll()).firstWhere((a) => a.id == 'a');
    expect(original.title, 'Reunión');
    expect(original.tasks.length, 2);
  });

  test('El estado de una tarea no cambia tareas de otra actividad', () async {
    await repo.save(example());
    await repo.save(example(
        id: 'b', tasks: [const AgendaTask(id: 'other', description: 'Otra')]));
    await repo.setTaskDone('b', 't1', true); // ID de actividad incorrecto.
    expect((await repo.getAll()).expand((a) => a.tasks).every((t) => !t.isDone),
        isTrue);
    await repo.setTaskDone('a', 't1', true);
    expect(
        (await repo.getAll())
            .firstWhere((a) => a.id == 'b')
            .tasks
            .single
            .isDone,
        isFalse);
  });

  test('Stream entrega cambios después de confirmar SQLite', () async {
    final stream = StreamIterator(repo.watchAll());
    try {
      expect(await stream.moveNext(), isTrue);
      expect(stream.current, isEmpty);
      final next = stream.moveNext();
      await repo.save(example());
      expect(await next, isTrue);
      expect(stream.current.single.title, 'Reunión');
    } finally {
      await stream.cancel();
    }
  });
}
