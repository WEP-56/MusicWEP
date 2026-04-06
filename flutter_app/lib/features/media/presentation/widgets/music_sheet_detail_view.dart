import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/media/media_models.dart';
import 'music_track_actions.dart';

class MusicSheetHeaderAction {
  const MusicSheetHeaderAction({
    required this.label,
    required this.icon,
    this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;
}

class MusicSheetDetailView extends StatefulWidget {
  const MusicSheetDetailView({
    super.key,
    required this.sheet,
    required this.tracks,
    required this.onPlayQueue,
    required this.favoriteKeys,
    required this.onToggleFavorite,
    required this.onAddTrackToSheet,
    this.searchHint = '搜索歌单内歌曲',
    this.showPlatformColumn = true,
    this.platformLabelBuilder,
    this.emptyText = '没有匹配的歌曲。',
    this.badgeText = '歌单',
    this.actions = const <MusicSheetHeaderAction>[],
    this.onRemoveTrackFromCurrentSheet,
  });

  final MusicSheetItem sheet;
  final List<MusicItem> tracks;
  final Future<void> Function(List<MusicItem> tracks, int startIndex)
  onPlayQueue;
  final Set<String> favoriteKeys;
  final Future<void> Function(MusicItem track) onToggleFavorite;
  final Future<void> Function(MusicItem track) onAddTrackToSheet;
  final String searchHint;
  final bool showPlatformColumn;
  final String Function(MusicItem track)? platformLabelBuilder;
  final String emptyText;
  final String badgeText;
  final List<MusicSheetHeaderAction> actions;
  final Future<void> Function(MusicItem track)? onRemoveTrackFromCurrentSheet;

  @override
  State<MusicSheetDetailView> createState() => _MusicSheetDetailViewState();
}

class _MusicSheetDetailViewState extends State<MusicSheetDetailView> {
  late final TextEditingController _searchController;
  String _query = '';
  String? _selectedTrackId;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredTracks = _filterTracks(widget.tracks, _query);
    final selectedTrack = filteredTracks
        .where((track) => track.id == _selectedTrackId)
        .firstOrNull;

    return Column(
      children: <Widget>[
        _SheetHeader(
          badgeText: widget.badgeText,
          title: widget.sheet.title,
          artwork:
              widget.sheet.artwork ??
              widget.sheet.extra['coverImg']?.toString(),
          playCount: widget.sheet.playCount,
          artist: widget.sheet.artist,
          description: widget.sheet.description,
          searchHint: widget.searchHint,
          searchController: _searchController,
          onSearchChanged: (value) {
            setState(() {
              _query = value.trim();
              if (_selectedTrackId != null &&
                  filteredTracks.every(
                    (track) => track.id != _selectedTrackId,
                  )) {
                _selectedTrackId = null;
              }
            });
          },
          onPlayPressed: filteredTracks.isEmpty
              ? null
              : () => widget.onPlayQueue(filteredTracks, 0),
          actions: widget.actions,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _SheetTrackTable(
            tracks: filteredTracks,
            selectedTrackId: selectedTrack?.id,
            favoriteKeys: widget.favoriteKeys,
            onToggleFavorite: widget.onToggleFavorite,
            onAddTrackToSheet: widget.onAddTrackToSheet,
            onRemoveTrackFromCurrentSheet: widget.onRemoveTrackFromCurrentSheet,
            showPlatformColumn: widget.showPlatformColumn,
            platformLabelBuilder: widget.platformLabelBuilder,
            emptyText: widget.emptyText,
            onTrackTap: (track) {
              setState(() {
                _selectedTrackId = track.id;
              });
            },
            onTrackDoubleTap: (track) {
              final index = filteredTracks.indexWhere(
                (item) => item.id == track.id,
              );
              if (index >= 0) {
                widget.onPlayQueue(filteredTracks, index);
              }
            },
          ),
        ),
      ],
    );
  }

  static List<MusicItem> _filterTracks(List<MusicItem> tracks, String query) {
    if (query.isEmpty) {
      return tracks;
    }
    final keyword = query.toLowerCase();
    return tracks
        .where((track) {
          return track.title.toLowerCase().contains(keyword) ||
              track.artist.toLowerCase().contains(keyword) ||
              (track.album?.toLowerCase().contains(keyword) ?? false);
        })
        .toList(growable: false);
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.badgeText,
    required this.title,
    required this.artwork,
    required this.playCount,
    required this.artist,
    required this.description,
    required this.searchHint,
    required this.searchController,
    required this.onSearchChanged,
    required this.onPlayPressed,
    required this.actions,
  });

  final String badgeText;
  final String title;
  final String? artwork;
  final int? playCount;
  final String? artist;
  final String? description;
  final String searchHint;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onPlayPressed;
  final List<MusicSheetHeaderAction> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTheme.colorsOf(context).accent;
    final textColor = theme.colorScheme.onSurface;
    final secondaryColor = theme.colorScheme.onSurfaceVariant;
    return SizedBox(
      height: 162,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 160,
            height: 160,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: artwork != null && artwork!.isNotEmpty
                  ? Image.network(
                      artwork!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _SheetDetailFallbackCover(title: title),
                    )
                  : _SheetDetailFallbackCover(title: title),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: accent),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (playCount != null)
                  Text(
                    '播放数：$playCount',
                    style: TextStyle(fontSize: 14, color: secondaryColor),
                  ),
                if (artist?.isNotEmpty == true) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    '作者：$artist',
                    style: TextStyle(fontSize: 14, color: secondaryColor),
                  ),
                ] else if (description?.isNotEmpty == true) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: secondaryColor),
                  ),
                ],
                const Spacer(),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: onPlayPressed,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text('播放'),
                    ),
                    for (final action in actions)
                      action.filled
                          ? FilledButton.icon(
                              onPressed: action.onPressed,
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                              ),
                              icon: Icon(action.icon, size: 18),
                              label: Text(action.label),
                            )
                          : OutlinedButton.icon(
                              onPressed: action.onPressed,
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                              ),
                              icon: Icon(action.icon, size: 18),
                              label: Text(action.label),
                            ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 280,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: searchHint,
                suffixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetTrackTable extends StatelessWidget {
  const _SheetTrackTable({
    required this.tracks,
    required this.selectedTrackId,
    required this.favoriteKeys,
    required this.onToggleFavorite,
    required this.onAddTrackToSheet,
    required this.onTrackTap,
    required this.onTrackDoubleTap,
    required this.emptyText,
    this.showPlatformColumn = true,
    this.platformLabelBuilder,
    this.onRemoveTrackFromCurrentSheet,
  });

  final List<MusicItem> tracks;
  final String? selectedTrackId;
  final Set<String> favoriteKeys;
  final Future<void> Function(MusicItem track) onToggleFavorite;
  final Future<void> Function(MusicItem track) onAddTrackToSheet;
  final ValueChanged<MusicItem> onTrackTap;
  final ValueChanged<MusicItem> onTrackDoubleTap;
  final String emptyText;
  final bool showPlatformColumn;
  final String Function(MusicItem track)? platformLabelBuilder;
  final Future<void> Function(MusicItem track)? onRemoveTrackFromCurrentSheet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTheme.colorsOf(context).accent;
    final headerBackground = theme.colorScheme.surfaceContainerHigh;
    final selectedRow = theme.colorScheme.surfaceContainerLow;
    final secondaryColor = theme.colorScheme.onSurfaceVariant;
    if (tracks.isEmpty) {
      return Center(child: Text(emptyText));
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: headerBackground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: <Widget>[
                const SizedBox(width: 54),
                const SizedBox(width: 44, child: Center(child: Text('#'))),
                const Expanded(
                  flex: 4,
                  child: Text(
                    '标题',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const Expanded(
                  flex: 3,
                  child: Text(
                    '歌手',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const Expanded(
                  flex: 3,
                  child: Text(
                    '专辑',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(
                  width: 88,
                  child: Text(
                    '时长',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (showPlatformColumn)
                  const SizedBox(
                    width: 88,
                    child: Text(
                      '来源',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: tracks.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: theme.dividerColor),
              itemBuilder: (context, index) {
                final track = tracks[index];
                final selected = selectedTrackId == track.id;
                final favoriteKey = '${track.platform}@${track.id}';
                final isFavorite = favoriteKeys.contains(favoriteKey);
                return GestureDetector(
                  onSecondaryTapDown: (details) => showTrackContextMenu(
                    context,
                    position: details.globalPosition,
                    track: track,
                    onAddToSheet: () => onAddTrackToSheet(track),
                    onRemoveFromCurrentSheet:
                        onRemoveTrackFromCurrentSheet == null
                        ? null
                        : () => onRemoveTrackFromCurrentSheet!(track),
                  ),
                  child: InkWell(
                    onTap: () => onTrackTap(track),
                    onDoubleTap: () => onTrackDoubleTap(track),
                    child: Container(
                      height: 48,
                      color: selected ? selectedRow : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: 54,
                            child: Row(
                              children: <Widget>[
                                InkWell(
                                  onTap: () => onToggleFavorite(track),
                                  child: Icon(
                                    isFavorite
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    size: 18,
                                    color: isFavorite
                                        ? const Color(0xFFE44B4B)
                                        : const Color(0xFF7A7A7A),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.download_rounded,
                                  size: 18,
                                  color: Color(0xFFB0B0B0),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 44,
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(color: secondaryColor),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              track.album ?? '-',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width: 88,
                            child: Text(
                              _formatDuration(track.duration),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: secondaryColor),
                            ),
                          ),
                          if (showPlatformColumn)
                            SizedBox(
                              width: 88,
                              child: Align(
                                alignment: Alignment.center,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accent,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    platformLabelBuilder?.call(track) ??
                                        track.platform,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) {
      return '--:--';
    }
    final minutes = seconds ~/ 60;
    final remain = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remain.toString().padLeft(2, '0')}';
  }
}

class _SheetDetailFallbackCover extends StatelessWidget {
  const _SheetDetailFallbackCover({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(title);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  static List<Color> _palette(String seed) {
    final value = seed.runes.fold<int>(0, (sum, rune) => sum + rune);
    const palettes = <List<Color>>[
      <Color>[Color(0xFFF2994A), Color(0xFFF2C94C)],
      <Color>[Color(0xFF654EA3), Color(0xFFEAafc8)],
      <Color>[Color(0xFF4CB8C4), Color(0xFF3CD3AD)],
      <Color>[Color(0xFF8E2DE2), Color(0xFF4A00E0)],
      <Color>[Color(0xFF4568DC), Color(0xFFB06AB3)],
      <Color>[Color(0xFF1D976C), Color(0xFF93F9B9)],
    ];
    return palettes[value % math.max(1, palettes.length)];
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
