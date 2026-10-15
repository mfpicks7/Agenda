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
      required this.onSelected});
  final DateTime month;
  final DateTime selected;
  final List<Activity> activities;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final days = monthDays(month);
    final byDay = <String, List<Activity>>{};
    for (final activity in activities) {
      byDay.putIfAbsent(dateKey(activity.date), () => []).add(activity);
    }
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final height = 112.0 + (scale - 1).clamp(0, 3) * 78;
    return Column(children: [
      Row(children: [
        for (final day in const ['L', 'M', 'X', 'J', 'V', 'S', 'D'])
          Expanded(
              child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(day,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold)))),
      ]),
      for (var row = 0; row < days.length ~/ 7; row++)
        SizedBox(
            height: height,
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var column = 0; column < 7; column++)
                Expanded(child: _day(context, days[row * 7 + column], byDay)),
            ])),
    ]);
  }

  Widget _day(
      BuildContext context, DateTime day, Map<String, List<Activity>> byDay) {
    final items = byDay[dateKey(day)] ?? [];
    final active = dateKey(day) == dateKey(selected);
    final today = dateKey(day) == dateKey(DateTime.now());
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label:
          '${DateFormat.yMMMMEEEEd('es').format(day)}, ${items.length} actividades${active ? ', seleccionado' : ''}',
      button: true,
      selected: active,
      child: InkWell(
        onTap:
            day.year < 1900 || day.year > 2100 ? null : () => onSelected(day),
        child: Container(
          margin: const EdgeInsets.all(1),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
          decoration: BoxDecoration(
            color: active ? scheme.primaryContainer : scheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: today ? scheme.primary : scheme.outlineVariant,
                width: today ? 2 : 0.5),
          ),
          child: ExcludeSemantics(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Text('${day.day}',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                        fontWeight:
                            active ? FontWeight.bold : FontWeight.normal,
                        color: day.month == month.month
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant)),
                const SizedBox(height: 3),
                for (final item in items.take(2))
                  Tooltip(
                      message: '${item.category.label}: ${item.title}',
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 2, vertical: 2),
                        decoration: BoxDecoration(
                            color: categoryColor(item.category),
                            borderRadius: BorderRadius.circular(3)),
                        child: Text(
                            '${item.category == ActivityCategory.work ? 'T' : 'P'} · ${item.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: item.category == ActivityCategory.work
                                    ? Colors.white
                                    : Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      )),
                if (items.length > 2)
                  Text('+${items.length - 2}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
              ])),
        ),
      ),
    );
  }
}
