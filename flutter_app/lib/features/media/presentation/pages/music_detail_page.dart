import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/media/media_models.dart';
import '../../../../shared/ui/app_shell.dart';
import '../../../player/domain/player_models.dart';
import '../../../player/player_providers.dart';
import '../../domain/media_route_state.dart';
import '../../media_providers.dart';
import '../../music_sheet_library_providers.dart';
import '../widgets/music_track_actions.dart';

class MusicDetailPage extends ConsumerWidget {
  const MusicDetailPage({super.key, required this.state});

  final MusicRouteState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(musicDetailProvider(state));
    final playerState = ref.watch(playerControllerProvider);

    return AppShell(
      title: '歌曲详情',
      subtitle: '歌词与歌曲详细信息。',
      child: detail.when(
        data: (data) {
          final music = data.musicItem;
          final parsedLyric = ParsedLyric.fromRaw(
            raw: data.lyric?.rawLyric,
            translation: data.lyric?.translation,
          );
          final favorite = ref.watch(isFavoriteMusicProvider(music));
          final currentLyricIndex =
              playerState.currentTrack?.id == music.id &&
                  playerState.currentTrack?.platform == music.platform
              ? playerState.currentLyricIndex
              : -1;

          return Column(
            children: <Widget>[
              Expanded(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _DetailHeroCard(
                        music: music,
                        favorite: favorite,
                        onToggleFavorite: () =>
                            toggleFavoriteTrack(context, ref, music),
                        onAddToSheet: () => showAddToMusicSheetDialog(
                          context,
                          ref,
                          tracks: <MusicItem>[music],
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 2,
                      child: _LyricPanel(
                        lyric: parsedLyric,
                        currentLyricIndex: currentLyricIndex,
                      ),
                    ),
                  ],
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

class _DetailHeroCard extends StatelessWidget {
  const _DetailHeroCard({
    required this.music,
    required this.favorite,
    required this.onToggleFavorite,
    required this.onAddToSheet,
  });

  final MusicItem music;
  final bool favorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAddToSheet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTheme.colorsOf(context).accent;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: theme.brightness == Brightness.dark
              ? <Color>[
                  theme.colorScheme.surfaceContainerHighest,
                  theme.colorScheme.surfaceContainerLow,
                ]
              : const <Color>[Color(0xFFF4D0DC), Color(0xFFF6F4F2)],
        ),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 20),
            Text(
              music.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  music.artist,
                  style: TextStyle(
                    fontSize: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    music.platform,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: music.artwork?.isNotEmpty == true
                  ? Image.network(
                      music.artwork!,
                      width: 320,
                      height: 320,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const _MusicArtworkFallback(),
                    )
                  : const _MusicArtworkFallback(),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  tooltip: favorite ? '从我喜欢移除' : '加入我喜欢',
                  onPressed: onToggleFavorite,
                  icon: Icon(
                    favorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: favorite
                        ? const Color(0xFFE44B4B)
                        : theme.iconTheme.color,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: '添加到歌单',
                  onPressed: onAddToSheet,
                  icon: const Icon(Icons.library_add_outlined),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: '评论功能后续接入',
                  onPressed: null,
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MusicArtworkFallback extends StatelessWidget {
  const _MusicArtworkFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFF48FB1), Color(0xFFF8BBD0)],
        ),
      ),
      child: const Icon(Icons.album_rounded, size: 96, color: Colors.white),
    );
  }
}

class _LyricPanel extends StatelessWidget {
  const _LyricPanel({required this.lyric, required this.currentLyricIndex});

  final ParsedLyric lyric;
  final int currentLyricIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.dividerColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: lyric.lines.isEmpty
          ? Center(
              child: Text(
                '暂无歌词',
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.builder(
              itemCount: lyric.lines.length,
              itemBuilder: (context, index) {
                final line = lyric.lines[index];
                final highlighted = index == currentLyricIndex;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: <Widget>[
                      Text(
                        line.text.isEmpty ? '...' : line.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: highlighted ? 22 : 18,
                          height: 1.5,
                          fontWeight: highlighted
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: highlighted
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (line.translation?.trim().isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            line.translation!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: highlighted ? 16 : 14,
                              color: highlighted
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
