import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../../../app/theme/app_theme.dart';
import '../../../../core/media/media_constants.dart';
import '../../../../core/media/media_models.dart';
import '../../../../shared/ui/app_shell.dart';
import '../../../player/player_providers.dart';
import '../../domain/internal_plugins.dart';
import '../../local_music_providers.dart';

enum _LocalMusicDisplayView { list, artist, album, folder }

class LocalMusicPage extends ConsumerStatefulWidget {
  const LocalMusicPage({super.key});

  @override
  ConsumerState<LocalMusicPage> createState() => _LocalMusicPageState();
}

class _LocalMusicPageState extends ConsumerState<LocalMusicPage> {
  late final TextEditingController _searchController;

  _LocalMusicDisplayView _displayView = _LocalMusicDisplayView.list;
  String _query = '';
  String? _selectedTrackId;
  String? _selectedArtistKey;
  String? _selectedAlbumKey;
  String? _selectedFolderKey;
  bool _isBusy = false;

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
    final libraryAsync = ref.watch(localMusicControllerProvider);

    return AppShell(
      title: '本地音乐',
      subtitle: '导入本地歌曲，并按列表、歌手、专辑、文件夹查看。',
      child: libraryAsync.when(
        data: (tracks) {
          final filteredTracks = _filterTracks(tracks, _query);
          final artistGroups = _buildArtistGroups(filteredTracks);
          final albumGroups = _buildAlbumGroups(filteredTracks);
          final folderGroups = _buildFolderGroups(filteredTracks);

          final selectedArtistKey = _resolveSelectedGroupKey(
            preferredKey: _selectedArtistKey,
            groups: artistGroups,
          );
          final selectedAlbumKey = _resolveSelectedGroupKey(
            preferredKey: _selectedAlbumKey,
            groups: albumGroups,
          );
          final selectedFolderKey = _resolveSelectedGroupKey(
            preferredKey: _selectedFolderKey,
            groups: folderGroups,
          );

          final visibleTracks = switch (_displayView) {
            _LocalMusicDisplayView.list => filteredTracks,
            _LocalMusicDisplayView.artist =>
              artistGroups[selectedArtistKey]?.tracks ?? const <MusicItem>[],
            _LocalMusicDisplayView.album =>
              albumGroups[selectedAlbumKey]?.tracks ?? const <MusicItem>[],
            _LocalMusicDisplayView.folder =>
              folderGroups[selectedFolderKey]?.tracks ?? const <MusicItem>[],
          };

          final selectedTrack = visibleTracks
              .where((track) => track.id == _selectedTrackId)
              .firstOrNull;

          return Column(
            children: <Widget>[
              _LocalMusicOperations(
                searchController: _searchController,
                displayView: _displayView,
                busy: _isBusy,
                onSearchChanged: (value) {
                  setState(() {
                    _query = value.trim();
                    if (_selectedTrackId != null &&
                        visibleTracks.every(
                          (track) => track.id != _selectedTrackId,
                        )) {
                      _selectedTrackId = null;
                    }
                  });
                },
                onChangeView: (view) {
                  setState(() {
                    _displayView = view;
                    _selectedTrackId = null;
                  });
                },
                onImportFiles: _isBusy ? null : _importFiles,
                onImportFolder: _isBusy ? null : _importFolder,
                onClear: tracks.isEmpty || _isBusy ? null : _clearLibrary,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: switch (_displayView) {
                  _LocalMusicDisplayView.list => _TrackTable(
                    tracks: visibleTracks,
                    selectedTrackId: selectedTrack?.id,
                    onTrackTap: _selectTrack,
                    onTrackDoubleTap: (track) {
                      final index = visibleTracks.indexWhere(
                        (item) => item.id == track.id,
                      );
                      if (index >= 0) {
                        _playQueue(visibleTracks, index);
                      }
                    },
                  ),
                  _LocalMusicDisplayView.artist => _GroupedTrackView(
                    groups: artistGroups,
                    selectedKey: selectedArtistKey,
                    showArtistColumn: false,
                    onSelectGroup: (key) {
                      setState(() {
                        _selectedArtistKey = key;
                        _selectedTrackId = null;
                      });
                    },
                    selectedTrackId: selectedTrack?.id,
                    onTrackTap: _selectTrack,
                    onTrackDoubleTap: (track) {
                      final items =
                          artistGroups[selectedArtistKey]?.tracks ??
                          const <MusicItem>[];
                      final index = items.indexWhere(
                        (item) => item.id == track.id,
                      );
                      if (index >= 0) {
                        _playQueue(items, index);
                      }
                    },
                  ),
                  _LocalMusicDisplayView.album => _GroupedTrackView(
                    groups: albumGroups,
                    selectedKey: selectedAlbumKey,
                    showAlbumColumn: false,
                    onSelectGroup: (key) {
                      setState(() {
                        _selectedAlbumKey = key;
                        _selectedTrackId = null;
                      });
                    },
                    selectedTrackId: selectedTrack?.id,
                    onTrackTap: _selectTrack,
                    onTrackDoubleTap: (track) {
                      final items =
                          albumGroups[selectedAlbumKey]?.tracks ??
                          const <MusicItem>[];
                      final index = items.indexWhere(
                        (item) => item.id == track.id,
                      );
                      if (index >= 0) {
                        _playQueue(items, index);
                      }
                    },
                  ),
                  _LocalMusicDisplayView.folder => _GroupedTrackView(
                    groups: folderGroups,
                    selectedKey: selectedFolderKey,
                    showArtistColumn: false,
                    onSelectGroup: (key) {
                      setState(() {
                        _selectedFolderKey = key;
                        _selectedTrackId = null;
                      });
                    },
                    selectedTrackId: selectedTrack?.id,
                    onTrackTap: _selectTrack,
                    onTrackDoubleTap: (track) {
                      final items =
                          folderGroups[selectedFolderKey]?.tracks ??
                          const <MusicItem>[];
                      final index = items.indexWhere(
                        (item) => item.id == track.id,
                      );
                      if (index >= 0) {
                        _playQueue(items, index);
                      }
                    },
                  ),
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

  Future<void> _importFiles() async {
    setState(() {
      _isBusy = true;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: supportedLocalMediaTypes
            .map((entry) => entry.replaceFirst('.', ''))
            .toList(growable: false),
      );
      final paths = picked?.paths.whereType<String>().toList(growable: false);
      if (paths == null || paths.isEmpty) {
        return;
      }

      final before = ref.read(localMusicControllerProvider).valueOrNull;
      final next = await ref
          .read(localMusicControllerProvider.notifier)
          .importFiles(paths);
      if (!mounted) {
        return;
      }
      _showMessage(
        '已导入 ${math.max(0, next.length - (before?.length ?? 0))} 首歌曲。',
      );
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _importFolder() async {
    setState(() {
      _isBusy = true;
    });
    try {
      final folderPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择本地音乐文件夹',
      );
      if (folderPath == null || folderPath.trim().isEmpty) {
        return;
      }

      final before = ref.read(localMusicControllerProvider).valueOrNull;
      final next = await ref
          .read(localMusicControllerProvider.notifier)
          .importFolder(folderPath);
      if (!mounted) {
        return;
      }
      _showMessage(
        '扫描完成，当前共 ${next.length} 首，本次新增 ${math.max(0, next.length - (before?.length ?? 0))} 首。',
      );
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _clearLibrary() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('清空本地音乐'),
          content: const Text('仅清空当前应用内的本地音乐记录，不会删除磁盘文件。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('清空'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isBusy = true;
    });
    try {
      await ref.read(localMusicControllerProvider.notifier).clear();
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedTrackId = null;
        _selectedArtistKey = null;
        _selectedAlbumKey = null;
        _selectedFolderKey = null;
      });
      _showMessage('已清空本地音乐记录。');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _playQueue(List<MusicItem> tracks, int startIndex) async {
    if (tracks.isEmpty || startIndex < 0 || startIndex >= tracks.length) {
      return;
    }

    await ref
        .read(playerControllerProvider.notifier)
        .playQueue(
          plugin: buildLocalPluginRecord(),
          queue: tracks,
          startIndex: startIndex,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedTrackId = tracks[startIndex].id;
    });
  }

  void _selectTrack(MusicItem track) {
    setState(() {
      _selectedTrackId = track.id;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
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
              (track.album?.toLowerCase().contains(keyword) ?? false) ||
              (track.localPath?.toLowerCase().contains(keyword) ?? false);
        })
        .toList(growable: false);
  }

  static Map<String, _TrackGroup> _buildArtistGroups(List<MusicItem> tracks) {
    final grouped = <String, List<MusicItem>>{};
    for (final track in tracks) {
      final key = _safeLabel(track.artist, '未知歌手');
      grouped.putIfAbsent(key, () => <MusicItem>[]).add(track);
    }
    final entries = grouped.entries.toList(growable: false)
      ..sort(
        (left, right) =>
            left.key.toLowerCase().compareTo(right.key.toLowerCase()),
      );
    return {
      for (final entry in entries)
        entry.key: _TrackGroup(
          key: entry.key,
          title: entry.key,
          subtitle: '${entry.value.length} 首歌曲',
          tracks: entry.value,
        ),
    };
  }

  static Map<String, _TrackGroup> _buildAlbumGroups(List<MusicItem> tracks) {
    final grouped = <String, List<MusicItem>>{};
    for (final track in tracks) {
      final album = _safeLabel(track.album, '未知专辑');
      final artist = _safeLabel(track.artist, '未知歌手');
      final key = '$album - $artist';
      grouped.putIfAbsent(key, () => <MusicItem>[]).add(track);
    }
    final entries = grouped.entries.toList(growable: false)
      ..sort(
        (left, right) =>
            left.key.toLowerCase().compareTo(right.key.toLowerCase()),
      );
    return {
      for (final entry in entries)
        entry.key: _TrackGroup(
          key: entry.key,
          title: entry.key.split(' - ').first,
          subtitle: entry.key.split(' - ').skip(1).join(' - '),
          tracks: entry.value,
        ),
    };
  }

  static Map<String, _TrackGroup> _buildFolderGroups(List<MusicItem> tracks) {
    final grouped = <String, List<MusicItem>>{};
    for (final track in tracks) {
      final folder = track.localPath == null || track.localPath!.isEmpty
          ? '未知目录'
          : path.dirname(track.localPath!);
      grouped.putIfAbsent(folder, () => <MusicItem>[]).add(track);
    }
    final entries = grouped.entries.toList(growable: false)
      ..sort(
        (left, right) =>
            left.key.toLowerCase().compareTo(right.key.toLowerCase()),
      );
    return {
      for (final entry in entries)
        entry.key: _TrackGroup(
          key: entry.key,
          title: entry.key,
          subtitle: '${entry.value.length} 首歌曲',
          tracks: entry.value,
        ),
    };
  }

  static String? _resolveSelectedGroupKey({
    required String? preferredKey,
    required Map<String, _TrackGroup> groups,
  }) {
    if (groups.isEmpty) {
      return null;
    }
    if (preferredKey != null && groups.containsKey(preferredKey)) {
      return preferredKey;
    }
    return groups.keys.first;
  }

  static String _safeLabel(String? value, String fallback) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }
}

class _LocalMusicOperations extends StatelessWidget {
  const _LocalMusicOperations({
    required this.searchController,
    required this.displayView,
    required this.busy,
    required this.onSearchChanged,
    required this.onChangeView,
    required this.onImportFiles,
    required this.onImportFolder,
    required this.onClear,
  });

  final TextEditingController searchController;
  final _LocalMusicDisplayView displayView;
  final bool busy;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_LocalMusicDisplayView> onChangeView;
  final VoidCallback? onImportFiles;
  final VoidCallback? onImportFolder;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTheme.colorsOf(context).accent;
    return Row(
      children: <Widget>[
        FilledButton(
          onPressed: onImportFolder,
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(busy ? '处理中...' : '自动扫描'),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: onImportFiles,
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('导入文件'),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: onClear,
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('清空列表'),
        ),
        const Spacer(),
        SizedBox(
          width: 280,
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: '搜索本地音乐',
              suffixIcon: Icon(
                Icons.search_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: accent),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _ViewSwitchButton(
          icon: Icons.music_note_rounded,
          tooltip: '列表视图',
          selected: displayView == _LocalMusicDisplayView.list,
          onTap: () => onChangeView(_LocalMusicDisplayView.list),
        ),
        const SizedBox(width: 8),
        _ViewSwitchButton(
          icon: Icons.person_outline_rounded,
          tooltip: '歌手视图',
          selected: displayView == _LocalMusicDisplayView.artist,
          onTap: () => onChangeView(_LocalMusicDisplayView.artist),
        ),
        const SizedBox(width: 8),
        _ViewSwitchButton(
          icon: Icons.album_outlined,
          tooltip: '专辑视图',
          selected: displayView == _LocalMusicDisplayView.album,
          onTap: () => onChangeView(_LocalMusicDisplayView.album),
        ),
        const SizedBox(width: 8),
        _ViewSwitchButton(
          icon: Icons.folder_open_rounded,
          tooltip: '文件夹视图',
          selected: displayView == _LocalMusicDisplayView.folder,
          onTap: () => onChangeView(_LocalMusicDisplayView.folder),
        ),
      ],
    );
  }
}

class _ViewSwitchButton extends StatelessWidget {
  const _ViewSwitchButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTheme.colorsOf(context).accent;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: selected ? accent : theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? accent : theme.dividerColor),
          ),
          child: Icon(
            icon,
            color: selected ? Colors.white : theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _GroupedTrackView extends StatelessWidget {
  const _GroupedTrackView({
    required this.groups,
    required this.selectedKey,
    required this.onSelectGroup,
    required this.selectedTrackId,
    required this.onTrackTap,
    required this.onTrackDoubleTap,
    this.showArtistColumn = true,
    this.showAlbumColumn = true,
  });

  final Map<String, _TrackGroup> groups;
  final String? selectedKey;
  final ValueChanged<String> onSelectGroup;
  final String? selectedTrackId;
  final ValueChanged<MusicItem> onTrackTap;
  final ValueChanged<MusicItem> onTrackDoubleTap;
  final bool showArtistColumn;
  final bool showAlbumColumn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTheme.colorsOf(context).accent;
    if (groups.isEmpty || selectedKey == null) {
      return const Center(child: Text('暂无可显示的本地音乐。'));
    }

    final selectedGroup = groups[selectedKey];
    if (selectedGroup == null) {
      return const Center(child: Text('暂无可显示的本地音乐。'));
    }

    return Row(
      children: <Widget>[
        Container(
          width: 280,
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: groups.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: theme.dividerColor),
            itemBuilder: (context, index) {
              final group = groups.values.elementAt(index);
              final selected = group.key == selectedKey;
              return InkWell(
                onTap: () => onSelectGroup(group.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.translucentSelection(context)
                        : Colors.transparent,
                    border: Border(
                      left: BorderSide(
                        color: selected ? accent : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        group.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (group.subtitle?.isNotEmpty == true) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          group.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _TrackTable(
            tracks: selectedGroup.tracks,
            selectedTrackId: selectedTrackId,
            showArtistColumn: showArtistColumn,
            showAlbumColumn: showAlbumColumn,
            onTrackTap: onTrackTap,
            onTrackDoubleTap: onTrackDoubleTap,
          ),
        ),
      ],
    );
  }
}

class _TrackTable extends StatelessWidget {
  const _TrackTable({
    required this.tracks,
    required this.selectedTrackId,
    required this.onTrackTap,
    required this.onTrackDoubleTap,
    this.showArtistColumn = true,
    this.showAlbumColumn = true,
  });

  final List<MusicItem> tracks;
  final String? selectedTrackId;
  final ValueChanged<MusicItem> onTrackTap;
  final ValueChanged<MusicItem> onTrackDoubleTap;
  final bool showArtistColumn;
  final bool showAlbumColumn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (tracks.isEmpty) {
      return const Center(child: Text('暂无本地音乐，请先导入歌曲。'));
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
              children: <Widget>[
                const SizedBox(width: 44, child: Center(child: Text('#'))),
                const Expanded(
                  flex: 4,
                  child: Text(
                    '标题',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (showArtistColumn)
                  const Expanded(
                    flex: 3,
                    child: Text(
                      '歌手',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                if (showAlbumColumn)
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
                return InkWell(
                  onTap: () => onTrackTap(track),
                  onDoubleTap: () => onTrackDoubleTap(track),
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
                        if (showArtistColumn)
                          Expanded(
                            flex: 3,
                            child: Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (showAlbumColumn)
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

class _TrackGroup {
  const _TrackGroup({
    required this.key,
    required this.title,
    required this.tracks,
    this.subtitle,
  });

  final String key;
  final String title;
  final String? subtitle;
  final List<MusicItem> tracks;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
