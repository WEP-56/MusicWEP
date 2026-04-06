import '../../../core/media/media_models.dart';
import '../../../core/storage/json_file_store.dart';
import '../domain/recent_playback_entry.dart';

class RecentPlaybackRepository {
  const RecentPlaybackRepository(this._store);

  static const int maxEntries = 200;

  final JsonFileStore _store;

  Future<List<RecentPlaybackEntry>> load() async {
    final data = await _store.readList();
    return data
        .whereType<Map>()
        .map(
          (entry) => RecentPlaybackEntry.fromJson(
            entry.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  Future<List<RecentPlaybackEntry>> record({
    required String pluginId,
    required MusicItem musicItem,
  }) async {
    final existing = await load();
    final next = <RecentPlaybackEntry>[
      RecentPlaybackEntry(
        pluginId: pluginId,
        musicItem: musicItem,
        playedAt: DateTime.now(),
      ),
      ...existing.where(
        (entry) =>
            !(entry.pluginId == pluginId &&
                entry.musicItem.platform == musicItem.platform &&
                entry.musicItem.id == musicItem.id),
      ),
    ];
    final trimmed = next.take(maxEntries).toList(growable: false);
    await _store.writeJson(
      trimmed.map((entry) => entry.toJson()).toList(growable: false),
    );
    return trimmed;
  }

  Future<void> clear() async {
    await _store.writeJson(const <dynamic>[]);
  }
}
