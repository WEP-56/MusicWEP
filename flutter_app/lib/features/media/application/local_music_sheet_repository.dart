import 'dart:math' as math;

import '../../../core/media/media_constants.dart';
import '../../../core/media/media_models.dart';
import '../../../core/storage/json_file_store.dart';

const String defaultLocalMusicSheetId = 'favorite';

class LocalMusicSheetRepository {
  const LocalMusicSheetRepository(this._store);

  final JsonFileStore _store;

  Future<List<MusicSheetItem>> loadAll() async {
    final data = await _store.readList();
    final sheets = data
        .whereType<Map>()
        .map(
          (entry) => MusicSheetItem.fromJson(
            entry.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .map(_normalizeSheet)
        .toList(growable: true);

    final favoriteIndex = sheets.indexWhere(
      (sheet) => sheet.id == defaultLocalMusicSheetId,
    );
    if (favoriteIndex < 0) {
      sheets.insert(0, defaultFavoriteSheet);
      await _persist(sheets);
      return sheets;
    }

    if (favoriteIndex > 0) {
      final favorite = sheets.removeAt(favoriteIndex);
      sheets.insert(0, favorite);
    }
    return sheets;
  }

  Future<MusicSheetItem?> getById(String sheetId) async {
    final sheets = await loadAll();
    return sheets.where((sheet) => sheet.id == sheetId).firstOrNull;
  }

  Future<List<MusicSheetItem>> createSheet(
    String title, {
    List<MusicItem> musicList = const <MusicItem>[],
    String? artwork,
  }) async {
    final sheets = await loadAll();
    final next = <MusicSheetItem>[
      ...sheets,
      MusicSheetItem(
        platform: localPluginName,
        id: _createSheetId(),
        title: title.trim().isEmpty ? '新建歌单' : title.trim(),
        createAt: DateTime.now().millisecondsSinceEpoch,
        artwork: artwork,
        musicList: musicList,
      ),
    ];
    await _persist(next);
    return next;
  }

  Future<List<MusicSheetItem>> renameSheet(String sheetId, String title) async {
    final sheets = await loadAll();
    final next = sheets
        .map((sheet) {
          if (sheet.id != sheetId || sheet.id == defaultLocalMusicSheetId) {
            return sheet;
          }
          return MusicSheetItem(
            platform: sheet.platform,
            id: sheet.id,
            title: title.trim().isEmpty ? sheet.title : title.trim(),
            artist: sheet.artist,
            description: sheet.description,
            artwork: sheet.artwork,
            worksNum: sheet.worksNum,
            playCount: sheet.playCount,
            createAt: sheet.createAt,
            musicList: sheet.musicList,
            extra: sheet.extra,
          );
        })
        .toList(growable: false);
    await _persist(next);
    return next;
  }

  Future<List<MusicSheetItem>> deleteSheet(String sheetId) async {
    final sheets = await loadAll();
    final next = sheets
        .where(
          (sheet) =>
              sheet.id == defaultLocalMusicSheetId || sheet.id != sheetId,
        )
        .toList(growable: false);
    await _persist(next);
    return next;
  }

  Future<List<MusicSheetItem>> updateSheet(MusicSheetItem target) async {
    final sheets = await loadAll();
    final index = sheets.indexWhere((sheet) => sheet.id == target.id);
    final next = sheets.toList(growable: true);
    if (index >= 0) {
      next[index] = _normalizeSheet(target);
    } else {
      next.add(_normalizeSheet(target));
    }
    await _persist(next);
    return next;
  }

  Future<List<MusicSheetItem>> addMusicToSheet(
    String sheetId,
    List<MusicItem> musicItems,
  ) async {
    final sheets = await loadAll();
    final index = sheets.indexWhere((sheet) => sheet.id == sheetId);
    if (index < 0) {
      return sheets;
    }

    final target = sheets[index];
    final nextTracks = target.musicList.toList(growable: true);
    final seen = {for (final item in nextTracks) '${item.platform}@${item.id}'};
    for (final item in musicItems) {
      final key = '${item.platform}@${item.id}';
      if (seen.add(key)) {
        nextTracks.add(item);
      }
    }

    final next = sheets.toList(growable: true);
    next[index] = MusicSheetItem(
      platform: target.platform,
      id: target.id,
      title: target.title,
      artist: target.artist,
      description: target.description,
      artwork: nextTracks.isNotEmpty ? nextTracks.last.artwork : target.artwork,
      worksNum: nextTracks.length,
      playCount: target.playCount,
      createAt: target.createAt,
      musicList: nextTracks,
      extra: target.extra,
    );
    await _persist(next);
    return next;
  }

  Future<List<MusicSheetItem>> removeMusicFromSheet(
    String sheetId,
    List<MusicItem> musicItems,
  ) async {
    final sheets = await loadAll();
    final index = sheets.indexWhere((sheet) => sheet.id == sheetId);
    if (index < 0) {
      return sheets;
    }

    final removedKeys = {
      for (final item in musicItems) '${item.platform}@${item.id}',
    };
    final target = sheets[index];
    final nextTracks = target.musicList
        .where((item) => !removedKeys.contains('${item.platform}@${item.id}'))
        .toList(growable: false);

    final next = sheets.toList(growable: true);
    next[index] = MusicSheetItem(
      platform: target.platform,
      id: target.id,
      title: target.title,
      artist: target.artist,
      description: target.description,
      artwork: nextTracks.isNotEmpty ? nextTracks.last.artwork : null,
      worksNum: nextTracks.length,
      playCount: target.playCount,
      createAt: target.createAt,
      musicList: nextTracks,
      extra: target.extra,
    );
    await _persist(next);
    return next;
  }

  Future<void> _persist(List<MusicSheetItem> sheets) {
    final favorite =
        sheets
            .where((sheet) => sheet.id == defaultLocalMusicSheetId)
            .firstOrNull ??
        defaultFavoriteSheet;
    final normalized = <MusicSheetItem>[
      favorite,
      ...sheets.where((sheet) => sheet.id != defaultLocalMusicSheetId),
    ];
    return _store.writeJson(
      normalized.map((sheet) => sheet.toJson()).toList(growable: false),
    );
  }

  MusicSheetItem _normalizeSheet(MusicSheetItem sheet) {
    if (sheet.id == defaultLocalMusicSheetId) {
      return MusicSheetItem(
        platform: localPluginName,
        id: defaultLocalMusicSheetId,
        title: defaultFavoriteSheet.title,
        artist: sheet.artist,
        description: sheet.description,
        artwork: sheet.artwork,
        worksNum: sheet.musicList.length,
        playCount: sheet.playCount,
        createAt: sheet.createAt ?? -1,
        musicList: sheet.musicList,
        extra: sheet.extra,
      );
    }

    return MusicSheetItem(
      platform: localPluginName,
      id: sheet.id,
      title: sheet.title,
      artist: sheet.artist,
      description: sheet.description,
      artwork: sheet.artwork,
      worksNum: sheet.musicList.length,
      playCount: sheet.playCount,
      createAt: sheet.createAt ?? DateTime.now().millisecondsSinceEpoch,
      musicList: sheet.musicList,
      extra: sheet.extra,
    );
  }

  String _createSheetId() {
    final now = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final random = math.Random().nextInt(1 << 32).toRadixString(36);
    return '$now$random';
  }
}

const MusicSheetItem defaultFavoriteSheet = MusicSheetItem(
  platform: localPluginName,
  id: defaultLocalMusicSheetId,
  title: '我喜欢',
  createAt: -1,
);

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
