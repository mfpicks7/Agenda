import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/app_database.dart';
import '../features/activities/activity.dart';
import '../features/activities/activity_repository.dart';

final repositoryProvider = Provider<ActivityRepository>((ref) {
  final repository = ActivityRepository(AppDatabase.device());
  ref.onDispose(repository.close);
  return repository;
});
final activitiesProvider = StreamProvider<List<Activity>>(
  (ref) => ref.watch(repositoryProvider).watchAll(),
);
