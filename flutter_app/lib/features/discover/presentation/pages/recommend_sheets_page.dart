import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/media/media_models.dart';
import '../../../../shared/ui/app_shell.dart';
import '../../../../shared/ui/horizontal_item_scroller.dart';
import '../../../media/domain/media_route_state.dart';
import '../../../media/media_providers.dart';
import '../../../plugins/domain/plugin.dart';
import '../../../plugins/domain/plugin_method_models.dart';
import '../../../plugins/plugin_providers.dart';

class RecommendSheetsPage extends ConsumerStatefulWidget {
  const RecommendSheetsPage({super.key});

  @override
  ConsumerState<RecommendSheetsPage> createState() =>
      _RecommendSheetsPageState();
}

class _RecommendSheetsPageState extends ConsumerState<RecommendSheetsPage> {
  String? _selectedPluginId;
  MediaTag? _selectedTag;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(pluginControllerProvider);

    return AppShell(
      title: '热门歌单',
      subtitle: '切换音乐源并浏览推荐歌单。',
      child: snapshot.when(
        data: (data) {
          final plugins = data.plugins
              .where(
                (plugin) =>
                    plugin.meta.enabled &&
                    (plugin.manifest?.supportedMethods.contains(
                          'getRecommendSheetsByTag',
                        ) ??
                        false),
              )
              .toList(growable: false);

          if (plugins.isEmpty) {
            return const Center(child: Text('当前没有已启用且支持热门歌单的插件。'));
          }

          _selectedPluginId ??= plugins.first.storageKey;
          final selectedPlugin = plugins.firstWhere(
            (plugin) => plugin.storageKey == _selectedPluginId,
            orElse: () => plugins.first,
          );

          final tagsAsync = ref.watch(
            recommendTagsProvider(selectedPlugin.storageKey),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _PluginTabBar(
                plugins: plugins,
                selectedPluginId: selectedPlugin.storageKey,
                onSelected: (pluginId) {
                  if (pluginId == _selectedPluginId) {
                    return;
                  }
                  setState(() {
                    _selectedPluginId = pluginId;
                    _selectedTag = null;
                  });
                },
              ),
              const SizedBox(height: 18),
              tagsAsync.when(
                data: (tags) {
                  final resolvedTag = _resolveSelectedTag(tags);
                  final sheetsAsync = resolvedTag == null
                      ? const AsyncData<PluginRecommendSheetsResult>(
                          PluginRecommendSheetsResult(isEnd: true),
                        )
                      : ref.watch(
                          recommendSheetsProvider(
                            RecommendSheetsRouteState(
                              pluginId: selectedPlugin.storageKey,
                              tag: resolvedTag,
                            ),
                          ),
                        );

                  return Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _TagBar(
                          tags: tags,
                          selectedTag: resolvedTag,
                          onTagSelected: (tag) {
                            setState(() {
                              _selectedTag = tag;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: sheetsAsync.when(
                            data: (result) {
                              if (resolvedTag == null) {
                                return const Center(child: Text('没有可用标签。'));
                              }
                              if (result.data.isEmpty) {
                                return const Center(child: Text('没有返回推荐歌单。'));
                              }
                              return GridView.builder(
                                itemCount: result.data.length,
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 196,
                                      mainAxisSpacing: 24,
                                      crossAxisSpacing: 18,
                                      childAspectRatio: 0.68,
                                    ),
                                itemBuilder: (context, index) {
                                  final item = result.data[index];
                                  return _RecommendSheetCard(
                                    pluginId: selectedPlugin.storageKey,
                                    item: item,
                                  );
                                },
                              );
                            },
                            error: (error, _) =>
                                Center(child: Text(error.toString())),
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                error: (error, _) =>
                    Expanded(child: Center(child: Text(error.toString()))),
                loading: () => const Expanded(
                  child: Center(child: CircularProgressIndicator()),
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

  MediaTag? _resolveSelectedTag(PluginRecommendSheetTagsResult tags) {
    final flattenedTags = <MediaTag>[
      const MediaTag(id: '', name: '默认'),
      ...tags.pinned
          .map((item) => MediaTag(id: item.id, name: item.title))
          .toList(growable: false),
      ...tags.data.expand(
        (group) =>
            group.data.map((item) => MediaTag(id: item.id, name: item.title)),
      ),
    ];
    if (flattenedTags.isEmpty) {
      return null;
    }
    if (_selectedTag == null) {
      _selectedTag = flattenedTags.first;
      return _selectedTag;
    }
    return flattenedTags.firstWhere(
      (tag) => tag.id == _selectedTag!.id,
      orElse: () => flattenedTags.first,
    );
  }
}

class _PluginTabBar extends StatelessWidget {
  const _PluginTabBar({
    required this.plugins,
    required this.selectedPluginId,
    required this.onSelected,
  });

  final List<PluginRecord> plugins;
  final String selectedPluginId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTheme.colorsOf(context).accent;
    final softAccent = AppTheme.colorsOf(context).softAccent;
    return HorizontalItemScroller(
      height: 46,
      itemCount: plugins.length,
      itemBuilder: (context, index) {
        final plugin = plugins[index];
        final selected = plugin.storageKey == selectedPluginId;
        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => onSelected(plugin.storageKey),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? softAccent
                  : theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: selected ? accent : theme.dividerColor),
            ),
            child: Text(
              plugin.displayName,
              style: TextStyle(
                color: selected ? accent : theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TagBar extends StatelessWidget {
  const _TagBar({
    required this.tags,
    required this.selectedTag,
    required this.onTagSelected,
  });

  final PluginRecommendSheetTagsResult tags;
  final MediaTag? selectedTag;
  final ValueChanged<MediaTag> onTagSelected;

  @override
  Widget build(BuildContext context) {
    final allTags = tags.data
        .expand(
          (group) =>
              group.data.map((item) => MediaTag(id: item.id, name: item.title)),
        )
        .toList(growable: false);
    final pinnedTags = <MediaTag>[
      const MediaTag(id: '', name: '默认'),
      ...tags.pinned
          .map((item) => MediaTag(id: item.id, name: item.title))
          .toList(growable: false),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        PopupMenuButton<MediaTag>(
          tooltip: '全部标签',
          onSelected: onTagSelected,
          itemBuilder: (context) => allTags
              .map(
                (tag) => PopupMenuItem<MediaTag>(
                  value: tag,
                  child: Text(tag.name ?? tag.id),
                ),
              )
              .toList(growable: false),
          child: _TagChip(
            label: selectedTag?.name ?? '默认',
            selected: true,
            trailingIcon: Icons.keyboard_arrow_down_rounded,
          ),
        ),
        ...pinnedTags
            .skip(1)
            .map(
              (tag) => _TagChip(
                label: tag.name ?? tag.id,
                selected: selectedTag?.id == tag.id,
                onTap: () => onTagSelected(tag),
              ),
            ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.selected,
    this.onTap,
    this.trailingIcon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTheme.colorsOf(context).accent;
    final softAccent = AppTheme.colorsOf(context).softAccent;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? softAccent : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? accent : theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                color: selected ? accent : theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (trailingIcon != null) ...<Widget>[
              const SizedBox(width: 4),
              Icon(
                trailingIcon,
                size: 16,
                color: selected ? accent : theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecommendSheetCard extends StatelessWidget {
  const _RecommendSheetCard({required this.pluginId, required this.item});

  final String pluginId;
  final MusicSheetItem item;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final imageUrl = (item.artwork?.isNotEmpty ?? false)
        ? item.artwork
        : item.extra['coverImg']?.toString();
    final playCount = item.playCount;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push(
        '/sheet',
        extra: SheetRouteState(pluginId: pluginId, sheetItem: item),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _SheetFallbackCover(title: item.title),
                        )
                      : _SheetFallbackCover(title: item.title),
                  if (playCount != null && playCount > 0)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.38),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _formatPlayCount(playCount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.artist?.isNotEmpty == true
                ? item.artist!
                : (item.description ?? ''),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: secondaryColor),
          ),
        ],
      ),
    );
  }

  static String _formatPlayCount(int playCount) {
    if (playCount >= 10000) {
      return '${(playCount / 10000).toStringAsFixed(playCount >= 100000 ? 0 : 1)}万';
    }
    return '$playCount';
  }
}

class _SheetFallbackCover extends StatelessWidget {
  const _SheetFallbackCover({required this.title});

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
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(
            right: -12,
            bottom: -14,
            child: Icon(
              Icons.queue_music_rounded,
              size: 84,
              color: Colors.white.withOpacity(0.14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
            ),
          ),
        ],
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
