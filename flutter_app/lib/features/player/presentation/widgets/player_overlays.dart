import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/media/media_models.dart';
import '../../../downloads/presentation/widgets/download_track_actions.dart';
import '../../../downloads/presentation/widgets/download_track_button.dart';
import '../../../media/music_sheet_library_providers.dart';
import '../../../media/presentation/widgets/music_track_actions.dart';
import '../../player_providers.dart';

class PlayerOverlays extends ConsumerWidget {
  const PlayerOverlays({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerControllerProvider);
    if (!playerState.playlistPanelVisible) {
      return const SizedBox.shrink();
    }
    return const Stack(children: <Widget>[_PlaylistPanel()]);
  }
}

class _PlaylistPanel extends ConsumerWidget {
  const _PlaylistPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final favoriteKeys = ref.watch(favoriteMusicKeysProvider);
    final theme = Theme.of(context);
    final accent = AppTheme.colorsOf(context).accent;
    final softAccent = AppTheme.colorsOf(context).softAccent;

    return Positioned.fill(
      child: GestureDetector(
        onTap: controller.closePlaylistPanel,
        child: Material(
          color: const Color(0x33000000),
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {},
              child: Material(
                color: theme.colorScheme.surface,
                child: Container(
                  width: 460,
                  margin: const EdgeInsets.only(top: 54, bottom: 72),
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: theme.dividerColor)),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 18,
                        offset: Offset(-4, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                '播放列表（${playerState.queue.length}首）',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            OutlinedButton(
                              onPressed: controller.clearQueue,
                              child: const Text('清空'),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: theme.dividerColor),
                      Expanded(
                        child: ListView.separated(
                          itemCount: playerState.queue.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: theme.dividerColor),
                          itemBuilder: (context, index) {
                            final track = playerState.queue[index];
                            final selected =
                                playerState.currentTrack?.id == track.id &&
                                playerState.currentTrack?.platform ==
                                    track.platform;
                            final favorite = favoriteKeys.contains(
                              '${track.platform}@${track.id}',
                            );
                            return InkWell(
                              onTap: () => controller.playAt(index),
                              onDoubleTap: () => controller.playAt(index),
                              onSecondaryTapDown: (details) =>
                                  showTrackContextMenu(
                                    context,
                                    position: details.globalPosition,
                                    track: track,
                                    onDownload: () async {
                                      await queueTrackDownload(
                                        context,
                                        ref,
                                        track,
                                      );
                                    },
                                    onAddToSheet: () =>
                                        showAddToMusicSheetDialog(
                                          context,
                                          ref,
                                          tracks: <MusicItem>[track],
                                        ),
                                  ),
                              child: Container(
                                height: 40,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                color: selected
                                    ? softAccent
                                    : Colors.transparent,
                                child: Row(
                                  children: <Widget>[
                                    InkWell(
                                      onTap: () => toggleFavoriteTrack(
                                        context,
                                        ref,
                                        track,
                                      ),
                                      child: Icon(
                                        favorite
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        size: 18,
                                        color: favorite
                                            ? const Color(0xFFE44B4B)
                                            : theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    DownloadTrackButton(
                                      track: track,
                                      showTooltip: false,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        track.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: selected
                                              ? accent
                                              : theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        track.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accent,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        track.platform,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    InkWell(
                                      onTap: () =>
                                          controller.removeFromQueueAt(index),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
