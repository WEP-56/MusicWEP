import '../../../core/media/media_models.dart';
import '../../../core/storage/json_file_store.dart';
import 'local_plugin_service.dart';

class LocalMusicRepository {
  LocalMusicRepository(this._store, {LocalPluginService? importer})
    : _importer = importer ?? const LocalPluginService();

  final JsonFileStore _store;
  final LocalPluginService _importer;

  Future<List<MusicItem>> load() async {
    final data = await _store.readList();
    return data
        .whereType<Map>()
        .map(
          (entry) => MusicItem.fromJson(
            entry.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  Future<List<MusicItem>> importFiles(List<String> filePaths) async {
    final existing = await load();
    final next = existing.toList(growable: true);
    final seenIds = {for (final item in existing) item.id};

    for (final filePath in filePaths) {
      final imported = await _importer.importMusicItem(filePath);
      if (seenIds.contains(imported.id)) {
        final index = next.indexWhere((item) => item.id == imported.id);
        if (index >= 0) {
          next[index] = imported;
        }
        continue;
      }
      next.add(imported);
      seenIds.add(imported.id);
    }

    await _persist(next);
    return next.toList(growable: false);
  }

  Future<List<MusicItem>> importFolder(String folderPath) async {
    final items = await _importer.importMusicSheet(folderPath);
    if (items.isEmpty) {
      return load();
    }

    final existing = await load();
    final next = existing.toList(growable: true);
    final seenIds = {for (final item in existing) item.id};

    for (final item in items) {
      if (seenIds.contains(item.id)) {
        final index = next.indexWhere((entry) => entry.id == item.id);
        if (index >= 0) {
          next[index] = item;
        }
        continue;
      }
      next.add(item);
      seenIds.add(item.id);
    }

    await _persist(next);
    return next.toList(growable: false);
  }

  Future<void> clear() async {
    await _store.writeJson(const <dynamic>[]);
  }

  Future<void> _persist(List<MusicItem> items) {
    return _store.writeJson(
      items.map((entry) => entry.toJson()).toList(growable: false),
    );
  }
}
