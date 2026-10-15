import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import 'agenda_backup.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});
  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}
class _BackupScreenState extends ConsumerState<BackupScreen> {
  static const channel = MethodChannel('miagenda/platform');
  AgendaBackup? preview;
  bool busy = false;
  String? message;
  @override
  void dispose() { preview?.close(); super.dispose(); }
  Future<void> perform(Future<void> Function() callback) async {
    if (busy) { return; }
    setState(() { busy = true; message = null; });
    try { await callback(); }
    on FormatException catch (e) { if (mounted) { setState(() => message = e.message); } }
    on StateError catch (e) { if (mounted) { setState(() => message = e.message); } }
    catch (_) { if (mounted) { setState(() => message = 'No se pudo completar. La agenda existente no se ha reemplazado.'); } }
    finally { if (mounted) { setState(() => busy = false); } }
  }
  Future<void> choose() async {
    final input = await channel.invokeMethod<Uint8List>('readBackup');
    if (input == null) { return; }
    final result = await AgendaBackup.inspect(input);
    if (!mounted) { await result.close(); return; }
    final old = preview;
    setState(() => preview = result);
    await old?.close();
  }
  Future<void> restore() async {
    final source = preview;
    if (source == null) { return; }
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Restaurar respaldo'),
      content: Text('Se copiarán ${source.activities} actividades y ${source.tasks} tareas únicamente si esta agenda está vacía. La app anterior y el archivo original se conservan.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restaurar'))]));
    if (confirmed != true || !mounted) { return; }
    await source.restoreIntoEmpty(ref.read(repositoryProvider));
    ref.invalidate(activitiesProvider);
    await ref.read(reminderCoordinatorProvider).synchronize();
    if (mounted) { setState(() => message = 'Restauración completada: ${source.activities} actividades y ${source.tasks} tareas.'); }
  }
  Future<void> save() async {
    final bytes = await AgendaBackup.export(ref.read(repositoryProvider));
    final saved = await channel.invokeMethod<bool>('saveBackup', bytes);
    if (saved == true && mounted) { setState(() => message = 'Respaldo guardado en el documento elegido.'); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Respaldo y recuperación')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      if (const bool.fromEnvironment('RECOVERY_BUILD')) const Text('Mi Agenda Recuperación: esta app está separada de Mi Agenda anterior. Conserva ambas hasta comprobar todos los datos.'),
      const SizedBox(height: 16),
      const Text('Selecciona el TXT original de aShellYou o un respaldo SQLite. Primero se comprueba una copia temporal. Restaurar solo funciona con esta agenda vacía; no sobrescribe actividades existentes.'),
      const SizedBox(height: 16),
      FilledButton(onPressed: busy ? null : () => perform(choose), child: const Text('Seleccionar respaldo')),
      if (preview != null) ...[
        const SizedBox(height: 16),
        Text('Respaldo válido: ${preview!.activities} actividades y ${preview!.tasks} tareas.'),
        OutlinedButton(onPressed: busy ? null : () => perform(restore), child: const Text('Restaurar en esta agenda vacía')),
      ],
      const SizedBox(height: 16),
      OutlinedButton(onPressed: busy ? null : () => perform(save), child: const Text('Guardar copia de esta agenda')),
      if (busy) const LinearProgressIndicator(),
      if (message != null) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(message!)),
      const Text('El respaldo contiene tus notas y tareas. Guárdalo en un lugar privado. Para los avisos restaurados, revisa los permisos desde la campana.'),
    ]));
}
