import '../../../core/storage/json_file_store.dart';
import '../domain/download_models.dart';

class DownloadRepository {
  const DownloadRepository(this._store);

  final JsonFileStore _store;

  Future<List<DownloadTask>> loadAll() async {
    final raw = await _store.readList();
    return raw
        .whereType<Map>()
        .map(
          (entry) => DownloadTask.fromJson(
            entry.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  Future<void> saveAll(List<DownloadTask> tasks) {
    return _store.writeJson(
      tasks.map((task) => task.toJson()).toList(growable: false),
    );
  }
}
