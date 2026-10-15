import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import 'activity.dart';
import '../reminders/reminder_plan.dart';

class ActivityDetailScreen extends ConsumerStatefulWidget {
  const ActivityDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ActivityDetailScreen> createState() =>
      _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends ConsumerState<ActivityDetailScreen> {
  bool busy = false;
  String? error;

  Future<void> toggle(AgendaTask task, bool value) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(repositoryProvider).setTaskDone(widget.id, task.id, value);
    } catch (_) {
      if (mounted) {
        setState(() =>
            error = 'No se pudo guardar el pendiente. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> remove() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('¿Eliminar actividad?'),
              content: const Text(
                  'Se eliminarán también sus notas y pendientes. Esta acción no se puede deshacer.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Eliminar'))
              ],
            ));
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final hadReminders = (ref.read(activitiesProvider).asData?.value ?? [])
          .any((a) => a.id == widget.id && a.reminderOffsets.isNotEmpty);
      await ref.read(repositoryProvider).delete(widget.id);
      if (hadReminders) {
        await ref.read(reminderCoordinatorProvider).synchronize();
      }
      if (mounted) {
        context.go('/');
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            error = 'No se pudo eliminar la actividad. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Detalle de actividad')),
        body: ref.watch(activitiesProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, unused) => Center(
                  child: TextButton(
                      onPressed: () => ref.invalidate(activitiesProvider),
                      child: const Text('Reintentar cargar la actividad'))),
              data: (all) {
                final matches = all.where((a) => a.id == widget.id);
                if (matches.isEmpty) {
                  return const Center(
                      child: Text('Esta actividad ya no está disponible.'));
                }
                final activity = matches.first;
                return ListView(padding: const EdgeInsets.all(20), children: [
                  Text(activity.title,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  Row(children: [
                    Icon(Icons.circle,
                        size: 14, color: categoryColor(activity.category)),
                    const SizedBox(width: 8),
                    Text(activity.category.label)
                  ]),
                  const SizedBox(height: 12),
                  Text(
                      '${DateFormat.yMMMMEEEEd('es').format(activity.date)}\n${activity.timeLabel}'),
                  const SizedBox(height: 24),
                  Text('Avisos',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(activity.reminderOffsets.isEmpty
                      ? 'Sin avisos.'
                      : activity.reminderOffsets
                          .map(reminderLabel)
                          .join(' · ')),
                  if (activity.reminderOffsets.isNotEmpty) ...[
                    if (activity.isAllDay)
                      Text(
                          'Hora base: ${(activity.allDayReminderMinute ~/ 60).toString().padLeft(2, '0')}:${(activity.allDayReminderMinute % 60).toString().padLeft(2, '0')}'),
                    Text('Zona: ${activity.timeZoneId ?? 'sin configurar'}'),
                    if (ref.watch(reminderCoordinatorProvider).warning != null)
                      Text(ref.watch(reminderCoordinatorProvider).warning!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    TextButton(
                        onPressed: () => context.push('/notifications'),
                        child: const Text('Revisar permisos de avisos')),
                  ],
                  const SizedBox(height: 24),
                  Text('Notas', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SelectableText(
                      activity.notes.isEmpty ? 'Sin notas.' : activity.notes),
                  const SizedBox(height: 24),
                  Text(
                      'Pendientes (${activity.tasks.where((t) => t.isDone).length}/${activity.tasks.length})',
                      style: Theme.of(context).textTheme.titleMedium),
                  if (activity.tasks.isEmpty)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Sin pendientes.')),
                  for (final task in activity.tasks)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(task.description),
                      value: task.isDone,
                      onChanged:
                          busy ? null : (value) => toggle(task, value ?? false),
                    ),
                  if (error != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error),
                            semanticsLabel: error)),
                  if (busy) const LinearProgressIndicator(),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                      onPressed: busy
                          ? null
                          : () => context.push('/activity/${widget.id}/edit'),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar actividad')),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                      onPressed: busy ? null : remove,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Eliminar actividad')),
                ]);
              },
            ),
      );
}
