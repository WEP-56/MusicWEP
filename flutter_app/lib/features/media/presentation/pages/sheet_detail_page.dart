import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/media/media_models.dart';
import '../../../../shared/ui/app_shell.dart';
import '../../../downloads/presentation/widgets/download_track_actions.dart';
import '../../../player/player_providers.dart';
import '../../domain/media_route_state.dart';
import '../../media_providers.dart';
import '../../music_sheet_library_providers.dart';
import '../widgets/music_sheet_detail_view.dart';
import '../widgets/music_track_actions.dart';

class SheetDetailPage extends ConsumerWidget {
  const SheetDetailPage({super.key, required this.state});

  final SheetRouteState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(sheetDetailProvider(state));
    final isStarred = ref.watch(isMusicSheetStarredProvider(state.sheetItem));
    final favoriteKeys = ref.watch(favoriteMusicKeysProvider);

    return AppShell(
      title: '热门歌单',
      subtitle: '歌单详情与歌曲列表。',
      child: detail.when(
        data: (data) {
          final sheet = data?.sheetItem ?? state.sheetItem;
          final tracks = data?.musicList ?? sheet.musicList;

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
              final plugin = ref.read(pluginByIdProvider(state.pluginId));
              if (plugin == null || queue.isEmpty) {
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
                label: isStarred ? '取消收藏' : '收藏',
                icon: isStarred
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                onPressed: () => ref
                    .read(starredMusicSheetControllerProvider.notifier)
                    .toggle(
                      MusicSheetItem(
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
                    ),
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
