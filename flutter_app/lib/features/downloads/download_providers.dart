import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../core/media/media_models.dart';
import '../../core/storage/json_file_store.dart';
import '../plugins/plugin_providers.dart';
import 'application/download_controller.dart';
import 'application/download_repository.dart';
import 'application/download_settings_repository.dart';
import 'domain/download_models.dart';

final downloadRepositoryProvider = FutureProvider<DownloadRepository>((
  ref,
) async {
  final appPaths = await ref.watch(appPathsProvider.future);
  return DownloadRepository(
    JsonFileStore(
      path.join(appPaths.appDataDirectory.path, 'download_tasks.json'),
    ),
  );
});

final downloadSettingsProvider = FutureProvider<DownloadSettings>((ref) async {
  final appPaths = await ref.watch(appPathsProvider.future);
  return DownloadSettingsRepository(
    configStore: JsonFileStore(appPaths.configFilePath),
    appPaths: appPaths,
  ).load();
});

final downloadControllerProvider =
    AsyncNotifierProvider<DownloadController, List<DownloadTask>>(
      DownloadController.new,
    );

final downloadTaskByTrackProvider = Provider.family<DownloadTask?, MusicItem>((
  ref,
  track,
) {
  final tasks = ref.watch(downloadControllerProvider);
  return tasks.maybeWhen(
    data: (items) {
      for (final item in items) {
        if (item.track.platform == track.platform &&
            item.track.id == track.id) {
          return item;
        }
      }
      return null;
    },
    orElse: () => null,
  );
});

final downloadedTasksProvider = Provider<List<DownloadTask>>((ref) {
  final tasks = ref.watch(downloadControllerProvider).valueOrNull;
  if (tasks == null) {
    return const <DownloadTask>[];
  }
  return tasks
      .where((task) => task.status == DownloadTaskStatus.completed)
      .toList(growable: false);
});

final downloadingTasksProvider = Provider<List<DownloadTask>>((ref) {
  final tasks = ref.watch(downloadControllerProvider).valueOrNull;
  if (tasks == null) {
    return const <DownloadTask>[];
  }
  return tasks
      .where((task) => task.status != DownloadTaskStatus.completed)
      .toList(growable: false);
});
