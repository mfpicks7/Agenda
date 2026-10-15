import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import '../features/activities/activity_detail_screen.dart';
import '../features/activities/activity_form_screen.dart';
import '../features/calendar/calendar_screen.dart';
import 'theme.dart';
import '../features/reminders/reminder_settings_screen.dart';

final agendaRouter = GoRouter(routes: [
  GoRoute(path: '/notifications', builder: (_, unused) => const ReminderSettingsScreen()),
  GoRoute(path: '/', builder: (_, unused) => const CalendarScreen()),
  GoRoute(
      path: '/new',
      builder: (_, state) => ActivityFormScreen(
            initialDate:
                DateTime.tryParse(state.uri.queryParameters['date'] ?? ''),
          )),
  GoRoute(
      path: '/activity/:id',
      builder: (_, state) =>
          ActivityDetailScreen(id: state.pathParameters['id']!)),
  GoRoute(
      path: '/activity/:id/edit',
      builder: (_, state) =>
          ActivityFormScreen(id: state.pathParameters['id']!)),
]);

class AgendaApp extends StatelessWidget {
  const AgendaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Mi Agenda',
        debugShowCheckedModeBanner: false,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: agendaTheme(Brightness.light),
        darkTheme: agendaTheme(Brightness.dark),
        themeMode: ThemeMode.light,
        routerConfig: agendaRouter,
      );
}
