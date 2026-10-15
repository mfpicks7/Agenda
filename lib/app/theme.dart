import 'package:flutter/material.dart';
import '../features/activities/activity.dart';

const workColor = Color(0xFF2563EB);
const personalColor = Color(0xFF16A34A);
Color categoryColor(ActivityCategory category) =>
    category == ActivityCategory.work ? workColor : personalColor;

ThemeData agendaTheme(Brightness brightness) {
  final scheme =
      ColorScheme.fromSeed(seedColor: workColor, brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: brightness == Brightness.light
        ? const Color(0xFFF6F8FC)
        : scheme.surface,
    appBarTheme: const AppBarTheme(centerTitle: false),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      alignLabelWithHint: true,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: workColor,
      foregroundColor: Colors.white,
    ),
  );
}
