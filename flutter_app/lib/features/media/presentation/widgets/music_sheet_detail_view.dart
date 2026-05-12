import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/media/media_models.dart';
import '../../../downloads/presentation/widgets/download_track_button.dart';
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
    required this.onDownloadTrack,
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
  final Future<void> Function(MusicItem track) onDownloadTrack;
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
            onDownloadTrack: widget.onDownloadTrack,
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
    final compact = MediaQuery.of(context).size.width < 980;
    if (compact) return _buildCompact(context);
    return _buildWide(context);
  }

  Widget _buildCompact(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTheme.colorsOf(context).accent;
    final textColor = theme.colorScheme.onSurface;
    final secondaryColor = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Cover + title + meta in a compact row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 80,
                height: 80,
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: accent),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  if (artist?.isNotEmpty == true)
                    Text(
                      '作者：$artist',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: secondaryColor),
                    ),
                  if (playCount != null)
                    Text(
                      '播放数：$playCount',
                      style: TextStyle(fontSize: 12, color: secondaryColor),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Action buttons in a scrollable row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
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
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('播放'),
              ),
              for (final action in actions) ...<Widget>[
                const SizedBox(width: 8),
                action.filled
                    ? FilledButton.icon(
                        onPressed: action.onPressed,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                        icon: Icon(action.icon, size: 16),
                        label: Text(action.label),
                      )
                    : OutlinedButton.icon(
                        onPressed: action.onPressed,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                        icon: Icon(action.icon, size: 16),
                        label: Text(action.label),
                      ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Search field full-width
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: searchHint,
            isDense: true,
            prefixIcon: Icon(
              Icons.search_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
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
      ],
    );
  }

  Widget _buildWide(BuildContext context) {
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
    required this.onDownloadTrack,
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
  final Future<void> Function(MusicItem track) onDownloadTrack;
  final ValueChanged<MusicItem> onTrackTap;
  final ValueChanged<MusicItem> onTrackDoubleTap;
  final String emptyText;
  final bool showPlatformColumn;
  final String Function(MusicItem track)? platformLabelBuilder;
  final Future<void> Function(MusicItem track)? onRemoveTrackFromCurrentSheet;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 980;
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
                if (!compact) const SizedBox(width: 54),
                const SizedBox(width: 44, child: Center(child: Text('#'))),
                const Expanded(
                  flex: 5,
                  child: Text(
                    '标题',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (!compact) ...<Widget>[
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
                ],
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
                  // Desktop: right-click context menu
                  onSecondaryTapDown: (details) => showTrackContextMenu(
                    context,
                    position: details.globalPosition,
                    track: track,
                    onDownload: () => onDownloadTrack(track),
                    onAddToSheet: () => onAddTrackToSheet(track),
                    onRemoveFromCurrentSheet:
                        onRemoveTrackFromCurrentSheet == null
                        ? null
                        : () => onRemoveTrackFromCurrentSheet!(track),
                  ),
                  // Mobile: long-press context menu
                  onLongPress: compact
                      ? () => _showMobileTrackMenu(
                          context,
                          track: track,
                          isFavorite: isFavorite,
                          onToggleFavorite: () => onToggleFavorite(track),
                          onAddToSheet: () => onAddTrackToSheet(track),
                          onDownload: () => onDownloadTrack(track),
                          onRemoveFromCurrentSheet:
                              onRemoveTrackFromCurrentSheet == null
                              ? null
                              : () => onRemoveTrackFromCurrentSheet!(track),
                        )
                      : null,
                  child: InkWell(
                    onTap: () => onTrackTap(track),
                    onDoubleTap: () => onTrackDoubleTap(track),
                    child: Container(
                      height: 48,
                      color: selected ? selectedRow : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: <Widget>[
                          if (!compact)
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
                                  DownloadTrackButton(track: track),
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
                            flex: 5,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                if (compact)
                                  Text(
                                    '${track.artist}${track.album?.isNotEmpty == true ? ' · ${track.album}' : ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: secondaryColor,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (!compact) ...<Widget>[
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
                          ],
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

  static Future<void> _showMobileTrackMenu(
    BuildContext context, {
    required MusicItem track,
    required bool isFavorite,
    required VoidCallback onToggleFavorite,
    required VoidCallback onAddToSheet,
    required VoidCallback onDownload,
    VoidCallback? onRemoveFromCurrentSheet,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.music_note_rounded),
              title: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: isFavorite ? const Color(0xFFE44B4B) : null,
              ),
              title: Text(isFavorite ? '从"我喜欢"移除' : '添加到"我喜欢"'),
              onTap: () {
                Navigator.of(ctx).pop();
                onToggleFavorite();
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('添加到歌单'),
              onTap: () {
                Navigator.of(ctx).pop();
                onAddToSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('下载'),
              onTap: () {
                Navigator.of(ctx).pop();
                onDownload();
              },
            ),
            if (onRemoveFromCurrentSheet != null)
              ListTile(
                leading: const Icon(Icons.remove_circle_outline_rounded),
                title: const Text('从歌单内删除'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  onRemoveFromCurrentSheet();
                },
              ),
          ],
        ),
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
    final accent = AppTheme.colorsOf(context).accent;
    return Container(
      color: accent.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          title.isNotEmpty ? title[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            color: accent,
          ),
        ),
      ),
    );
  }
}
