import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app/providers.dart';
import 'activity.dart';

class ActivityFormScreen extends ConsumerWidget {
  const ActivityFormScreen({super.key, this.id, this.initialDate});
  final String? id;
  final DateTime? initialDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (id == null) {
      return _ActivityEditor(initialDate: initialDate);
    }
    return ref.watch(activitiesProvider).when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, unused) => Scaffold(
              appBar: AppBar(title: const Text('Editar actividad')),
              body: Center(
                  child: TextButton(
                      onPressed: () => ref.invalidate(activitiesProvider),
                      child: const Text('Reintentar cargar')))),
          data: (all) {
            final matches = all.where((a) => a.id == id);
            if (matches.isEmpty) {
              return Scaffold(
                  appBar: AppBar(title: const Text('Editar actividad')),
                  body: const Center(
                      child: Text('La actividad ya no está disponible.')));
            }
            return _ActivityEditor(key: ValueKey(id), existing: matches.first);
          },
        );
  }
}

class _TaskDraft {
  _TaskDraft(AgendaTask task)
      : id = task.id,
        controller = TextEditingController(text: task.description),
        done = task.isDone;
  final String id;
  final TextEditingController controller;
  bool done;
}

class _ActivityEditor extends ConsumerStatefulWidget {
  const _ActivityEditor({super.key, this.existing, this.initialDate});
  final Activity? existing;
  final DateTime? initialDate;
  @override
  ConsumerState<_ActivityEditor> createState() => _ActivityEditorState();
}

class _ActivityEditorState extends ConsumerState<_ActivityEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title;
  late final TextEditingController notes;
  late final String id;
  late DateTime date;
  late ActivityCategory category;
  TimeOfDay? time;
  final tasks = <_TaskDraft>[];
  bool dirty = false;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    id = existing?.id ?? newId();
    title = TextEditingController(text: existing?.title ?? '');
    notes = TextEditingController(text: existing?.notes ?? '');
    date = existing?.date ?? widget.initialDate ?? dateOnly(DateTime.now());
    category = existing?.category ?? ActivityCategory.work;
    if (existing?.minuteOfDay != null) {
      time = TimeOfDay(
          hour: existing!.minuteOfDay! ~/ 60,
          minute: existing.minuteOfDay! % 60);
    }
    tasks.addAll((existing?.tasks ?? []).map(_TaskDraft.new));
  }

  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    for (final task in tasks) {
      task.controller.dispose();
    }
    super.dispose();
  }

  void changed() {
    if (!dirty) {
      setState(() => dirty = true);
    }
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime(1900),
        lastDate: DateTime(2100, 12, 31));
    if (picked != null && mounted) {
      setState(() {
        date = picked;
        dirty = true;
      });
    }
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(
        context: context,
        initialTime: time ?? const TimeOfDay(hour: 9, minute: 0),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!));
    if (picked != null && mounted) {
      setState(() {
        time = picked;
        dirty = true;
      });
    }
  }

  Future<void> leave() async {
    if (saving) {
      return;
    }
    final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('¿Descartar cambios?'),
              content: const Text(
                  'Los cambios de este formulario todavía no se han guardado.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Seguir editando')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Descartar'))
              ],
            ));
    if (discard != true || !mounted) {
      return;
    }
    setState(() => dirty = false);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) {
      context.pop();
    }
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) {
      return;
    }
    final activity = Activity(
        id: id,
        title: title.text,
        notes: notes.text,
        category: category,
        date: date,
        minuteOfDay: time == null ? null : time!.hour * 60 + time!.minute,
        tasks: tasks
            .map((t) => AgendaTask(
                id: t.id, description: t.controller.text, isDone: t.done))
            .toList());
    final validation = activity.validate();
    if (validation != null) {
      setState(() => error = validation);
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref.read(repositoryProvider).save(activity);
      if (!mounted) {
        return;
      }
      setState(() {
        dirty = false;
        saving = false;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) {
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error =
              'No se pudo guardar. Conservamos tus cambios en el formulario; vuelve a intentarlo.';
        });
      }
    }
  }

  void moveTask(int from, int to) => setState(() {
        tasks.insert(to, tasks.removeAt(from));
        dirty = true;
      });

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !dirty && !saving,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !saving) {
            leave();
          }
        },
        child: Scaffold(
          appBar: AppBar(
              title: Text(widget.existing == null
                  ? 'Nueva actividad'
                  : 'Editar actividad')),
          body: SafeArea(
              child: Form(
                  key: form,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      TextFormField(
                          controller: title,
                          decoration:
                              const InputDecoration(labelText: 'Título *'),
                          textCapitalization: TextCapitalization.sentences,
                          enabled: !saving,
                          onChanged: (_) => changed(),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Escribe un título.'
                                  : null),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<ActivityCategory>(
                          value: category,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'Categoría'),
                          items: [
                            for (final item in ActivityCategory.values)
                              DropdownMenuItem(
                                  value: item, child: Text(item.label))
                          ],
                          onChanged: saving
                              ? null
                              : (value) => setState(() {
                                    category = value!;
                                    dirty = true;
                                  })),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                          onPressed: saving ? null : pickDate,
                          icon: const Icon(Icons.calendar_month),
                          label: Text(DateFormat.yMMMMd('es').format(date))),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Todo el día'),
                          value: time == null,
                          onChanged: saving
                              ? null
                              : (allDay) => setState(() {
                                    time = allDay
                                        ? null
                                        : const TimeOfDay(hour: 9, minute: 0);
                                    dirty = true;
                                  })),
                      if (time != null)
                        OutlinedButton.icon(
                            onPressed: saving ? null : pickTime,
                            icon: const Icon(Icons.schedule),
                            label: Text(
                                '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}')),
                      const SizedBox(height: 20),
                      TextFormField(
                          controller: notes,
                          enabled: !saving,
                          onChanged: (_) => changed(),
                          minLines: 3,
                          maxLines: 8,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                              labelText: 'Notas (opcional)')),
                      const SizedBox(height: 24),
                      Text('Pendientes (opcional)',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      for (var i = 0; i < tasks.length; i++) taskEditor(i),
                      Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                              onPressed: saving
                                  ? null
                                  : () => setState(() {
                                        tasks.add(_TaskDraft(AgendaTask(
                                            id: newId(), description: '')));
                                        dirty = true;
                                      }),
                              icon: const Icon(Icons.add),
                              label: const Text('Añadir pendiente'))),
                      if (error != null)
                        Semantics(
                            liveRegion: true,
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Text(error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error)))),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                          onPressed: saving ? null : save,
                          icon: const Icon(Icons.check),
                          label: Text(
                              saving ? 'Guardando…' : 'Guardar actividad')),
                      if (saving) const LinearProgressIndicator(),
                    ],
                  ))),
        ),
      );

  Widget taskEditor(int index) {
    final task = tasks[index];
    return Card(
        key: ValueKey(task.id),
        child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              TextFormField(
                  controller: task.controller,
                  enabled: !saving,
                  onChanged: (_) => changed(),
                  decoration:
                      InputDecoration(labelText: 'Pendiente ${index + 1}'),
                  minLines: 1,
                  maxLines: 4,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe el pendiente o elimínalo.'
                      : null),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                Checkbox(
                    value: task.done,
                    semanticLabel: 'Completado',
                    onChanged: saving
                        ? null
                        : (value) => setState(() {
                              task.done = value!;
                              dirty = true;
                            })),
                const Text('Completado'),
                IconButton(
                    tooltip: 'Subir pendiente',
                    onPressed: saving || index == 0
                        ? null
                        : () => moveTask(index, index - 1),
                    icon: const Icon(Icons.arrow_upward)),
                IconButton(
                    tooltip: 'Bajar pendiente',
                    onPressed: saving || index == tasks.length - 1
                        ? null
                        : () => moveTask(index, index + 1),
                    icon: const Icon(Icons.arrow_downward)),
                IconButton(
                    tooltip: 'Eliminar pendiente',
                    onPressed: saving
                        ? null
                        : () {
                            setState(() {
                              tasks.removeAt(index);
                              dirty = true;
                            });
                            // Se dispone después de que el campo deje el árbol de widgets.
                            WidgetsBinding.instance.addPostFrameCallback(
                                (_) => task.controller.dispose());
                          },
                    icon: const Icon(Icons.delete_outline)),
              ]),
            ])));
  }
}
