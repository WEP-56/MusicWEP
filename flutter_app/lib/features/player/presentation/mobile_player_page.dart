import 'dart:async';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/media/media_constants.dart';
import '../../media/music_sheet_library_providers.dart';
import '../../media/presentation/widgets/music_track_actions.dart';
import '../domain/player_models.dart';
import '../domain/player_state.dart';
import '../player_providers.dart';

/// Full-screen mobile player page: artwork → lyrics → controls.
/// Opened by tapping the mini player bar.
class MobilePlayerPage extends ConsumerStatefulWidget {
  const MobilePlayerPage({super.key});

  @override
  ConsumerState<MobilePlayerPage> createState() => _MobilePlayerPageState();
}

class _MobilePlayerPageState extends ConsumerState<MobilePlayerPage> {
  final ScrollController _lyricScrollController = ScrollController();
  int _lastScrolledIndex = -1;

  @override
  void dispose() {
    _lyricScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerControllerProvider);
    final track = playerState.currentTrack;
    final theme = Theme.of(context);
    final accent = AppTheme.colorsOf(context).accent;

    // Auto-scroll lyrics to current line.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentLyric(playerState.currentLyricIndex);
    });

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // ── Top bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    iconSize: 28,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        Text(
                          track?.title ?? '未在播放',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (track?.artist?.isNotEmpty == true)
                          Text(
                            track!.artist!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Favorite button in the top-right slot
                  Consumer(
                    builder: (ctx, ref, _) {
                      final track = ref.watch(
                        playerControllerProvider.select((s) => s.currentTrack),
                      );
                      if (track == null) return const SizedBox(width: 48);
                      final isFavorite = ref.watch(
                        isFavoriteMusicProvider(track),
                      );
                      return SizedBox(
                        width: 48,
                        child: IconButton(
                          icon: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFavorite
                                ? const Color(0xFFE44B4B)
                                : null,
                          ),
                          onPressed: () =>
                              toggleFavoriteTrack(ctx, ref, track),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── Artwork ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: track?.artwork?.isNotEmpty == true
                      ? Image.network(
                          track!.artwork!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _ArtworkPlaceholder(accent: accent),
                        )
                      : _ArtworkPlaceholder(accent: accent),
                ),
              ),
            ),

            // ── Lyrics ────────────────────────────────────────────────────
            Expanded(
              child: _LyricView(
                lyric: playerState.lyric,
                currentIndex: playerState.currentLyricIndex,
                scrollController: _lyricScrollController,
                accent: accent,
              ),
            ),

            // ── Progress bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ProgressBar(playerState: playerState),
            ),

            // ── Main controls ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _RepeatButton(mode: playerState.repeatMode, accent: accent),
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded),
                    iconSize: 36,
                    onPressed: () => ref
                        .read(playerControllerProvider.notifier)
                        .playPrevious(),
                  ),
                  _PlayPauseButton(
                    isPlaying: playerState.isPlaying,
                    isLoading: playerState.isLoading,
                    accent: accent,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded),
                    iconSize: 36,
                    onPressed: () =>
                        ref.read(playerControllerProvider.notifier).playNext(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.queue_music_rounded),
                    iconSize: 28,
                    onPressed: () {
                      // TODO: open playlist sheet
                    },
                  ),
                ],
              ),
            ),

            // ── Secondary controls ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _QualityButton(currentQuality: playerState.currentQuality),
                  _SpeedButton(rate: playerState.rate),
                  _VolumeButton(volume: playerState.volume),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToCurrentLyric(int index) {
    if (index < 0 || index == _lastScrolledIndex) return;
    _lastScrolledIndex = index;
    if (!_lyricScrollController.hasClients) return;
    const lineHeight = 44.0;
    final viewportHeight = _lyricScrollController.position.viewportDimension;
    final targetOffset =
        (index * lineHeight) - (viewportHeight / 2) + (lineHeight / 2);
    _lyricScrollController.animateTo(
      targetOffset.clamp(
        0,
        _lyricScrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }
}

// ── Lyric view ──────────────────────────────────────────────────────────────

class _LyricView extends StatelessWidget {
  const _LyricView({
    required this.lyric,
    required this.currentIndex,
    required this.scrollController,
    required this.accent,
  });

  final ParsedLyric lyric;
  final int currentIndex;
  final ScrollController scrollController;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!lyric.hasContent) {
      return Center(
        child: Text(
          '暂无歌词',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }
    if (lyric.lines.isEmpty) {
      // Raw lyric without timestamps — show as scrollable text.
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Text(
          lyric.raw ?? '',
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.8,
          ),
        ),
      );
    }
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: lyric.lines.length,
      itemExtent: 44,
      itemBuilder: (context, index) {
        final line = lyric.lines[index];
        final isCurrent = index == currentIndex;
        return Center(
          child: Text(
            line.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isCurrent ? 16 : 14,
              fontWeight:
                  isCurrent ? FontWeight.w700 : FontWeight.w400,
              color: isCurrent
                  ? accent
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}

// ── Progress bar ─────────────────────────────────────────────────────────────

class _ProgressBar extends ConsumerWidget {
  const _ProgressBar({required this.playerState});

  final PlayerState playerState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accent = AppTheme.colorsOf(context).accent;
    final position = playerState.position;
    final duration = playerState.duration ?? Duration.zero;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      children: <Widget>[
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: accent,
            inactiveTrackColor: theme.colorScheme.surfaceContainerHigh,
            thumbColor: accent,
          ),
          child: Slider(
            value: progress,
            onChanged: (value) {
              if (duration.inMilliseconds > 0) {
                final target = Duration(
                  milliseconds: (value * duration.inMilliseconds).round(),
                );
                ref.read(playerControllerProvider.notifier).seek(target);
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                _formatDuration(position),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                _formatDuration(duration),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Control buttons ──────────────────────────────────────────────────────────

class _PlayPauseButton extends ConsumerWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.isLoading,
    required this.accent,
  });

  final bool isPlaying;
  final bool isLoading;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () =>
          ref.read(playerControllerProvider.notifier).togglePlayback(),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        child: isLoading
            ? const Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 36,
              ),
      ),
    );
  }
}

class _RepeatButton extends ConsumerWidget {
  const _RepeatButton({required this.mode, required this.accent});

  final RepeatMode mode;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, tooltip) = switch (mode) {
      RepeatMode.listLoop => (Icons.repeat_rounded, '列表循环'),
      RepeatMode.singleLoop => (Icons.repeat_one_rounded, '单曲循环'),
      RepeatMode.shuffle => (Icons.shuffle_rounded, '随机播放'),
    };
    return IconButton(
      icon: Icon(icon, color: accent),
      iconSize: 24,
      tooltip: tooltip,
      onPressed: () {
        final next = switch (mode) {
          RepeatMode.listLoop => RepeatMode.singleLoop,
          RepeatMode.singleLoop => RepeatMode.shuffle,
          RepeatMode.shuffle => RepeatMode.listLoop,
        };
        ref.read(playerControllerProvider.notifier).setRepeatMode(next);
      },
    );
  }
}

class _QualityButton extends ConsumerWidget {
  const _QualityButton({required this.currentQuality});

  final String currentQuality;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accent = AppTheme.colorsOf(context).accent;
    return TextButton(
      onPressed: () => _showQualitySheet(context, ref),
      child: Text(
        _qualityLabel(currentQuality),
        style: TextStyle(color: accent, fontSize: 13),
      ),
    );
  }

  String _qualityLabel(String q) {
    return switch (q) {
      'standard' => '标准',
      'high' => '高品',
      'super' => '超品',
      'low' => '流畅',
      _ => q,
    };
  }

  Future<void> _showQualitySheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '音质选择',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            ...qualityKeys.map(
              (q) => ListTile(
                title: Text(_qualityLabel(q)),
                trailing: ref.watch(
                          playerControllerProvider.select(
                            (s) => s.currentQuality,
                          ),
                        ) ==
                        q
                    ? Icon(
                        Icons.check_rounded,
                        color: AppTheme.colorsOf(ctx).accent,
                      )
                    : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  ref.read(playerControllerProvider.notifier).setQuality(q);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedButton extends ConsumerWidget {
  const _SpeedButton({required this.rate});

  final double rate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = AppTheme.colorsOf(context).accent;
    return TextButton(
      onPressed: () => _showSpeedSheet(context, ref),
      child: Text(
        '${rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 1)}x',
        style: TextStyle(color: accent, fontSize: 13),
      ),
    );
  }

  Future<void> _showSpeedSheet(BuildContext context, WidgetRef ref) async {
    const speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '播放速度',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            ...speeds.map(
              (s) => ListTile(
                title: Text(
                  '${s.toStringAsFixed(s == s.roundToDouble() ? 0 : 2)}x',
                ),
                trailing: ref.watch(
                          playerControllerProvider.select((st) => st.rate),
                        ) ==
                        s
                    ? Icon(
                        Icons.check_rounded,
                        color: AppTheme.colorsOf(ctx).accent,
                      )
                    : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  ref.read(playerControllerProvider.notifier).setRate(s);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VolumeButton extends ConsumerWidget {
  const _VolumeButton({required this.volume});

  final double volume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = AppTheme.colorsOf(context).accent;
    return IconButton(
      icon: Icon(
        volume == 0
            ? Icons.volume_off_rounded
            : volume < 0.5
            ? Icons.volume_down_rounded
            : Icons.volume_up_rounded,
        color: accent,
        size: 22,
      ),
      onPressed: () => _showVolumeSheet(context, ref),
    );
  }

  Future<void> _showVolumeSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                '音量',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, _) {
                  final vol = ref.watch(
                    playerControllerProvider.select((s) => s.volume),
                  );
                  return Slider(
                    value: vol,
                    onChanged: (v) => ref
                        .read(playerControllerProvider.notifier)
                        .setVolume(v),
                    activeColor: AppTheme.colorsOf(ctx).accent,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Artwork placeholder ───────────────────────────────────────────────────────

class _ArtworkPlaceholder extends StatelessWidget {
  const _ArtworkPlaceholder({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: accent.withValues(alpha: 0.12),
      child: Icon(Icons.music_note_rounded, color: accent, size: 80),
    );
  }
}
