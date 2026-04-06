import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../core/media/media_models.dart';
import '../../core/storage/json_file_store.dart';
import '../plugins/plugin_providers.dart';
import 'application/local_music_sheet_repository.dart';
import 'application/starred_music_sheet_repository.dart';

final localMusicSheetRepositoryProvider =
    FutureProvider<LocalMusicSheetRepository>((ref) async {
      final appPaths = await ref.watch(appPathsProvider.future);
      return LocalMusicSheetRepository(
        JsonFileStore(
          path.join(appPaths.appDataDirectory.path, 'local_music_sheets.json'),
        ),
      );
    });

final starredMusicSheetRepositoryProvider =
    FutureProvider<StarredMusicSheetRepository>((ref) async {
      final appPaths = await ref.watch(appPathsProvider.future);
      return StarredMusicSheetRepository(
        JsonFileStore(
          path.join(
            appPaths.appDataDirectory.path,
            'starred_music_sheets.json',
          ),
        ),
      );
    });

class LocalMusicSheetController extends AsyncNotifier<List<MusicSheetItem>> {
  @override
  Future<List<MusicSheetItem>> build() async {
    final repository = await ref.watch(
      localMusicSheetRepositoryProvider.future,
    );
    return repository.loadAll();
  }

  Future<List<MusicSheetItem>> createSheet(
    String title, {
    List<MusicItem> musicList = const <MusicItem>[],
    String? artwork,
  }) async {
    final repository = await ref.read(localMusicSheetRepositoryProvider.future);
    final next = await repository.createSheet(
      title,
      musicList: musicList,
      artwork: artwork,
    );
    state = AsyncData(next);
    return next;
  }

  Future<List<MusicSheetItem>> renameSheet(String sheetId, String title) async {
    final repository = await ref.read(localMusicSheetRepositoryProvider.future);
    final next = await repository.renameSheet(sheetId, title);
    state = AsyncData(next);
    return next;
  }

  Future<List<MusicSheetItem>> deleteSheet(String sheetId) async {
    final repository = await ref.read(localMusicSheetRepositoryProvider.future);
    final next = await repository.deleteSheet(sheetId);
    state = AsyncData(next);
    return next;
  }

  Future<List<MusicSheetItem>> addMusicToSheet(
    String sheetId,
    List<MusicItem> musicItems,
  ) async {
    final repository = await ref.read(localMusicSheetRepositoryProvider.future);
    final next = await repository.addMusicToSheet(sheetId, musicItems);
    state = AsyncData(next);
    return next;
  }

  Future<List<MusicSheetItem>> removeMusicFromSheet(
    String sheetId,
    List<MusicItem> musicItems,
  ) async {
    final repository = await ref.read(localMusicSheetRepositoryProvider.future);
    final next = await repository.removeMusicFromSheet(sheetId, musicItems);
    state = AsyncData(next);
    return next;
  }

  Future<bool> toggleFavoriteMusic(MusicItem musicItem) async {
    final current = state.valueOrNull ?? const <MusicSheetItem>[];
    final favoriteSheet = current.firstWhere(
      (sheet) => sheet.id == defaultLocalMusicSheetId,
      orElse: () => defaultFavoriteSheet,
    );
    final exists = favoriteSheet.musicList.any(
      (item) => item.platform == musicItem.platform && item.id == musicItem.id,
    );
    if (exists) {
      await removeMusicFromSheet(defaultLocalMusicSheetId, <MusicItem>[
        musicItem,
      ]);
      return false;
    }
    await addMusicToSheet(defaultLocalMusicSheetId, <MusicItem>[musicItem]);
    return true;
  }
}

final localMusicSheetControllerProvider =
    AsyncNotifierProvider<LocalMusicSheetController, List<MusicSheetItem>>(
      LocalMusicSheetController.new,
    );

final localMusicSheetByIdProvider = Provider.family<MusicSheetItem?, String>((
  ref,
  sheetId,
) {
  final sheets = ref.watch(localMusicSheetControllerProvider);
  return sheets.maybeWhen(
    data: (items) {
      for (final item in items) {
        if (item.id == sheetId) {
          return item;
        }
      }
      return null;
    },
    orElse: () => null,
  );
});

final favoriteMusicKeysProvider = Provider<Set<String>>((ref) {
  final sheet = ref.watch(
    localMusicSheetByIdProvider(defaultLocalMusicSheetId),
  );
  if (sheet == null) {
    return const <String>{};
  }
  return sheet.musicList.map((item) => '${item.platform}@${item.id}').toSet();
});

final isFavoriteMusicProvider = Provider.family<bool, MusicItem>((ref, track) {
  final keys = ref.watch(favoriteMusicKeysProvider);
  return keys.contains('${track.platform}@${track.id}');
});

class StarredMusicSheetController extends AsyncNotifier<List<MusicSheetItem>> {
  @override
  Future<List<MusicSheetItem>> build() async {
    final repository = await ref.watch(
      starredMusicSheetRepositoryProvider.future,
    );
    return repository.loadAll();
  }

  Future<List<MusicSheetItem>> toggle(MusicSheetItem sheet) async {
    final repository = await ref.read(
      starredMusicSheetRepositoryProvider.future,
    );
    final next = await repository.toggle(sheet);
    state = AsyncData(next);
    return next;
  }

  Future<List<MusicSheetItem>> remove(MusicSheetItem sheet) async {
    final repository = await ref.read(
      starredMusicSheetRepositoryProvider.future,
    );
    final next = await repository.remove(sheet);
    state = AsyncData(next);
    return next;
  }
}

final starredMusicSheetControllerProvider =
    AsyncNotifierProvider<StarredMusicSheetController, List<MusicSheetItem>>(
      StarredMusicSheetController.new,
    );

final starredMusicSheetByIdentityProvider =
    Provider.family<MusicSheetItem?, ({String platform, String sheetId})>((
      ref,
      key,
    ) {
      final sheets = ref.watch(starredMusicSheetControllerProvider);
      return sheets.maybeWhen(
        data: (items) {
          for (final item in items) {
            if (item.platform == key.platform && item.id == key.sheetId) {
              return item;
            }
          }
          return null;
        },
        orElse: () => null,
      );
    });

final isMusicSheetStarredProvider = Provider.family<bool, MusicSheetItem>((
  ref,
  sheet,
) {
  final sheets = ref.watch(starredMusicSheetControllerProvider);
  return sheets.maybeWhen(
    data: (items) => items.any(
      (item) => item.platform == sheet.platform && item.id == sheet.id,
    ),
    orElse: () => false,
  );
});
