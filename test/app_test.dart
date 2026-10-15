import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mi_agenda/app/theme.dart';
import 'package:mi_agenda/features/calendar/calendar_screen.dart';
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
    expect(find.byKey(ValueKey('dot-${dateKey(DateTime.now())}-work')),
        findsOneWidget);
    expect(find.byKey(ValueKey('dot-${dateKey(DateTime.now())}-personal')),
        findsOneWidget);
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

  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844)
  ]) {
    for (final date in [
      DateTime(2021, 2, 14),
      DateTime(2026, 10, 14),
      DateTime(2026, 3, 14)
    ]) {
      testWidgets(
          'Mes completo sin desplazar: ${dateKey(date)} en ${size.width}x${size.height}',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = ActivityRepository(AppDatabase(NativeDatabase.memory()));
        addTearDown(repo.close);
        await tester.pumpWidget(ProviderScope(
            overrides: [repositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
                locale: const Locale('es'),
                supportedLocales: const [Locale('es')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                theme: agendaTheme(Brightness.light),
                home: CalendarScreen(initialDate: date))));
        await tester.pumpAndSettle();
        final last = DateTime(date.year, date.month + 1, 0);
        final grid = tester.getRect(find.byKey(const ValueKey('month-grid')));
        final lastDay =
            tester.getRect(find.byKey(ValueKey('day-${dateKey(last)}')));
        final button =
            tester.getRect(find.byKey(const ValueKey('new-activity-button')));
        expect(grid.top, greaterThanOrEqualTo(0));
        expect(grid.bottom, lessThanOrEqualTo(button.top));
        expect(lastDay.bottom, lessThanOrEqualTo(button.top));
        expect(lastDay.right, lessThanOrEqualTo(size.width));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('Pantalla completa con texto doble y títulos largos sin overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = ActivityRepository(AppDatabase(NativeDatabase.memory()));
    addTearDown(repo.close);
    final date = DateTime(2026, 3, 14);
    await repo.save(Activity(
        id: 'long',
        title: 'Una actividad con un título largo que se puede abrir completo',
        category: ActivityCategory.work,
        date: date));
    await tester.pumpWidget(ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
            locale: const Locale('es'),
            supportedLocales: const [Locale('es')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: agendaTheme(Brightness.light),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(2)),
                child: child!),
            home: CalendarScreen(initialDate: date))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
