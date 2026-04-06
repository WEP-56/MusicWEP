import '../../../core/storage/json_file_store.dart';
import '../domain/plugin.dart';

class PluginSubscriptionRepository {
  const PluginSubscriptionRepository(this._store);

  final JsonFileStore _store;

  Future<List<PluginSubscription>> loadAll() async {
    final raw = await _store.readList();
    return raw
        .whereType<Map>()
        .map(
          (entry) => PluginSubscription.fromJson(
            entry.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  Future<void> saveAll(List<PluginSubscription> subscriptions) {
    return _store.writeJson(
      subscriptions.map((entry) => entry.toJson()).toList(growable: false),
    );
  }
}
