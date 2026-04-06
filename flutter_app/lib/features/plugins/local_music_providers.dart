import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../core/media/media_models.dart';
import '../../core/storage/json_file_store.dart';
import 'application/local_music_repository.dart';
import 'plugin_providers.dart';

final localMusicRepositoryProvider = FutureProvider<LocalMusicRepository>((
  ref,
) async {
  final appPaths = await ref.watch(appPathsProvider.future);
  return LocalMusicRepository(
    JsonFileStore(
      path.join(appPaths.appDataDirectory.path, 'local_music.json'),
    ),
  );
});

class LocalMusicController extends AsyncNotifier<List<MusicItem>> {
  @override
  Future<List<MusicItem>> build() async {
    final repository = await ref.watch(localMusicRepositoryProvider.future);
    return repository.load();
  }

  Future<List<MusicItem>> importFiles(List<String> filePaths) async {
    final repository = await ref.read(localMusicRepositoryProvider.future);
    final next = await repository.importFiles(filePaths);
    state = AsyncData(next);
    return next;
  }

  Future<List<MusicItem>> importFolder(String folderPath) async {
    final repository = await ref.read(localMusicRepositoryProvider.future);
    final next = await repository.importFolder(folderPath);
    state = AsyncData(next);
    return next;
  }

  Future<void> clear() async {
    final repository = await ref.read(localMusicRepositoryProvider.future);
    await repository.clear();
    state = const AsyncData(<MusicItem>[]);
  }
}

final localMusicControllerProvider =
    AsyncNotifierProvider<LocalMusicController, List<MusicItem>>(
      LocalMusicController.new,
    );
