import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/media/media_models.dart';
import '../../../../shared/ui/app_shell.dart';
import '../../../player/domain/recent_playback_entry.dart';
import '../../../player/player_providers.dart';
import '../../../player/recent_playback_providers.dart';
import '../../domain/internal_plugins.dart';
import '../../domain/plugin.dart';
import '../../plugin_providers.dart';

class RecentlyPlayedPage extends ConsumerStatefulWidget {
  const RecentlyPlayedPage({super.key});

  @override
  ConsumerState<RecentlyPlayedPage> createState() => _RecentlyPlayedPageState();
}

class _RecentlyPlayedPageState extends ConsumerState<RecentlyPlayedPage> {
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
    final recentAsync = ref.watch(recentPlaybackControllerProvider);
    final pluginSnapshot = ref.watch(pluginControllerProvider);

    return AppShell(
      title: '最近播放',
      subtitle: '查看播放历史，并快速重新播放。',
      child: recentAsync.when(
        data: (entries) {
          final filteredEntries = _filterEntries(entries, _query);
          return pluginSnapshot.when(
            data: (snapshot) {
              final localPlugin = buildLocalPluginRecord();
              final pluginsById = <String, PluginRecord>{
                for (final plugin in snapshot.plugins)
                  plugin.storageKey: plugin,
                localPlugin.storageKey: localPlugin,
              };
              final selectedEntry = filteredEntries
                  .where((entry) => entry.musicItem.id == _selectedTrackId)
                  .firstOrNull;

              return Column(
                children: <Widget>[
                  _RecentlyPlayedHeader(
                    playCount: entries.length,
                    searchController: _searchController,
                    onSearchChanged: (value) {
                      setState(() {
                        _query = value.trim();
                        if (_selectedTrackId != null &&
                            filteredEntries.every(
                              (entry) => entry.musicItem.id != _selectedTrackId,
                            )) {
                          _selectedTrackId = null;
                        }
                      });
                    },
                    onPlayPressed: filteredEntries.isEmpty
                        ? null
                        : () => _playEntry(
                            selectedEntry ?? filteredEntries.first,
                            filteredEntries,
                            pluginsById,
                          ),
                    onClearPressed: entries.isEmpty
                        ? null
                        : () => ref
                              .read(recentPlaybackControllerProvider.notifier)
                              .clear(),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _RecentlyPlayedTable(
                      entries: filteredEntries,
                      selectedTrackId: selectedEntry?.musicItem.id,
                      pluginLabels: {
                        for (final entry in filteredEntries)
                          entry.musicItem.id:
                              pluginsById[entry.pluginId]?.displayName ??
                              entry.musicItem.platform,
                      },
                      onEntryTap: (entry) {
                        setState(() {
                          _selectedTrackId = entry.musicItem.id;
                        });
                      },
                      onEntryDoubleTap: (entry) =>
                          _playEntry(entry, filteredEntries, pluginsById),
                    ),
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

  Future<void> _playEntry(
    RecentPlaybackEntry entry,
    List<RecentPlaybackEntry> allEntries,
    Map<String, PluginRecord> pluginsById,
  ) async {
    final plugin = pluginsById[entry.pluginId];
    if (plugin == null) {
      return;
    }
    final queue = allEntries
        .where((item) => item.pluginId == entry.pluginId)
        .map((item) => item.musicItem as MusicItem)
        .toList(growable: false);
    final startIndex = queue.indexWhere(
      (item) => item.id == entry.musicItem.id,
    );
    if (queue.isEmpty || startIndex < 0) {
      return;
    }
    await ref
        .read(playerControllerProvider.notifier)
        .playQueue(plugin: plugin, queue: queue, startIndex: startIndex);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedTrackId = entry.musicItem.id;
    });
  }

  static List<RecentPlaybackEntry> _filterEntries(
    List<RecentPlaybackEntry> entries,
    String query,
  ) {
    if (query.isEmpty) {
      return entries;
    }
    final keyword = query.toLowerCase();
    return entries
        .where((entry) {
          final track = entry.musicItem as MusicItem;
          return track.title.toLowerCase().contains(keyword) ||
              track.artist.toLowerCase().contains(keyword) ||
              (track.album?.toLowerCase().contains(keyword) ?? false);
        })
        .toList(growable: false);
  }
}

class _RecentlyPlayedHeader extends StatelessWidget {
  const _RecentlyPlayedHeader({
    required this.playCount,
    required this.searchController,
    required this.onSearchChanged,
    required this.onPlayPressed,
    required this.onClearPressed,
  });

  final int playCount;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onPlayPressed;
  final VoidCallback? onClearPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTheme.colorsOf(context).accent;
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
              child: const _RecentFallbackCover(),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '最近播放',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '播放数：$playCount',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Row(
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
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('添加'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: onClearPressed,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('清空'),
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
                hintText: '搜索最近播放歌曲',
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

class _RecentlyPlayedTable extends StatelessWidget {
  const _RecentlyPlayedTable({
    required this.entries,
    required this.selectedTrackId,
    required this.pluginLabels,
    required this.onEntryTap,
    required this.onEntryDoubleTap,
  });

  final List<RecentPlaybackEntry> entries;
  final String? selectedTrackId;
  final Map<String, String> pluginLabels;
  final ValueChanged<RecentPlaybackEntry> onEntryTap;
  final ValueChanged<RecentPlaybackEntry> onEntryDoubleTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTheme.colorsOf(context).accent;
    if (entries.isEmpty) {
      return Center(
        child: Text(
          '最近播放为空。',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
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
              color: AppTheme.translucentSurfaceVariant(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: const <Widget>[
                SizedBox(width: 44, child: Center(child: Text('#'))),
                Expanded(
                  flex: 4,
                  child: Text(
                    '标题',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '歌手',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '专辑',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
                  width: 88,
                  child: Text(
                    '时长',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
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
              itemCount: entries.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: theme.dividerColor),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final track = entry.musicItem as MusicItem;
                final selected = selectedTrackId == track.id;
                return InkWell(
                  onTap: () => onEntryTap(entry),
                  onDoubleTap: () => onEntryDoubleTap(entry),
                  child: Container(
                    height: 48,
                    color: selected
                        ? AppTheme.translucentSelection(context)
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 44,
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
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
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
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
                                pluginLabels[track.id] ?? track.platform,
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

class _RecentFallbackCover extends StatelessWidget {
  const _RecentFallbackCover();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFF8C73B), Color(0xFFF2992E)],
        ),
      ),
      child: Center(
        child: Container(
          width: 102,
          height: 102,
          decoration: const BoxDecoration(
            color: Color(0xFF2D3E59),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.album_rounded,
            size: 58,
            color: Color(0xFFFF5A47),
          ),
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
