import 'package:timezone/timezone.dart' as tz;
import '../activities/activity.dart';

String canonicalReminderZone(String zone) => const {
      'UTC',
      'GMT',
      'Etc/UTC',
      'Etc/GMT',
      'UCT',
      'Etc/UCT',
      'Universal',
      'Zulu'
    }.contains(zone)
        ? 'UTC'
        : zone;

tz.Location reminderLocation(String zone) =>
    canonicalReminderZone(zone) == 'UTC' ? tz.UTC : tz.getLocation(zone);

String reminderLabel(int minutes) {
  if (minutes == 0) {
    return 'Al comenzar';
  }
  if (minutes % 1440 == 0) {
    return '${minutes ~/ 1440} día(s) antes';
  }
  if (minutes % 60 == 0) {
    return '${minutes ~/ 60} hora(s) antes';
  }
  return '$minutes minutos antes';
}

class PlannedReminder {
  const PlannedReminder(this.activity, this.offset, this.instant);
  final Activity activity;
  final int offset;
  final tz.TZDateTime instant;
  String get key => '${activity.id}:$offset';
}

// Comprueba la hora civil contra los offsets de ambos lados de una transición.
// Si una hora se repite, elige el primer instante; si no existe, muestra un error.
tz.TZDateTime resolveCivil(Activity activity) {
  final zone = activity.timeZoneId;
  if (zone == null) {
    throw const FormatException('Falta la zona horaria del aviso.');
  }
  final location = reminderLocation(zone);
  final minute = activity.minuteOfDay ?? activity.allDayReminderMinute;
  final civil = DateTime.utc(activity.date.year, activity.date.month,
      activity.date.day, minute ~/ 60, minute % 60);
  final offsets = <int>{};
  for (final hours in [-48, 0, 48]) {
    offsets.add(tz.TZDateTime.from(civil.add(Duration(hours: hours)), location)
        .timeZoneOffset
        .inMilliseconds);
  }
  final candidates = <tz.TZDateTime>[];
  for (final offset in offsets) {
    final value = tz.TZDateTime.from(
        DateTime.fromMillisecondsSinceEpoch(
            civil.millisecondsSinceEpoch - offset,
            isUtc: true),
        location);
    if (value.year == civil.year &&
        value.month == civil.month &&
        value.day == civil.day &&
        value.hour == civil.hour &&
        value.minute == civil.minute) {
      candidates.add(value);
    }
  }
  if (candidates.isEmpty) {
    throw const FormatException(
        'Esta hora no existe por el cambio de horario. Elige otra hora.');
  }
  candidates.sort((a, b) => a.compareTo(b));
  return candidates.first;
}

List<PlannedReminder> planReminders(List<Activity> activities, DateTime now) {
  final result = <PlannedReminder>[];
  for (final activity in activities) {
    if (activity.reminderOffsets.isEmpty) {
      continue;
    }
    final start = resolveCivil(activity);
    for (final offset in activity.reminderOffsets) {
      final instant = start.subtract(Duration(minutes: offset));
      if (instant.isAfter(now)) {
        result.add(PlannedReminder(activity, offset, instant));
      }
    }
  }
  result.sort((a, b) => a.instant.compareTo(b.instant));
  return result;
}
