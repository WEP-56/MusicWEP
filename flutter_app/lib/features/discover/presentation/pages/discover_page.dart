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
import '../../../plugins/plugin_providers.dart';

class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  String? _selectedPluginId;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(pluginControllerProvider);

    return AppShell(
      title: '排行榜',
      subtitle: '切换音乐源并浏览对应榜单分组。',
      child: snapshot.when(
        data: (data) {
          final plugins = data.plugins
              .where(
                (plugin) =>
                    plugin.meta.enabled &&
                    (plugin.manifest?.supportedMethods.contains(
                          'getTopLists',
                        ) ??
                        false),
              )
              .toList(growable: false);

          if (plugins.isEmpty) {
            return const Center(child: Text('当前没有已启用且支持排行榜的插件。'));
          }

          _selectedPluginId ??= plugins.first.storageKey;
          final selectedPlugin = plugins.firstWhere(
            (plugin) => plugin.storageKey == _selectedPluginId,
            orElse: () => plugins.first,
          );
          final topLists = ref.watch(
            topListsProvider(selectedPlugin.storageKey),
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
                  });
                },
              ),
              const SizedBox(height: 20),
              Expanded(
                child: topLists.when(
                  data: (groups) {
                    if (groups.isEmpty) {
                      return const Center(child: Text('没有返回排行榜。'));
                    }
                    return ListView.separated(
                      itemCount: groups.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 28),
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return _TopListGroupSection(
                          pluginId: selectedPlugin.storageKey,
                          group: group,
                        );
                      },
                    );
                  },
                  error: (error, _) => Center(child: Text(error.toString())),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
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

class _TopListGroupSection extends StatelessWidget {
  const _TopListGroupSection({required this.pluginId, required this.group});

  final String pluginId;
  final MusicSheetGroup group;

  @override
  Widget build(BuildContext context) {
    final title = (group.title?.trim().isNotEmpty ?? false)
        ? group.title!.trim()
        : '热门榜单';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            const minTileWidth = 168.0;
            final columnCount = math.max(
              1,
              (constraints.maxWidth / minTileWidth).floor(),
            );

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: group.data.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnCount,
                mainAxisSpacing: 22,
                crossAxisSpacing: 18,
                childAspectRatio: 0.68,
              ),
              itemBuilder: (context, index) {
                final item = group.data[index];
                return _TopListCard(pluginId: pluginId, item: item);
              },
            );
          },
        ),
      ],
    );
  }
}

class _TopListCard extends StatelessWidget {
  const _TopListCard({required this.pluginId, required this.item});

  final String pluginId;
  final MusicSheetItem item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = (item.artwork?.isNotEmpty ?? false)
        ? item.artwork
        : item.extra['coverImg']?.toString();
    final subtitle = _buildSubtitle(item);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push(
        '/toplist',
        extra: TopListRouteState(pluginId: pluginId, topListItem: item),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _TopListFallbackCover(title: item.title),
                    )
                  : _TopListFallbackCover(title: item.title),
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
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (subtitle.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _buildSubtitle(MusicSheetItem item) {
    final candidates = <String>[
      if (item.artist?.trim().isNotEmpty ?? false) item.artist!.trim(),
      if (item.description?.trim().isNotEmpty ?? false)
        item.description!.trim(),
      if (item.playCount != null && item.playCount! > 0) '播放 ${item.playCount}',
    ];
    return candidates.isEmpty ? '' : candidates.first;
  }
}

class _TopListFallbackCover extends StatelessWidget {
  const _TopListFallbackCover({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = _coverPalette(title);

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
              Icons.emoji_events_rounded,
              size: 82,
              color: Colors.white.withOpacity(0.14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  Icons.emoji_events_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static List<Color> _coverPalette(String seed) {
    final value = seed.runes.fold<int>(0, (sum, rune) => sum + rune);
    const palettes = <List<Color>>[
      <Color>[Color(0xFFFF5E62), Color(0xFFFF9966)],
      <Color>[Color(0xFF7F7FD5), Color(0xFF86A8E7)],
      <Color>[Color(0xFF11998E), Color(0xFF38EF7D)],
      <Color>[Color(0xFFFC466B), Color(0xFF3F5EFB)],
      <Color>[Color(0xFFFFD200), Color(0xFFF7971E)],
      <Color>[Color(0xFF8E2DE2), Color(0xFF4A00E0)],
      <Color>[Color(0xFF00B4DB), Color(0xFF0083B0)],
    ];
    return palettes[value % palettes.length];
  }
}
