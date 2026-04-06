import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/media/media_models.dart';
import '../../../../shared/ui/app_shell.dart';
import '../../../../shared/ui/section_card.dart';
import '../../../downloads/presentation/widgets/download_track_actions.dart';
import '../../../downloads/presentation/widgets/download_track_button.dart';
import '../../../media/domain/media_route_state.dart';
import '../../../player/player_providers.dart';
import '../../../media/music_sheet_library_providers.dart';
import '../../../media/presentation/widgets/music_track_actions.dart';
import '../../../plugins/domain/plugin.dart';
import '../../../plugins/domain/plugin_search.dart';
import '../../../plugins/plugin_providers.dart';
import '../../search_providers.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _queryController;
  PluginSearchType _type = PluginSearchType.music;
  String? _selectedPluginId;
  String _lastRouteQuery = '';

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeQuery = GoRouterState.of(context).uri.queryParameters['q'] ?? '';
    if (_lastRouteQuery == routeQuery) {
      return;
    }
    _lastRouteQuery = routeQuery;
    if (_queryController.text != routeQuery) {
      _queryController.text = routeQuery;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final plugins =
          ref.read(pluginControllerProvider).valueOrNull?.plugins ??
          const <PluginRecord>[];
      _runSearch(ref.read(searchPageControllerProvider.notifier), plugins);
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(pluginControllerProvider);
    final searchState = ref.watch(searchPageControllerProvider);
    final controller = ref.read(searchPageControllerProvider.notifier);
    final routeQuery = GoRouterState.of(context).uri.queryParameters['q'] ?? '';
    final favoriteKeys = ref.watch(favoriteMusicKeysProvider);
    final accent = AppTheme.colorsOf(context).accent;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return AppShell(
      title: '搜索',
      subtitle: '',
      child: snapshot.when(
        data: (data) {
          final supportedPlugins = _supportedPluginsForType(
            data.plugins,
            _type,
          );
          if (supportedPlugins.isEmpty) {
            return const SectionCard(child: Text('当前没有支持该搜索类型的已启用插件。'));
          }

          _selectedPluginId ??= supportedPlugins.first.storageKey;
          final selectedPlugin = supportedPlugins.firstWhere(
            (plugin) => plugin.storageKey == _selectedPluginId,
            orElse: () => supportedPlugins.first,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: '[',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    TextSpan(
                      text: routeQuery,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    TextSpan(
                      text: '] 的搜索结果',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _TypeTabs(
                type: _type,
                onChanged: (nextType) {
                  setState(() {
                    _type = nextType;
                    final nextPlugins = _supportedPluginsForType(
                      data.plugins,
                      nextType,
                    );
                    _selectedPluginId = nextPlugins.isEmpty
                        ? null
                        : nextPlugins.first.storageKey;
                  });
                  _runSearch(controller, data.plugins);
                },
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: supportedPlugins
                    .map(
                      (plugin) => _PluginChip(
                        label: plugin.displayName,
                        selected: plugin.storageKey == _selectedPluginId,
                        onTap: () {
                          setState(() {
                            _selectedPluginId = plugin.storageKey;
                          });
                          _runSearch(controller, data.plugins);
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: searchState.when(
                  data: (state) {
                    if (state.query.isEmpty || state.result == null) {
                      return const SectionCard(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text('在顶部搜索框输入关键字后开始搜索。'),
                        ),
                      );
                    }

                    final result = state.result!;
                    if (result.errorMessage != null) {
                      return SectionCard(
                        child: Text(
                          result.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      );
                    }

                    if (result.items.isEmpty) {
                      return const SectionCard(child: Text('没有返回结果。'));
                    }

                    if (_type == PluginSearchType.music) {
                      final musicItems = result.items
                          .map((item) => item.media)
                          .whereType<MusicItem>()
                          .toList(growable: false);
                      return _MusicResultsTable(
                        plugin: result.plugin,
                        musicItems: musicItems,
                        favoriteKeys: favoriteKeys,
                        onPlayTrack: (index) => _playTrack(
                          plugin: result.plugin,
                          queue: musicItems,
                          index: index,
                        ),
                        onToggleFavorite: (music) =>
                            toggleFavoriteTrack(context, ref, music),
                        onAddToSheet: (music) => showAddToMusicSheetDialog(
                          context,
                          ref,
                          tracks: <MusicItem>[music],
                        ),
                        onDownloadTrack: (music) async {
                          await queueTrackDownload(context, ref, music);
                        },
                      );
                    }

                    return SectionCard(
                      padding: const EdgeInsets.all(0),
                      child: ListView.separated(
                        itemCount: result.items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = result.items[index];
                          return ListTile(
                            title: Text(item.title),
                            subtitle: item.subtitle.isEmpty
                                ? null
                                : Text(item.subtitle),
                            trailing: IconButton(
                              tooltip: '查看原始数据',
                              onPressed: () =>
                                  _showRawDialog(context, item.media),
                              icon: const Icon(Icons.data_object_rounded),
                            ),
                            onTap: () => _openMedia(
                              context,
                              result.plugin.storageKey,
                              item.media,
                            ),
                          );
                        },
                      ),
                    );
                  },
                  error: (error, _) =>
                      SectionCard(child: Text(error.toString())),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                ),
              ),
              searchState.maybeWhen(
                data: (state) {
                  final result = state.result;
                  if (result == null ||
                      result.isEnd ||
                      result.errorMessage != null) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: FilledButton.tonal(
                      onPressed: () => controller.search(
                        plugin: selectedPlugin,
                        query: state.query,
                        type: state.type,
                        page: state.page + 1,
                        append: true,
                      ),
                      child: const Text('加载更多'),
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          );
        },
        error: (error, _) => SectionCard(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  List<PluginRecord> _supportedPluginsForType(
    List<PluginRecord> plugins,
    PluginSearchType type,
  ) {
    return plugins
        .where(
          (plugin) =>
              plugin.meta.enabled &&
              (plugin.manifest?.supportedMethods.contains('search') ?? false) &&
              _supportsSearchType(plugin, type),
        )
        .toList(growable: false);
  }

  bool _supportsSearchType(PluginRecord plugin, PluginSearchType type) {
    final supportedTypes =
        plugin.manifest?.supportedSearchTypes ?? const <String>[];
    if (supportedTypes.isEmpty) {
      return true;
    }
    return supportedTypes.contains(type.value);
  }

  Future<void> _runSearch(
    SearchPageController controller,
    List<PluginRecord> plugins,
  ) async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      return;
    }

    final supportedPlugins = _supportedPluginsForType(plugins, _type);
    if (supportedPlugins.isEmpty) {
      return;
    }

    final selectedPlugin = supportedPlugins.firstWhere(
      (plugin) => plugin.storageKey == _selectedPluginId,
      orElse: () => supportedPlugins.first,
    );

    await controller.search(plugin: selectedPlugin, query: query, type: _type);
  }

  Future<void> _playTrack({
    required PluginRecord plugin,
    required List<MusicItem> queue,
    required int index,
  }) async {
    await ref
        .read(playerControllerProvider.notifier)
        .playQueue(plugin: plugin, queue: queue, startIndex: index);
  }

  void _openMedia(BuildContext context, String pluginId, MediaItem media) {
    if (media.mediaType == MediaType.music ||
        media.mediaType == MediaType.lyric) {
      context.push(
        '/music',
        extra: MusicRouteState(
          pluginId: pluginId,
          musicItem: media as MusicItem,
        ),
      );
      return;
    }
    if (media.mediaType == MediaType.album) {
      context.push(
        '/album',
        extra: AlbumRouteState(
          pluginId: pluginId,
          albumItem: media as AlbumItem,
        ),
      );
      return;
    }
    if (media.mediaType == MediaType.artist) {
      context.push(
        '/artist',
        extra: ArtistRouteState(
          pluginId: pluginId,
          artistItem: media as ArtistItem,
        ),
      );
      return;
    }
    context.push(
      '/sheet',
      extra: SheetRouteState(
        pluginId: pluginId,
        sheetItem: media as MusicSheetItem,
      ),
    );
  }

  Future<void> _showRawDialog(BuildContext context, MediaItem media) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('原始数据'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(media.toJson()),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
}

class _TypeTabs extends StatelessWidget {
  const _TypeTabs({required this.type, required this.onChanged});

  final PluginSearchType type;
  final ValueChanged<PluginSearchType> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTheme.colorsOf(context).accent;
    return Row(
      children: PluginSearchType.values
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(right: 26),
              child: InkWell(
                onTap: () => onChanged(entry),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      switch (entry) {
                        PluginSearchType.music => '音乐',
                        PluginSearchType.album => '专辑',
                        PluginSearchType.artist => '作者',
                        PluginSearchType.sheet => '歌单',
                      },
                      style: TextStyle(
                        fontSize: 15,
                        color: type == entry
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: type == entry
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 32,
                      height: 3,
                      decoration: BoxDecoration(
                        color: type == entry ? accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _PluginChip extends StatelessWidget {
  const _PluginChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTheme.colorsOf(context).accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? accent : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? accent : theme.dividerColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: selected ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _MusicResultsTable extends StatelessWidget {
  const _MusicResultsTable({
    required this.plugin,
    required this.musicItems,
    required this.favoriteKeys,
    required this.onPlayTrack,
    required this.onToggleFavorite,
    required this.onAddToSheet,
    required this.onDownloadTrack,
  });

  final PluginRecord plugin;
  final List<MusicItem> musicItems;
  final Set<String> favoriteKeys;
  final ValueChanged<int> onPlayTrack;
  final ValueChanged<MusicItem> onToggleFavorite;
  final ValueChanged<MusicItem> onAddToSheet;
  final ValueChanged<MusicItem> onDownloadTrack;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        children: <Widget>[
          const _MusicResultsHeader(),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: musicItems.length,
              itemBuilder: (context, index) {
                final item = musicItems[index];
                return _MusicResultRow(
                  index: index,
                  pluginName: plugin.displayName,
                  music: item,
                  favorite: favoriteKeys.contains(
                    '${item.platform}@${item.id}',
                  ),
                  onDoubleTap: () => onPlayTrack(index),
                  onToggleFavorite: () => onToggleFavorite(item),
                  onAddToSheet: () => onAddToSheet(item),
                  onDownloadToQueue: () => onDownloadTrack(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MusicResultsHeader extends StatelessWidget {
  const _MusicResultsHeader();

  @override
  Widget build(BuildContext context) {
    final headerStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurface,
    );

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: <Widget>[
          SizedBox(width: 54),
          SizedBox(width: 44, child: Text('#', style: headerStyle)),
          Expanded(flex: 5, child: Text('标题', style: headerStyle)),
          Expanded(flex: 3, child: Text('作者', style: headerStyle)),
          Expanded(flex: 3, child: Text('专辑', style: headerStyle)),
          SizedBox(width: 86, child: Text('时长', style: headerStyle)),
          SizedBox(width: 86, child: Text('来源', style: headerStyle)),
        ],
      ),
    );
  }
}

class _MusicResultRow extends StatelessWidget {
  const _MusicResultRow({
    required this.index,
    required this.pluginName,
    required this.music,
    required this.favorite,
    required this.onDoubleTap,
    required this.onToggleFavorite,
    required this.onAddToSheet,
    required this.onDownloadToQueue,
  });

  final int index;
  final String pluginName;
  final MusicItem music;
  final bool favorite;
  final VoidCallback onDoubleTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAddToSheet;
  final VoidCallback onDownloadToQueue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTheme.colorsOf(context).accent;
    final rowBackground = index.isEven
        ? theme.colorScheme.surfaceContainerLow
        : theme.colorScheme.surface;
    final textColor = theme.colorScheme.onSurface;
    final secondaryColor = theme.colorScheme.onSurfaceVariant;
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      onSecondaryTapDown: (details) => showTrackContextMenu(
        context,
        position: details.globalPosition,
        track: music,
        onDownload: () async => onDownloadToQueue(),
        onAddToSheet: () async => onAddToSheet(),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          color: rowBackground,
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 54,
                child: Row(
                  children: <Widget>[
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
                    const SizedBox(width: 6),
                    DownloadTrackButton(track: music),
                  ],
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 14,
                  ).copyWith(color: secondaryColor),
                ),
              ),
              Expanded(
                flex: 5,
                child: Text(
                  music.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                  ).copyWith(color: textColor),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  music.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                  ).copyWith(color: textColor),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  music.album ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                  ).copyWith(color: secondaryColor),
                ),
              ),
              SizedBox(
                width: 86,
                child: Text(
                  _formatDurationSeconds(music.duration),
                  style: const TextStyle(
                    fontSize: 14,
                  ).copyWith(color: secondaryColor),
                ),
              ),
              SizedBox(
                width: 86,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      pluginName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
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
  }
}

String _formatDurationSeconds(int? seconds) {
  if (seconds == null || seconds <= 0) {
    return '--:--';
  }

  final duration = Duration(seconds: seconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:$minutes:$secs';
  }
  return '$minutes:$secs';
}
