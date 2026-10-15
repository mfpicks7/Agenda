import 'package:uuid/uuid.dart';

enum ActivityCategory {
  work('Trabajo'),
  personal('Personal');

  const ActivityCategory(this.label);
  final String label;
}

String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
String newId() => const Uuid().v4();

class AgendaTask {
  const AgendaTask(
      {required this.id, required this.description, this.isDone = false});
  final String id;
  final String description;
  final bool isDone;

  AgendaTask copyWith({String? description, bool? isDone}) => AgendaTask(
        id: id,
        description: description ?? this.description,
        isDone: isDone ?? this.isDone,
      );
}

class Activity {
  Activity({
    required this.id,
    required this.title,
    required this.category,
    required DateTime date,
    this.minuteOfDay,
    this.notes = '',
    this.timeZoneId,
    this.allDayReminderMinute = 540,
    List<int> reminderOffsets = const [],
    List<AgendaTask> tasks = const [],
  })  : date = dateOnly(date),
        tasks = List.unmodifiable(tasks),
        reminderOffsets = List.unmodifiable(reminderOffsets);

  final String id;
  final String title;
  final ActivityCategory category;
  final DateTime date;
  // Hora civil local asociada a timeZoneId cuando hay recordatorios.
  final int? minuteOfDay;
  final String notes;
  final String? timeZoneId;
  final int allDayReminderMinute;
  final List<int> reminderOffsets;
  final List<AgendaTask> tasks;

  bool get isAllDay => minuteOfDay == null;
  String get timeLabel => minuteOfDay == null
      ? 'Todo el día'
      : '${(minuteOfDay! ~/ 60).toString().padLeft(2, '0')}:${(minuteOfDay! % 60).toString().padLeft(2, '0')}';

  Activity withTimeZone(String zone) => Activity(id: id, title: title, category: category,
    date: date, minuteOfDay: minuteOfDay, notes: notes, tasks: tasks,
    timeZoneId: zone, reminderOffsets: reminderOffsets, allDayReminderMinute: allDayReminderMinute);

  String? validate() {
    if (title.trim().isEmpty) {
      return 'Escribe un título.';
    }
    if (date.year < 1900 || date.year > 2100) {
      return 'La fecha debe estar entre 1900 y 2100.';
    }
    if (minuteOfDay != null && (minuteOfDay! < 0 || minuteOfDay! >= 1440)) {
      return 'Selecciona una hora válida.';
    }
    if (reminderOffsets.length > 8 || reminderOffsets.toSet().length != reminderOffsets.length ||
        reminderOffsets.any((m) => m < 0 || m > 525600)) {
      return 'Elige hasta ocho avisos diferentes, entre 0 y 525600 minutos.';
    }
    if (allDayReminderMinute < 0 || allDayReminderMinute >= 1440) {
      return 'La hora del aviso no es válida.';
    }
    if (tasks.any((task) => task.description.trim().isEmpty)) {
      return 'Escribe el pendiente o elimínalo.';
    }
    if (tasks.map((task) => task.id).toSet().length != tasks.length) {
      return 'Hay pendientes duplicados.';
    }
    return null;
  }
}
