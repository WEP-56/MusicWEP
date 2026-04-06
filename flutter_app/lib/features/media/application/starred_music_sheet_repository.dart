import '../../../core/media/media_models.dart';
import '../../../core/storage/json_file_store.dart';

class StarredMusicSheetRepository {
  const StarredMusicSheetRepository(this._store);

  final JsonFileStore _store;

  Future<List<MusicSheetItem>> loadAll() async {
    final data = await _store.readList();
    return data
        .whereType<Map>()
        .map(
          (entry) => MusicSheetItem.fromJson(
            entry.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  Future<List<MusicSheetItem>> toggle(MusicSheetItem sheet) async {
    final current = await loadAll();
    final exists = current.any(
      (item) => item.platform == sheet.platform && item.id == sheet.id,
    );
    final next = exists
        ? current
              .where(
                (item) =>
                    !(item.platform == sheet.platform && item.id == sheet.id),
              )
              .toList(growable: false)
        : <MusicSheetItem>[sheet, ...current];
    await _persist(next);
    return next;
  }

  Future<List<MusicSheetItem>> remove(MusicSheetItem sheet) async {
    final current = await loadAll();
    final next = current
        .where(
          (item) => !(item.platform == sheet.platform && item.id == sheet.id),
        )
        .toList(growable: false);
    await _persist(next);
    return next;
  }

  Future<MusicSheetItem?> findByIdentity(
    String platform,
    String sheetId,
  ) async {
    final items = await loadAll();
    for (final item in items) {
      if (item.platform == platform && item.id == sheetId) {
        return item;
      }
    }
    return null;
  }

  Future<void> _persist(List<MusicSheetItem> sheets) {
    return _store.writeJson(
      sheets.map((sheet) => sheet.toJson()).toList(growable: false),
    );
  }
}
