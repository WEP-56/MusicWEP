import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/media/media_constants.dart';
import '../../../../core/media/media_models.dart';
import '../../../../shared/ui/app_shell.dart';
import '../../../downloads/presentation/widgets/download_track_actions.dart';
import '../../../player/player_providers.dart';
import '../../application/local_music_sheet_repository.dart';
import '../../domain/media_route_state.dart';
import '../../media_providers.dart';
import '../../music_sheet_library_providers.dart';
import '../widgets/music_sheet_detail_view.dart';
import '../widgets/music_track_actions.dart';

class MusicSheetPage extends ConsumerWidget {
  const MusicSheetPage({
    super.key,
    required this.pluginId,
    required this.sheetId,
  });

  final String pluginId;
  final String sheetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLocal = pluginId == localPluginName || pluginId == localPluginHash;
    if (isLocal) {
      return _LocalMusicSheetPage(sheetId: sheetId);
    }
    return _StarredMusicSheetPage(pluginId: pluginId, sheetId: sheetId);
  }
}

class _LocalMusicSheetPage extends ConsumerWidget {
  const _LocalMusicSheetPage({required this.sheetId});

  final String sheetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheetsAsync = ref.watch(localMusicSheetControllerProvider);
    final sheet = ref.watch(localMusicSheetByIdProvider(sheetId));
    final favoriteKeys = ref.watch(favoriteMusicKeysProvider);

    return AppShell(
      title: '我的歌单',
      subtitle: '查看本地歌单与收藏歌曲。',
      child: sheetsAsync.when(
        data: (_) {
          if (sheet == null) {
            return const Center(child: Text('歌单不存在或已被删除。'));
          }

          final displaySheet = sheet.id == defaultLocalMusicSheetId
              ? MusicSheetItem(
                  platform: sheet.platform,
                  id: sheet.id,
                  title: '我喜欢',
                  artist: sheet.artist,
                  description: sheet.description,
                  artwork: sheet.artwork,
                  worksNum: sheet.worksNum,
                  playCount: sheet.playCount,
                  createAt: sheet.createAt,
                  musicList: sheet.musicList,
                  extra: sheet.extra,
                )
              : sheet;

          return MusicSheetDetailView(
            sheet: displaySheet,
            tracks: sheet.musicList,
            favoriteKeys: favoriteKeys,
            onToggleFavorite: (track) =>
                toggleFavoriteTrack(context, ref, track),
            onAddTrackToSheet: (track) => showAddToMusicSheetDialog(
              context,
              ref,
              tracks: <MusicItem>[track],
            ),
            onDownloadTrack: (track) async {
              await queueTrackDownload(context, ref, track);
            },
            onRemoveTrackFromCurrentSheet: (track) => ref
                .read(localMusicSheetControllerProvider.notifier)
                .removeMusicFromSheet(sheet.id, <MusicItem>[track]),
            showPlatformColumn: false,
            searchHint: '搜索歌单内歌曲',
            emptyText: '当前歌单还没有歌曲。',
            onPlayQueue: (tracks, startIndex) async {
              final plugin = ref.read(pluginByIdProvider(localPluginName));
              if (plugin == null) {
                return;
              }
              await ref
                  .read(playerControllerProvider.notifier)
                  .playQueue(
                    plugin: plugin,
                    queue: tracks,
                    startIndex: startIndex,
                  );
            },
            actions: <MusicSheetHeaderAction>[
              if (sheet.id != defaultLocalMusicSheetId)
                MusicSheetHeaderAction(
                  label: '删除歌单',
                  icon: Icons.delete_outline_rounded,
                  onPressed: () async {
                    await ref
                        .read(localMusicSheetControllerProvider.notifier)
                        .deleteSheet(sheet.id);
                    if (context.mounted) {
                      context.go(
                        '/music-sheet/${Uri.encodeComponent(localPluginName)}/$defaultLocalMusicSheetId',
                      );
                    }
                  },
                ),
            ],
          );
        },
        error: (error, _) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _StarredMusicSheetPage extends ConsumerWidget {
  const _StarredMusicSheetPage({required this.pluginId, required this.sheetId});

  final String pluginId;
  final String sheetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final starredSheets = ref.watch(starredMusicSheetControllerProvider);
    final favoriteKeys = ref.watch(favoriteMusicKeysProvider);
    final savedSheet = ref.watch(
      starredMusicSheetByIdentityProvider((
        platform: pluginId,
        sheetId: sheetId,
      )),
    );

    return AppShell(
      title: '我的收藏',
      subtitle: '查看已收藏的远程歌单。',
      child: starredSheets.when(
        data: (_) {
          if (savedSheet == null) {
            return const Center(child: Text('收藏歌单不存在或已被取消收藏。'));
          }

          final detail = ref.watch(
            sheetDetailProvider(
              SheetRouteState(pluginId: pluginId, sheetItem: savedSheet),
            ),
          );

          return detail.when(
            data: (data) {
              final sheet = data?.sheetItem ?? savedSheet;
              final tracks = data?.musicList ?? savedSheet.musicList;

              return MusicSheetDetailView(
                sheet: MusicSheetItem(
                  platform: sheet.platform,
                  id: sheet.id,
                  title: sheet.title,
                  artist: sheet.artist,
                  description: sheet.description,
                  artwork: sheet.artwork,
                  worksNum: sheet.worksNum,
                  playCount: sheet.playCount,
                  createAt: sheet.createAt,
                  musicList: tracks,
                  extra: sheet.extra,
                ),
                tracks: tracks,
                favoriteKeys: favoriteKeys,
                onToggleFavorite: (track) =>
                    toggleFavoriteTrack(context, ref, track),
                onAddTrackToSheet: (track) => showAddToMusicSheetDialog(
                  context,
                  ref,
                  tracks: <MusicItem>[track],
                ),
                onDownloadTrack: (track) async {
                  await queueTrackDownload(context, ref, track);
                },
                onPlayQueue: (queue, startIndex) async {
                  final plugin = ref.read(pluginByIdProvider(pluginId));
                  if (plugin == null) {
                    return;
                  }
                  await ref
                      .read(playerControllerProvider.notifier)
                      .playQueue(
                        plugin: plugin,
                        queue: queue,
                        startIndex: startIndex,
                      );
                },
                actions: <MusicSheetHeaderAction>[
                  MusicSheetHeaderAction(
                    label: '取消收藏',
                    icon: Icons.favorite_rounded,
                    onPressed: () async {
                      await ref
                          .read(starredMusicSheetControllerProvider.notifier)
                          .remove(savedSheet);
                      if (context.mounted) {
                        context.go(
                          '/music-sheet/${Uri.encodeComponent(localPluginName)}/$defaultLocalMusicSheetId',
                        );
                      }
                    },
                  ),
                ],
              );
            },
            error: (error, _) => Center(child: Text(error.toString())),
            loading: () => const Center(child: CircularProgressIndicator()),
          );
        },
        error: (error, _) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
