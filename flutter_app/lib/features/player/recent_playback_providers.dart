import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../core/media/media_models.dart';
import '../../core/storage/json_file_store.dart';
import '../plugins/plugin_providers.dart';
import 'application/recent_playback_repository.dart';
import 'domain/recent_playback_entry.dart';

final recentPlaybackRepositoryProvider =
    FutureProvider<RecentPlaybackRepository>((ref) async {
      final appPaths = await ref.watch(appPathsProvider.future);
      return RecentPlaybackRepository(
        JsonFileStore(
          path.join(appPaths.appDataDirectory.path, 'recent_playback.json'),
        ),
      );
    });

class RecentPlaybackController
    extends AsyncNotifier<List<RecentPlaybackEntry>> {
  @override
  Future<List<RecentPlaybackEntry>> build() async {
    final repository = await ref.watch(recentPlaybackRepositoryProvider.future);
    return repository.load();
  }

  Future<void> record({
    required String pluginId,
    required MusicItem musicItem,
  }) async {
    final repository = await ref.read(recentPlaybackRepositoryProvider.future);
    final next = await repository.record(
      pluginId: pluginId,
      musicItem: musicItem,
    );
    state = AsyncData(next);
  }

  Future<void> clear() async {
    final repository = await ref.read(recentPlaybackRepositoryProvider.future);
    await repository.clear();
    state = const AsyncData(<RecentPlaybackEntry>[]);
  }
}

final recentPlaybackControllerProvider =
    AsyncNotifierProvider<RecentPlaybackController, List<RecentPlaybackEntry>>(
      RecentPlaybackController.new,
    );
