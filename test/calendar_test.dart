import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mi_agenda/app/theme.dart';
import 'package:mi_agenda/features/activities/activity.dart';
import 'package:mi_agenda/features/calendar/month_grid.dart';

void main() {
  setUpAll(() async { await initializeDateFormatting('es'); });
  test('Lunes inicial, febrero bisiesto y cambio de año', () {
    final days = monthDays(DateTime(2028, 2));
    expect(days.first.weekday, DateTime.monday);
    expect(days.length % 7, 0);
    expect(days.where((d) => d.month == 2).length, 29);
    expect(monthDays(DateTime(2027, 2)).where((d) => d.month == 2).length, 28);
    expect(monthDays(DateTime(2027, 13)).where((d) => d.month == 1).first.year, 2028);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('Calendario de 320 px, tres actividades y texto a escala $scale', (tester) async {
      tester.view.physicalSize = const Size(320, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final date = DateTime(2028, 2, 29);
      final items = List.generate(3, (i) => Activity(id: '$i', title: 'Actividad de nombre muy largo $i',
        category: i == 0 ? ActivityCategory.work : ActivityCategory.personal, date: date));
      DateTime? picked;
      await tester.pumpWidget(MaterialApp(locale: const Locale('es'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates, supportedLocales: const [Locale('es')],
        theme: agendaTheme(Brightness.light),
        home: MediaQuery(data: MediaQueryData(size: const Size(320, 1200), textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: SingleChildScrollView(child: MonthGrid(
            month: date, selected: date, activities: items, onSelected: (day) => picked = day))))));
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('T · ${items[0].title}'), findsOneWidget);
      expect(find.text('P · ${items[1].title}'), findsOneWidget);
      expect(find.text('P · ${items[2].title}'), findsNothing);
      final work = tester.widget<Text>(find.text('T · ${items[0].title}'));
      expect(work.style!.color, Colors.white);
      final colored = tester.widgetList<Container>(find.byType(Container)).where((c) =>
        c.decoration is BoxDecoration && (c.decoration! as BoxDecoration).color == workColor);
      expect(colored, isNotEmpty);
      await tester.ensureVisible(find.text('29'));
      await tester.tap(find.text('29'));
      expect(picked, date);
      expect(tester.takeException(), isNull);
    });
  }
}
