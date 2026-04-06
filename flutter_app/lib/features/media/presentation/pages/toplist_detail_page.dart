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

class TopListDetailPage extends ConsumerWidget {
  const TopListDetailPage({super.key, required this.state});

  final TopListRouteState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(topListDetailProvider(state));
    final favoriteKeys = ref.watch(favoriteMusicKeysProvider);

    return AppShell(
      title: '排行榜',
      subtitle: '榜单详情与歌曲列表。',
      child: detail.when(
        data: (data) {
          return MusicSheetDetailView(
            sheet: MusicSheetItem(
              platform: data.topListItem.platform,
              id: data.topListItem.id,
              title: data.topListItem.title,
              artist: data.topListItem.artist,
              description: _buildDescription(data.topListItem),
              artwork:
                  data.topListItem.artwork ??
                  data.topListItem.extra['coverImg']?.toString(),
              worksNum: data.musicList.length,
              musicList: data.musicList,
              extra: data.topListItem.extra,
            ),
            tracks: data.musicList,
            badgeText: '榜单',
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
            onPlayQueue: (tracks, startIndex) async {
              final plugin = ref.read(pluginByIdProvider(state.pluginId));
              if (plugin == null || tracks.isEmpty) {
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
            actions: const <MusicSheetHeaderAction>[
              MusicSheetHeaderAction(label: '添加', icon: Icons.add_rounded),
            ],
            searchHint: '搜索榜单内歌曲',
          );
        },
        error: (error, _) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  static String _buildDescription(MusicSheetItem topListItem) {
    final candidates = <String>[
      if (topListItem.description?.toString().trim().isNotEmpty ?? false)
        topListItem.description.toString().trim(),
      if (topListItem.artist?.toString().trim().isNotEmpty ?? false)
        topListItem.artist.toString().trim(),
    ];
    return candidates.isEmpty ? '暂无简介' : candidates.first;
  }
}
