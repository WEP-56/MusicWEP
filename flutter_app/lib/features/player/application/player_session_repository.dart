import '../../../core/storage/json_file_store.dart';
import '../domain/player_session.dart';

class PlayerSessionRepository {
  const PlayerSessionRepository(this._store);

  final JsonFileStore _store;

  Future<PlayerSession?> load() async {
    final raw = await _store.readObject();
    if (raw.isEmpty) {
      return null;
    }
    return PlayerSession.fromJson(raw);
  }

  Future<void> save(PlayerSession session) async {
    await _store.writeJson(session.toJson());
  }

  Future<void> clear() async {
    await _store.writeJson(const <String, dynamic>{});
  }
}
