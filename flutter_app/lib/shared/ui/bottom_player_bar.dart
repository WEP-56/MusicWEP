import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../features/media/domain/media_route_state.dart';
import '../../features/media/music_sheet_library_providers.dart';
import '../../features/media/presentation/widgets/music_track_actions.dart';
import '../../features/player/domain/player_models.dart';
import '../../features/player/player_providers.dart';

class SharedBottomPlayerBar extends ConsumerStatefulWidget {
  const SharedBottomPlayerBar({super.key, this.backgroundActive = false});

  final bool backgroundActive;

  @override
  ConsumerState<SharedBottomPlayerBar> createState() =>
      _SharedBottomPlayerBarState();
}

class _SharedBottomPlayerBarState extends ConsumerState<SharedBottomPlayerBar> {
  bool _progressHover = false;
  bool _progressDragging = false;
  double? _dragProgress;
  bool _showSpeedBubble = false;
  bool _showVolumeBubble = false;

  @override
  Widget build(BuildContext context) {
    final themeColors = AppTheme.colorsOf(context);
    final playerState = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final track = playerState.currentTrack;
    final plugin = playerState.plugin;
    final playlistVisible = playerState.playlistPanelVisible;
    final displayedProgress = _dragProgress ?? _progressValue(playerState);
    final favorite = track == null
        ? false
        : ref.watch(isFavoriteMusicProvider(track));

    return Container(
      height: 82,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(
          alpha: widget.backgroundActive
              ? (Theme.of(context).brightness == Brightness.dark ? 0.56 : 0.44)
              : 1,
        ),
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: Column(
        children: <Widget>[
          MouseRegion(
            onEnter: (_) => setState(() => _progressHover = true),
            onExit: (_) => setState(() => _progressHover = false),
            child: SizedBox(
              height: 10,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: _progressHover || _progressDragging ? 4 : 2,
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: _progressHover || _progressDragging
                        ? 6
                        : 0,
                  ),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
                  inactiveTrackColor: const Color(0xFFE5E5E5),
                  activeTrackColor: themeColors.accent,
                  thumbColor: themeColors.accent,
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      _progressHover || _progressDragging ? -2 : 0,
                    ),
                    child: Slider(
                      value: displayedProgress,
                      onChangeStart: track == null
                          ? null
                          : (value) {
                              setState(() {
                                _progressDragging = true;
                                _dragProgress = value;
                              });
                            },
                      onChanged: track == null
                          ? null
                          : (value) {
                              setState(() {
                                _dragProgress = value;
                              });
                            },
                      onChangeEnd: track == null
                          ? null
                          : (value) async {
                              final duration = playerState.duration;
                              setState(() {
                                _progressDragging = false;
                                _dragProgress = null;
                              });
                              if (duration == null ||
                                  duration <= Duration.zero) {
                                return;
                              }
                              await controller.seek(
                                Duration(
                                  milliseconds:
                                      (duration.inMilliseconds * value).round(),
                                ),
                              );
                            },
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: <Widget>[
                  _PlayerArtwork(
                    artwork: track?.artwork,
                    onTap: track == null || plugin == null
                        ? null
                        : () => _openDetail(context, plugin.storageKey, track),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 290,
                    child: _InfoSection(
                      track: track,
                      pluginName: plugin?.displayName,
                      favorite: favorite,
                      progressText:
                          playerState.errorMessage ??
                          (track == null
                              ? '双击任意歌曲开始播放'
                              : '${track.artist}    ${_formatClock(playerState.position)}/${_formatClock(playerState.duration ?? Duration.zero)}'),
                      hasError: playerState.errorMessage != null,
                      onOpenDetail: track == null || plugin == null
                          ? null
                          : () =>
                                _openDetail(context, plugin.storageKey, track),
                      onToggleFavorite: track == null
                          ? null
                          : () => toggleFavoriteTrack(context, ref, track),
                    ),
                  ),
                  const Spacer(),
                  _PlayerIcon(
                    icon: Icons.skip_previous_rounded,
                    enabled: playerState.hasTrack && playerState.hasPrevious,
                    onTap: playerState.hasTrack
                        ? controller.playPrevious
                        : null,
                  ),
                  const SizedBox(width: 14),
                  InkWell(
                    onTap: playerState.hasTrack
                        ? controller.togglePlayback
                        : null,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: playerState.hasTrack
                            ? themeColors.accent
                            : const Color(0xFFE6E6E6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        playerState.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: playerState.hasTrack
                            ? Colors.white
                            : const Color(0xFFAAAAAA),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  _PlayerIcon(
                    icon: Icons.skip_next_rounded,
                    enabled: playerState.hasTrack && playerState.hasNext,
                    onTap: playerState.hasTrack ? controller.playNext : null,
                  ),
                  const Spacer(),
                  _QualityButton(
                    quality: playerState.currentQuality,
                    enabled: playerState.hasTrack,
                    onPressed: () => _showQualityDialog(context, playerState),
                  ),
                  const SizedBox(width: 14),
                  _HoverPopupAnchor(
                    icon: Icons.speed_rounded,
                    tooltip: '倍速',
                    highlighted: _showSpeedBubble,
                    showBubble: _showSpeedBubble,
                    onShowChanged: (value) {
                      setState(() {
                        _showSpeedBubble = value;
                        if (value) {
                          _showVolumeBubble = false;
                        }
                      });
                    },
                    bubble: _VerticalValueBubble(
                      label: '${playerState.rate.toStringAsFixed(2)}x',
                      min: 0.25,
                      max: 2.0,
                      value: playerState.rate,
                      onChanged: controller.setRate,
                    ),
                  ),
                  const SizedBox(width: 14),
                  _HoverPopupAnchor(
                    icon: playerState.volume == 0
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_outlined,
                    tooltip: '音量',
                    highlighted: _showVolumeBubble,
                    showBubble: _showVolumeBubble,
                    onShowChanged: (value) {
                      setState(() {
                        _showVolumeBubble = value;
                        if (value) {
                          _showSpeedBubble = false;
                        }
                      });
                    },
                    bubble: _VerticalValueBubble(
                      label: '${(playerState.volume * 100).round()}%',
                      min: 0,
                      max: 1,
                      value: playerState.volume,
                      onChanged: controller.setVolume,
                    ),
                  ),
                  const SizedBox(width: 14),
                  _PlayerIcon(
                    icon: Icons.lyrics_outlined,
                    highlighted: playerState.desktopLyricVisible,
                    onTap: controller.toggleDesktopLyric,
                  ),
                  const SizedBox(width: 14),
                  _PlayerIcon(
                    icon: switch (playerState.repeatMode) {
                      RepeatMode.listLoop => Icons.repeat_rounded,
                      RepeatMode.singleLoop => Icons.repeat_one_rounded,
                      RepeatMode.shuffle => Icons.shuffle_rounded,
                    },
                    highlighted: true,
                    tooltip: switch (playerState.repeatMode) {
                      RepeatMode.listLoop => '列表循环',
                      RepeatMode.singleLoop => '单曲循环',
                      RepeatMode.shuffle => '随机播放',
                    },
                    onTap: controller.toggleRepeatMode,
                  ),
                  const SizedBox(width: 14),
                  _PlayerIcon(
                    icon: Icons.playlist_play_rounded,
                    highlighted: playlistVisible,
                    onTap: controller.togglePlaylistPanel,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showQualityDialog(
    BuildContext context,
    dynamic playerState,
  ) async {
    String selectedQuality = playerState.currentQuality;
    bool currentOnly = false;

    final result = await showDialog<(String, bool)>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('切换音质'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final quality in const <String>[
                    'low',
                    'standard',
                    'high',
                    'super',
                  ])
                    RadioListTile<String>(
                      value: quality,
                      groupValue: selectedQuality,
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          selectedQuality = value;
                        });
                      },
                      title: Text(_qualityLabel(quality)),
                    ),
                  CheckboxListTile(
                    value: currentOnly,
                    onChanged: (value) {
                      setState(() {
                        currentOnly = value ?? false;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    title: const Text('仅设置当前歌曲'),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).pop((selectedQuality, currentOnly)),
                  child: const Text('确认'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    await ref
        .read(playerControllerProvider.notifier)
        .setQuality(result.$1, applyToCurrentTrackOnly: result.$2);
  }

  void _openDetail(BuildContext context, String pluginId, dynamic track) {
    context.push(
      '/music',
      extra: MusicRouteState(pluginId: pluginId, musicItem: track),
    );
  }

  double _progressValue(dynamic state) {
    final duration = state.duration as Duration?;
    if (duration == null || duration <= Duration.zero) {
      return 0;
    }
    return (state.position as Duration).inMilliseconds /
        duration.inMilliseconds;
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.track,
    required this.pluginName,
    required this.favorite,
    required this.progressText,
    required this.hasError,
    this.onOpenDetail,
    this.onToggleFavorite,
  });

  final dynamic track;
  final String? pluginName;
  final bool favorite;
  final String progressText;
  final bool hasError;
  final VoidCallback? onOpenDetail;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final title = track?.title?.toString() ?? '未开始播放';
    final textColor = Theme.of(context).colorScheme.onSurface;
    final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: InkWell(
                onTap: onOpenDetail,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ),
            if (pluginName != null) ...<Widget>[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.colorsOf(context).accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  pluginName!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                progressText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: hasError
                      ? Theme.of(context).colorScheme.error
                      : secondaryColor,
                ),
              ),
            ),
            if (onToggleFavorite != null)
              InkWell(
                onTap: onToggleFavorite,
                child: Icon(
                  favorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 18,
                  color: favorite
                      ? const Color(0xFFE44B4B)
                      : const Color(0xFF7A7A7A),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _QualityButton extends StatelessWidget {
  const _QualityButton({
    required this.quality,
    required this.enabled,
    required this.onPressed,
  });

  final String quality;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final disabled = Theme.of(context).disabledColor;
    return InkWell(
      onTap: enabled ? onPressed : null,
      child: Text(
        _qualityShortLabel(quality),
        style: TextStyle(fontSize: 22, color: enabled ? onSurface : disabled),
      ),
    );
  }
}

class _HoverPopupAnchor extends StatefulWidget {
  const _HoverPopupAnchor({
    required this.icon,
    required this.tooltip,
    required this.showBubble,
    required this.highlighted,
    required this.onShowChanged,
    required this.bubble,
  });

  final IconData icon;
  final String tooltip;
  final bool showBubble;
  final bool highlighted;
  final ValueChanged<bool> onShowChanged;
  final Widget bubble;

  @override
  State<_HoverPopupAnchor> createState() => _HoverPopupAnchorState();
}

class _HoverPopupAnchorState extends State<_HoverPopupAnchor> {
  final GlobalKey _anchorKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  Timer? _hideTimer;

  @override
  void didUpdateWidget(covariant _HoverPopupAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (widget.showBubble) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _show() {
    _hideTimer?.cancel();
    widget.onShowChanged(true);
    _showOverlay();
  }

  void _hideDelayed() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 140), () {
      widget.onShowChanged(false);
      _removeOverlay();
    });
  }

  void _showOverlay() {
    final context = _anchorKey.currentContext;
    if (context == null) {
      return;
    }
    final overlay = Overlay.of(context, rootOverlay: true);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (overlay == null || renderBox == null || !renderBox.attached) {
      return;
    }
    final topLeft = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: topLeft.dx + size.width / 2 - 29,
          top: topLeft.dy - 132,
          child: MouseRegion(
            onEnter: (_) => _show(),
            onExit: (_) => _hideDelayed(),
            child: Material(color: Colors.transparent, child: widget.bubble),
          ),
        );
      },
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      key: _anchorKey,
      onEnter: (_) => _show(),
      onExit: (_) => _hideDelayed(),
      child: _PlayerIcon(
        icon: widget.icon,
        highlighted: widget.highlighted,
        tooltip: widget.tooltip,
      ),
    );
  }
}

class _VerticalValueBubble extends StatelessWidget {
  const _VerticalValueBubble({
    required this.label,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double min;
  final double max;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.colorsOf(context).accent;
    final panelColor = Theme.of(context).colorScheme.surfaceContainerHigh;
    final labelColor = Theme.of(context).colorScheme.onSurface;
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 58,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: 110,
              child: RotatedBox(
                quarterTurns: 3,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: accent,
                    thumbColor: accent,
                    inactiveTrackColor: const Color(0xFFD8D8D8),
                  ),
                  child: Slider(
                    min: min,
                    max: max,
                    divisions: ((max - min) / (max <= 1 ? 0.01 : 0.05)).round(),
                    value: value.clamp(min, max),
                    onChanged: onChanged,
                  ),
                ),
              ),
            ),
            Text(label, style: TextStyle(fontSize: 12, color: labelColor)),
          ],
        ),
      ),
    );
  }
}

class _PlayerArtwork extends StatelessWidget {
  const _PlayerArtwork({required this.artwork, this.onTap});

  final String? artwork;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget placeholder() {
      final scheme = Theme.of(context).colorScheme;
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.music_note_rounded, color: scheme.onSurfaceVariant),
      );
    }

    final child = artwork == null || artwork!.isEmpty
        ? placeholder()
        : ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              artwork!,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => placeholder(),
            ),
          );

    return onTap == null ? child : InkWell(onTap: onTap, child: child);
  }
}

class _PlayerIcon extends StatelessWidget {
  const _PlayerIcon({
    required this.icon,
    this.enabled = true,
    this.highlighted = false,
    this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final bool enabled;
  final bool highlighted;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.colorsOf(context).accent;
    final iconColor =
        Theme.of(context).iconTheme.color ??
        Theme.of(context).colorScheme.onSurface;
    final child = InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: Icon(
        icon,
        size: 22,
        color: !enabled
            ? const Color(0xFFB6B6B6)
            : highlighted
            ? accent
            : iconColor,
      ),
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}

String _formatClock(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

String _qualityShortLabel(String quality) {
  return switch (quality) {
    'low' => 'LQ',
    'high' => 'HQ',
    'super' => 'SQ',
    _ => 'SD',
  };
}

String _qualityLabel(String quality) {
  return switch (quality) {
    'low' => '低音质',
    'high' => '高音质',
    'super' => '超高音质',
    _ => '标准音质',
  };
}
