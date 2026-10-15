import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mi_agenda/app/app.dart';
import 'package:mi_agenda/app/providers.dart';
import 'package:mi_agenda/core/database/app_database.dart';
import 'package:mi_agenda/features/activities/activity.dart';
import 'package:mi_agenda/features/activities/activity_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
  });
  testWidgets(
      'Crear con validación, detalle, checklist, editar y eliminar con confirmación',
      (tester) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = ActivityRepository(AppDatabase(NativeDatabase.memory()));
    addTearDown(repo.close);
    agendaRouter.go('/');
    await tester.pumpWidget(ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: const AgendaApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva actividad'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar actividad'));
    await tester.tap(find.text('Guardar actividad'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe un título.'), findsOneWidget);
    await tester.ensureVisible(find.byType(TextFormField).first);
    await tester.enterText(
        find.byType(TextFormField).first, 'Revisar proyecto');
    await tester.enterText(find.byType(TextFormField).at(1), 'Nota persistida');
    await tester.ensureVisible(find.text('Añadir pendiente'));
    await tester.tap(find.text('Añadir pendiente'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).at(2), 'Preparar entrega');
    await tester.ensureVisible(find.text('Guardar actividad'));
    await tester.tap(find.text('Guardar actividad'));
    await tester.pumpAndSettle();
    expect((await repo.getAll()).single.notes, 'Nota persistida');
    await tester.ensureVisible(find.text('Revisar proyecto'));
    await tester.tap(find.text('Revisar proyecto'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect((await repo.getAll()).single.tasks.single.isDone, isTrue);
    await tester.ensureVisible(find.text('Editar actividad'));
    await tester.tap(find.text('Editar actividad'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).first, 'Proyecto revisado');
    await tester.ensureVisible(find.text('Guardar actividad'));
    await tester.tap(find.text('Guardar actividad'));
    await tester.pumpAndSettle();
    expect(find.text('Proyecto revisado'), findsOneWidget);
    await tester.ensureVisible(find.text('Eliminar actividad'));
    await tester.tap(find.text('Eliminar actividad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect((await repo.getAll()).length, 1);
    await tester.tap(find.text('Eliminar actividad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(await repo.getAll(), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Tres actividades, filtros y navegación de meses',
      (tester) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = ActivityRepository(AppDatabase(NativeDatabase.memory()));
    addTearDown(repo.close);
    for (var i = 0; i < 3; i++) {
      await repo.save(Activity(
          id: '$i',
          title: 'Actividad $i',
          category: i == 0 ? ActivityCategory.work : ActivityCategory.personal,
          date: DateTime.now(),
          minuteOfDay: 600 + i));
    }
    agendaRouter.go('/');
    await tester.pumpWidget(ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: const AgendaApp()));
    await tester.pumpAndSettle();
    expect(find.text('+1'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(3));
    await tester.tap(find.text('Trabajo'));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
    expect(await repo.getAll(), hasLength(3));
    await tester.tap(find.byTooltip('Mes siguiente'));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing);
    await tester.tap(find.text('Hoy'));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
