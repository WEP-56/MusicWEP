import '../../../core/storage/json_file_store.dart';
import '../domain/plugin.dart';

class PluginMetaRepository {
  const PluginMetaRepository(this._store);

  final JsonFileStore _store;

  Future<Map<String, PluginMetaRecord>> loadAll() async {
    final raw = await _store.readObject();
    final result = <String, PluginMetaRecord>{};
    raw.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        result[key] = PluginMetaRecord.fromJson(value);
      } else if (value is Map) {
        result[key] = PluginMetaRecord.fromJson(
          value.map(
            (nestedKey, nestedValue) =>
                MapEntry(nestedKey.toString(), nestedValue),
          ),
        );
      }
    });
    return result;
  }

  Future<void> saveAll(Map<String, PluginMetaRecord> records) {
    return _store.writeJson(
      records.map((key, value) => MapEntry(key, value.toJson())),
    );
  }
}
