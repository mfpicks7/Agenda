import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';

class ReminderSettingsScreen extends ConsumerStatefulWidget {
  const ReminderSettingsScreen({super.key});
  @override
  ConsumerState<ReminderSettingsScreen> createState() =>
      _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends ConsumerState<ReminderSettingsScreen>
    with WidgetsBindingObserver {
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() =>
        action(() => ref.read(reminderCoordinatorProvider).synchronize()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) {
      action(() => ref.read(reminderCoordinatorProvider).synchronize());
    }
  }

  Future<void> action(Future<void> Function() callback,
      {String? success}) async {
    if (!mounted || busy) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await callback();
      if (mounted && success != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'No se pudo completar. Comprueba los permisos y vuelve a intentar.');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(reminderCoordinatorProvider);
    return Scaffold(
        appBar: AppBar(title: const Text('Avisos y permisos')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(
              service.permission.enabled
                  ? 'Notificaciones permitidas'
                  : 'Notificaciones bloqueadas o sin permiso',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(service.permission.exact
              ? 'Precisión de alarmas habilitada'
              : 'Horario aproximado: Android puede retrasar los avisos.'),
          if (!service.permission.sound)
            const Text(
                'El canal de avisos está sin sonido. Revísalo en los ajustes del teléfono.'),
          const SizedBox(height: 12),
          Text('Avisos futuros programados: ${service.scheduledCount}'),
        TextButton.icon(onPressed: () => context.push('/backup'), icon: const Icon(Icons.backup_outlined), label: const Text('Respaldo y recuperación')),
          if (service.deviceZone != null)
            Text('Zona del teléfono: ${service.deviceZone}'),
          const SizedBox(height: 16),
          const Text(
              'Elige los avisos en cada actividad. Las actividades de todo el día tienen su propia hora de aviso. Los avisos que ya pasaron no se envían.'),
          if (service.warning != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(service.warning!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          if (error != null)
            Text(error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 16),
          FilledButton(
              onPressed:
                  busy ? null : () => action(service.requestNotifications),
              child: const Text('Permitir notificaciones')),
          OutlinedButton(
              onPressed: busy ? null : () => action(service.requestExact),
              child: const Text('Activar precisión de avisos')),
          OutlinedButton(
              onPressed:
                  busy ? null : () => action(service.gateway.openSettings),
              child: const Text('Ajustes de notificaciones del teléfono')),
          OutlinedButton(
              onPressed: busy || !service.permission.enabled
                  ? null
                  : () => action(service.showTest,
                      success:
                          'Aviso de prueba enviado. Revisa la barra de notificaciones y el volumen.'),
              child: const Text('Probar aviso ahora')),
          OutlinedButton(
              onPressed: busy ||
                      !service.permission.enabled ||
                      !service.permission.exact
                  ? null
                  : () => action(service.scheduleTest,
                      success:
                          'Prueba programada. Sal de la app y espera unos 10 segundos.'),
              child: const Text('Probar aviso en 10 segundos')),
          TextButton(
              onPressed: busy ? null : () => action(service.synchronize),
              child: const Text('Volver a sincronizar avisos')),
          if (busy) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          const Text(
              'En algunos teléfonos debes permitir actividad en segundo plano. No fuerces la detención de la app: Android bloquea los avisos hasta que vuelvas a abrirla. El modo No molestar, el canal silenciado y el ahorro de batería pueden impedir el sonido.'),
        ]));
  }
}
