import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/app.dart';
import 'app/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  final container = ProviderContainer();
  final service = container.read(reminderCoordinatorProvider);
  service.onTap = (id) => agendaRouter.push('/activity/${Uri.encodeComponent(id)}');
  await service.synchronize(); // Un error de avisos no impide abrir la agenda.
  String? launch;
  if (service.initialized) { launch = await service.gateway.launchActivity(); }
  runApp(UncontrolledProviderScope(container: container, child: const _ReminderLifecycle(child: AgendaApp())));
  if (launch?.isNotEmpty == true) {
    WidgetsBinding.instance.addPostFrameCallback((_) => service.onTap?.call(launch!));
  }
}

class _ReminderLifecycle extends ConsumerStatefulWidget {
  const _ReminderLifecycle({required this.child});
  final Widget child;
  @override
  ConsumerState<_ReminderLifecycle> createState() => _ReminderLifecycleState();
}
class _ReminderLifecycleState extends ConsumerState<_ReminderLifecycle> with WidgetsBindingObserver {
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) { ref.read(reminderCoordinatorProvider).synchronize(); }
  }
  @override
  Widget build(BuildContext context) => widget.child;
}
