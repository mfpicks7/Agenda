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
  const AgendaTask({required this.id, required this.description, this.isDone = false});
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
    List<AgendaTask> tasks = const [],
  }) : date = dateOnly(date), tasks = List.unmodifiable(tasks);

  final String id;
  final String title;
  final ActivityCategory category;
  final DateTime date;
  // Hora civil local. E1 no calcula instantes ni programa notificaciones.
  final int? minuteOfDay;
  final String notes;
  final List<AgendaTask> tasks;

  bool get isAllDay => minuteOfDay == null;
  String get timeLabel => minuteOfDay == null
      ? 'Todo el día'
      : '${(minuteOfDay! ~/ 60).toString().padLeft(2, '0')}:${(minuteOfDay! % 60).toString().padLeft(2, '0')}';

  String? validate() {
    if (title.trim().isEmpty) return 'Escribe un título.';
    if (date.year < 1900 || date.year > 2100) return 'La fecha debe estar entre 1900 y 2100.';
    if (minuteOfDay != null && (minuteOfDay! < 0 || minuteOfDay! >= 1440)) {
      return 'Selecciona una hora válida.';
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
