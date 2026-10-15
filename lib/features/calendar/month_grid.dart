import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../activities/activity.dart';

List<DateTime> monthDays(DateTime month) {
  final start = DateTime(month.year, month.month);
  final leading = start.weekday - DateTime.monday;
  final count = DateTime(month.year, month.month + 1, 0).day;
  final cells = ((leading + count) / 7).ceil() * 7;
  return List.generate(
      cells, (i) => DateTime(month.year, month.month, 1 - leading + i));
}

class MonthGrid extends StatelessWidget {
  const MonthGrid(
      {super.key,
      required this.month,
      required this.selected,
      required this.activities,
      required this.onSelected,
      this.rowHeight = 52});
  final DateTime month;
  final DateTime selected;
  final List<Activity> activities;
  final ValueChanged<DateTime> onSelected;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    final days = monthDays(month);
    final byDay = <String, List<Activity>>{};
    for (final activity in activities) {
      byDay.putIfAbsent(dateKey(activity.date), () => []).add(activity);
    }
    // Seis semanas caben en un teléfono. El texto ampliado puede crecer sin recortarse.
    final height =
        math.max(rowHeight, MediaQuery.textScalerOf(context).scale(16) + 24);
    const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    const names = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    return Column(key: const ValueKey('month-grid'), children: [
      Row(children: [
        for (var i = 0; i < 7; i++)
          Expanded(
              child: Semantics(
                  label: names[i],
                  child: ExcludeSemantics(
                      child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(labels[i],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF64696D))))))),
      ]),
      for (var row = 0; row < days.length ~/ 7; row++)
        SizedBox(
            height: height,
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var col = 0; col < 7; col++)
                Expanded(child: _day(context, days[row * 7 + col], byDay)),
            ])),
    ]);
  }

  Widget _day(
      BuildContext context, DateTime day, Map<String, List<Activity>> byDay) {
    if (day.month != month.month || day.year != month.year) {
      return const SizedBox.shrink();
    }
    final items = byDay[dateKey(day)] ?? [];
    final categories = ActivityCategory.values
        .where((category) => items.any((a) => a.category == category))
        .toList();
    final active = dateKey(day) == dateKey(selected);
    final today = dateKey(day) == dateKey(DateTime.now());
    final description = items.isEmpty
        ? 'Sin actividades'
        : items.map((a) => '${a.category.label}: ${a.title}').join('. ');
    return Semantics(
      key: ValueKey('day-${dateKey(day)}'),
      label:
          '${DateFormat.yMMMMEEEEd('es').format(day)}, ${items.length} actividades. $description',
      button: true,
      selected: active,
      child: Material(
        color: active ? const Color(0xFFEDF3FF) : Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
                color: active ? const Color(0xFF5F83C4) : Colors.transparent,
                width: 1.2)),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onSelected(day),
          child: ExcludeSemantics(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('${day.day}',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                                fontSize: 16,
                                height: 1.15,
                                fontWeight: active || today
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: today && !active
                                    ? workColor
                                    : const Color(0xFF1D2125))))),
                const SizedBox(height: 7),
                SizedBox(
                    height: 6,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final category in categories)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                child: DecoratedBox(
                                    key: ValueKey(
                                        'dot-${dateKey(day)}-${category.name}'),
                                    decoration: BoxDecoration(
                                        color: categoryColor(category),
                                        shape: BoxShape.circle),
                                    child:
                                        const SizedBox(width: 6, height: 6))),
                        ])),
              ])),
        ),
      ),
    );
  }
}
