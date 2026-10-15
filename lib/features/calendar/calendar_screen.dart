import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../activities/activity.dart';
import 'month_grid.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime selected = dateOnly(DateTime.now());
  late DateTime month = DateTime(selected.year, selected.month);
  ActivityCategory? filter;

  void select(DateTime value) => setState(() {
    selected = value;
    month = DateTime(value.year, value.month);
  });

  void move(int delta) {
    final next = DateTime(month.year, month.month + delta);
    if (next.year < 1900 || next.year > 2100) { return; }
    select(next);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(activitiesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Agenda'), actions: [
        TextButton(onPressed: () => select(dateOnly(DateTime.now())), child: const Text('Hoy')),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/new?date=${dateKey(selected)}'),
        icon: const Icon(Icons.add), label: const Text('Nueva actividad'),
      ),
      body: SafeArea(child: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, unused) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [const Text('No pudimos leer la agenda. Tus datos no se han borrado.'),
            TextButton(onPressed: () => ref.invalidate(activitiesProvider), child: const Text('Reintentar'))],
        ))),
        data: (all) {
          final visible = all.where((a) => filter == null || a.category == filter).toList();
          final day = visible.where((a) => dateKey(a.date) == dateKey(selected)).toList();
          return ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 100), children: [
            Row(children: [
              IconButton(tooltip: 'Mes anterior', onPressed: month.year == 1900 && month.month == 1 ? null : () => move(-1), icon: const Icon(Icons.chevron_left)),
              Expanded(child: Text(DateFormat.yMMMM('es').format(month), textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge)),
              IconButton(tooltip: 'Mes siguiente', onPressed: month.year == 2100 && month.month == 12 ? null : () => move(1), icon: const Icon(Icons.chevron_right)),
            ]),
            Wrap(spacing: 8, children: [
              ChoiceChip(label: const Text('Todos'), selected: filter == null, onSelected: (_) => setState(() => filter = null)),
              for (final category in ActivityCategory.values)
                ChoiceChip(label: Text(category.label), avatar: Icon(Icons.circle, size: 12, color: categoryColor(category)),
                  selected: filter == category, onSelected: (_) => setState(() => filter = category)),
            ]),
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('T: Trabajo · P: Personal', style: TextStyle(fontSize: 12))),
            MonthGrid(month: month, selected: selected, activities: visible, onSelected: select),
            const SizedBox(height: 24),
            Text(DateFormat.yMMMMEEEEd('es').format(selected), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (day.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No hay actividades para este día con el filtro seleccionado.')),
            for (final activity in day) Card(child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              leading: Icon(activity.category == ActivityCategory.work ? Icons.work_outline : Icons.person_outline,
                color: categoryColor(activity.category)),
              title: Text(activity.title),
              subtitle: Text('${activity.timeLabel} · ${activity.category.label}'
                '${activity.tasks.isEmpty ? '' : '\n${activity.tasks.where((t) => t.isDone).length}/${activity.tasks.length} pendientes completados'}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/activity/${activity.id}'),
            )),
          ]);
        },
      )),
    );
  }
}
