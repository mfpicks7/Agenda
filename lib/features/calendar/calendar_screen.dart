import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../activities/activity.dart';
import 'month_grid.dart';

String _capitalized(String text) => text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, this.initialDate});
  final DateTime? initialDate;
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime selected;
  late DateTime month;
  ActivityCategory? filter;

  @override
  void initState() {
    super.initState();
    selected = dateOnly(widget.initialDate ?? DateTime.now());
    month = DateTime(selected.year, selected.month);
  }

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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F9FA),
    bottomNavigationBar: SafeArea(top: false, minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: FilledButton.icon(key: const ValueKey('new-activity-button'), onPressed: () => context.push('/new?date=${dateKey(selected)}'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48),
          backgroundColor: workColor, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        icon: const Icon(Icons.add), label: const Text('Nueva actividad'))),
    body: SafeArea(child: ref.watch(activitiesProvider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, unused) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          const Text('No pudimos leer la agenda. Tus datos no se han borrado.'),
          TextButton(onPressed: () => ref.invalidate(activitiesProvider), child: const Text('Reintentar')),
        ]))),
      data: (all) {
        final visible = all.where((a) => filter == null || a.category == filter).toList();
        final day = visible.where((a) => dateKey(a.date) == dateKey(selected)).toList();
        return LayoutBuilder(builder: (context, constraints) {
          final rowHeight = ((constraints.maxHeight - 232) / 6).clamp(44.0, 52.0).toDouble();
          return SingleChildScrollView(padding: const EdgeInsets.all(12), child: Container(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE3E5E7))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _header(context),
              const SizedBox(height: 12),
              MonthGrid(month: month, selected: selected, activities: visible,
                onSelected: select, rowHeight: rowHeight),
              const SizedBox(height: 6),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
                for (final category in ActivityCategory.values) _legend(category),
                if (filter != null) TextButton(onPressed: () => setState(() => filter = null), child: const Text('Todos')),
              ]),
              const Padding(padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: Color(0xFFEBEDEF))),
              Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(
                _capitalized(DateFormat("EEEE d 'de' MMMM", 'es').format(selected)),
                key: const ValueKey('selected-day-heading'),
                style: const TextStyle(fontSize: 20, height: 1.25, fontWeight: FontWeight.w700, color: Color(0xFF171A1C)))),
              if (day.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 18),
                child: Text('No hay actividades para este día con el filtro seleccionado.',
                  style: TextStyle(color: Color(0xFF64696D), height: 1.4))),
              for (final activity in day) _activityCard(activity),
            ]),
          ));
        });
      },
    )),
  );

  Widget _header(BuildContext context) {
    final label = _capitalized(DateFormat('MMMM yyyy', 'es').format(month));
    const titleStyle = TextStyle(fontSize: 24, height: 1.15, fontWeight: FontWeight.w700, color: Color(0xFF13171A));
    final nav = Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(tooltip: 'Mes anterior', constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
        padding: const EdgeInsets.all(6), iconSize: 22,
        onPressed: month.year == 1900 && month.month == 1 ? null : () => move(-1), icon: const Icon(Icons.chevron_left)),
      TextButton(onPressed: () => select(dateOnly(DateTime.now())),
        style: TextButton.styleFrom(minimumSize: const Size(40, 44), padding: const EdgeInsets.symmetric(horizontal: 4),
          foregroundColor: const Color(0xFF64696D)), child: const Text('Hoy')),
      IconButton(tooltip: 'Mes siguiente', constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
        padding: const EdgeInsets.all(6), iconSize: 22,
        onPressed: month.year == 2100 && month.month == 12 ? null : () => move(1), icon: const Icon(Icons.chevron_right)),
    ]);
    const subtitle = Text('Mi agenda', style: TextStyle(fontSize: 16, color: Color(0xFF64696D)));
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(text: TextSpan(text: label, style: titleStyle),
        textDirection: Directionality.of(context), textScaler: MediaQuery.textScalerOf(context))..layout();
      final requiredWidth = painter.width + 132 * (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 2.0) + 8;
      painter.dispose();
      if (constraints.maxWidth < requiredWidth) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: titleStyle),
          Row(children: [const Expanded(child: subtitle), nav]),
        ]);
      }
      return Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: titleStyle), const SizedBox(height: 6), subtitle,
      ])), nav]);
    });
  }

  Widget _legend(ActivityCategory category) => Semantics(selected: filter == category,
    child: InkWell(borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => filter = filter == category ? null : category),
      child: Padding(padding: const EdgeInsets.fromLTRB(0, 12, 12, 12), child: Row(mainAxisSize: MainAxisSize.min, children: [
        DecoratedBox(decoration: BoxDecoration(color: categoryColor(category), shape: BoxShape.circle),
          child: const SizedBox(width: 10, height: 10)),
        const SizedBox(width: 5),
        Text(category.label, style: TextStyle(fontSize: 14, color: const Color(0xFF64696D),
          fontWeight: filter == category ? FontWeight.w700 : FontWeight.w400)),
      ]))));

  Widget _activityCard(Activity activity) => Padding(padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Material(color: const Color(0xFFF1F3F4), borderRadius: BorderRadius.circular(16),
      child: ListTile(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        minLeadingWidth: 4, horizontalTitleGap: 10,
        leading: SizedBox(width: 4, height: 42, child: DecoratedBox(
          decoration: BoxDecoration(color: categoryColor(activity.category), borderRadius: BorderRadius.circular(3)))),
        title: Text(activity.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        subtitle: Text('${activity.timeLabel} · ${activity.category.label}'
          '${activity.tasks.isEmpty ? '' : '\n${activity.tasks.where((t) => t.isDone).length}/${activity.tasks.length} pendientes completados'}',
          style: const TextStyle(fontSize: 14, color: Color(0xFF64696D), height: 1.5)),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF92999E)),
        onTap: () => context.push('/activity/${activity.id}'),
      )));
}
