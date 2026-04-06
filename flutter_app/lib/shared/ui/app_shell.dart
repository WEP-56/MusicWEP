import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/theme_customizer.dart';
import '../../core/media/media_constants.dart';
import '../../core/media/media_models.dart';
import '../../features/media/application/local_music_sheet_repository.dart';
import '../../features/media/music_sheet_library_providers.dart';
import '../../features/player/player_providers.dart';
import '../../features/plugins/domain/plugin.dart';
import '../../features/plugins/plugin_providers.dart';
import 'bottom_player_bar.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions = const <Widget>[],
  });

  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget> actions;

  static const List<_PrimaryDestination> _primaryDestinations =
      <_PrimaryDestination>[
        _PrimaryDestination('/discover', '排行榜', Icons.emoji_events_outlined),
        _PrimaryDestination(
          '/recommend-sheets',
          '热门歌单',
          Icons.local_fire_department_outlined,
        ),
        _PrimaryDestination('/downloads', '下载管理', Icons.download_rounded),
        _PrimaryDestination('/local-music', '本地音乐', Icons.folder_open_rounded),
        _PrimaryDestination('/plugins', '插件管理', Icons.extension_rounded),
        _PrimaryDestination('/recently-played', '最近播放', Icons.history_rounded),
      ];

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final compact = MediaQuery.of(context).size.width < 980;
    final theme = Theme.of(context);
    final shellBackground = theme.scaffoldBackgroundColor;
    final panelBackground = theme.colorScheme.surface;
    final headerBackground = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainer
        : Colors.white;
    final borderColor = theme.dividerColor;

    if (compact) {
      return Scaffold(
        backgroundColor: shellBackground,
        appBar: AppBar(title: Text(title), actions: actions),
        body: SafeArea(child: child),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedCompactIndex(path),
          onDestinationSelected: (index) {
            context.go(switch (index) {
              0 => '/search',
              1 => '/discover',
              2 => '/plugins',
              3 => '/recently-played',
              _ => '/settings',
            });
          },
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.search_rounded),
              label: '搜索',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_rounded),
              label: '发现',
            ),
            NavigationDestination(
              icon: Icon(Icons.extension_rounded),
              label: '插件',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded),
              label: '最近',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              label: '设置',
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: shellBackground,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const _TopBar(),
            Expanded(
              child: Row(
                children: <Widget>[
                  _Sidebar(path: path),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: headerBackground,
                            border: Border(
                              bottom: BorderSide(color: borderColor),
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (subtitle.isNotEmpty)
                                      Text(
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                  ],
                                ),
                              ),
                              if (actions.isNotEmpty)
                                Wrap(spacing: 8, children: actions),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Container(
                            color: panelBackground,
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                            child: child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SharedBottomPlayerBar(),
          ],
        ),
      ),
    );
  }

  int _selectedCompactIndex(String path) {
    if (path.startsWith('/discover') || path.startsWith('/toplist')) {
      return 1;
    }
    if (path.startsWith('/recommend-sheets') ||
        path.startsWith('/sheet') ||
        path.startsWith('/music-sheet') ||
        path.startsWith('/downloads') ||
        path.startsWith('/local-music') ||
        path.startsWith('/recently-played')) {
      return 1;
    }
    if (path.startsWith('/plugins') || path.startsWith('/subscriptions')) {
      return 2;
    }
    if (path.startsWith('/settings')) {
      return 4;
    }
    return 0;
  }
}

class _TopBar extends ConsumerStatefulWidget {
  const _TopBar();

  @override
  ConsumerState<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends ConsumerState<_TopBar> {
  late final TextEditingController _controller;
  bool _isMaximized = false;
  late final WindowListener _windowListener;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _windowListener = _TopBarWindowListener(
      onMaximizeChanged: (value) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isMaximized = value;
        });
      },
    );
    windowManager.addListener(_windowListener);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final maximized = await windowManager.isMaximized();
      if (!mounted) {
        return;
      }
      setState(() {
        _isMaximized = maximized;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uri = GoRouterState.of(context).uri;
    final q = uri.queryParameters['q'] ?? '';
    if (_controller.text != q) {
      _controller.text = q;
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(_windowListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = AppTheme.colorsOf(context);
    final miniModeVisible = ref.watch(
      playerControllerProvider.select((value) => value.miniModeVisible),
    );
    return Container(
      height: 54,
      decoration: BoxDecoration(color: themeColors.topBarBackground),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const Positioned.fill(
            child: DragToMoveArea(child: ColoredBox(color: Colors.transparent)),
          ),
          Row(
            children: <Widget>[
              const Text(
                'MusicWEP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 18),
              _TopBarIcon(
                icon: Icons.chevron_left_rounded,
                onTap: () => GoRouter.of(context).pop(),
              ),
              const SizedBox(width: 6),
              const _TopBarIcon(icon: Icons.chevron_right_rounded),
              const SizedBox(width: 16),
              SizedBox(
                width: 320,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: themeColors.topBarFieldBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (value) {
                      final query = value.trim();
                      if (query.isEmpty) {
                        context.go('/search');
                        return;
                      }
                      context.go(
                        '/search?q=${Uri.encodeQueryComponent(query)}',
                      );
                    },
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      hintText: '在这里输入搜索内容',
                      hintStyle: TextStyle(
                        color: themeColors.topBarHint,
                        fontSize: 14,
                      ),
                      suffixIcon: const Icon(
                        Icons.search_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              const _TopBarIcon(icon: Icons.auto_awesome_outlined),
              const SizedBox(width: 6),
              _TopBarIcon(
                icon: Icons.checkroom_outlined,
                onTap: () => _showThemeCustomizer(context),
              ),
              const SizedBox(width: 6),
              _TopBarIcon(
                icon: Icons.settings_outlined,
                onTap: () => context.go('/settings'),
              ),
              const SizedBox(width: 6),
              _TopBarIcon(
                icon: Icons.picture_in_picture_alt_outlined,
                highlighted: miniModeVisible,
                onTap: () => ref
                    .read(playerControllerProvider.notifier)
                    .toggleMiniMode(),
              ),
              const SizedBox(width: 10),
              _WindowButton(
                icon: Icons.remove_rounded,
                onTap: windowManager.minimize,
              ),
              _WindowButton(
                icon: _isMaximized
                    ? Icons.filter_none_rounded
                    : Icons.crop_square_rounded,
                onTap: () async {
                  if (_isMaximized) {
                    await windowManager.unmaximize();
                    return;
                  }
                  await windowManager.maximize();
                },
              ),
              _WindowButton(
                icon: Icons.close_rounded,
                hoverColor: themeColors.windowCloseHover,
                onTap: windowManager.close,
              ),
            ],
          ),
        ],
      ),
    );
  }
  Future<void> _showThemeCustomizer(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('主题外观'),
          content: const SizedBox(
            width: 520,
            child: ThemeCustomizerPane(compact: true),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localSheets = ref.watch(localMusicSheetControllerProvider);
    final starredSheets = ref.watch(starredMusicSheetControllerProvider);
    final theme = Theme.of(context);
    final sideBackground = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerLow
        : const Color(0xFFF7F7F7);
    final borderColor = theme.dividerColor;

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: sideBackground,
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 12),
          ...AppShell._primaryDestinations.map(
            (item) => _SidebarItem(
              destination: item.path,
              label: item.label,
              icon: item.icon,
              selected: _matches(path, item.path),
            ),
          ),
          const Divider(height: 20, color: Color(0xFFE2E2E2)),
          _LibrarySection(
            title: '我的歌单',
            actions: <Widget>[
              _HeaderActionButton(
                tooltip: '导入歌单',
                icon: Icons.playlist_add_rounded,
                onTap: () => _showImportSheetDialog(context, ref),
              ),
              _HeaderActionButton(
                tooltip: '新建歌单',
                icon: Icons.add_rounded,
                onTap: () => _showCreateSheetDialog(context, ref),
              ),
            ],
            child: localSheets.when(
              data: (items) => Column(
                children: items
                    .map(
                      (sheet) => _LibrarySidebarItem(
                        destination: _musicSheetRoute(
                          localPluginName,
                          sheet.id,
                        ),
                        label: sheet.id == defaultLocalMusicSheetId
                            ? '我喜欢'
                            : sheet.title,
                        icon: sheet.id == defaultLocalMusicSheetId
                            ? Icons.favorite_border_rounded
                            : Icons.music_note_rounded,
                        selected:
                            path == _musicSheetRoute(localPluginName, sheet.id),
                        onRename: sheet.id == defaultLocalMusicSheetId
                            ? null
                            : () => _showRenameSheetDialog(context, ref, sheet),
                        onDelete: sheet.id == defaultLocalMusicSheetId
                            ? null
                            : () => _deleteSheet(context, ref, sheet),
                      ),
                    )
                    .toList(growable: false),
              ),
              error: (error, _) => _SectionMessage(text: error.toString()),
              loading: () => const _SectionLoading(),
            ),
          ),
          const SizedBox(height: 8),
          _LibrarySection(
            title: '我的收藏',
            child: starredSheets.when(
              data: (items) {
                if (items.isEmpty) {
                  return const _SectionMessage(text: '暂无收藏歌单');
                }
                return Column(
                  children: items
                      .map(
                        (sheet) => _LibrarySidebarItem(
                          destination: _musicSheetRoute(
                            sheet.platform,
                            sheet.id,
                          ),
                          label: sheet.title,
                          icon: Icons.music_note_rounded,
                          selected:
                              path ==
                              _musicSheetRoute(sheet.platform, sheet.id),
                          onDelete: () => ref
                              .read(
                                starredMusicSheetControllerProvider.notifier,
                              )
                              .remove(sheet),
                        ),
                      )
                      .toList(growable: false),
                );
              },
              error: (error, _) => _SectionMessage(text: error.toString()),
              loading: () => const _SectionLoading(),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  bool _matches(String path, String destination) {
    if (destination == '/discover') {
      return path == '/discover' || path.startsWith('/toplist');
    }
    if (destination == '/recommend-sheets') {
      return path == '/recommend-sheets' || path.startsWith('/sheet');
    }
    return path == destination || path.startsWith('$destination/');
  }

  Future<void> _showCreateSheetDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('新建歌单'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 30,
            decoration: const InputDecoration(hintText: '请输入歌单名称'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('创建'),
            ),
          ],
        );
      },
    );

    if (value == null || value.isEmpty) {
      return;
    }

    final sheets = await ref
        .read(localMusicSheetControllerProvider.notifier)
        .createSheet(value);
    final created = sheets.lastOrNull;
    if (created != null && context.mounted) {
      context.go(_musicSheetRoute(localPluginName, created.id));
    }
  }

  Future<void> _showRenameSheetDialog(
    BuildContext context,
    WidgetRef ref,
    MusicSheetItem sheet,
  ) async {
    final controller = TextEditingController(text: sheet.title);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('重命名歌单'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 30,
            decoration: const InputDecoration(hintText: '请输入歌单名称'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (value == null || value.isEmpty) {
      return;
    }

    await ref
        .read(localMusicSheetControllerProvider.notifier)
        .renameSheet(sheet.id, value);
  }

  Future<void> _deleteSheet(
    BuildContext context,
    WidgetRef ref,
    MusicSheetItem sheet,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除歌单'),
          content: Text('确认删除歌单“${sheet.title}”？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    await ref
        .read(localMusicSheetControllerProvider.notifier)
        .deleteSheet(sheet.id);
    if (context.mounted &&
        GoRouterState.of(context).uri.path ==
            _musicSheetRoute(localPluginName, sheet.id)) {
      context.go(_musicSheetRoute(localPluginName, defaultLocalMusicSheetId));
    }
  }

  Future<void> _showImportSheetDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final snapshot = ref.read(pluginControllerProvider).valueOrNull;
    final plugins = (snapshot?.plugins ?? const <PluginRecord>[])
        .where(
          (plugin) =>
              plugin.meta.enabled &&
              (plugin.manifest?.supportedMethods.contains('importMusicSheet') ??
                  false),
        )
        .toList(growable: false);
    if (plugins.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前没有支持导入歌单的插件。')));
      return;
    }

    PluginRecord selectedPlugin = plugins.first;
    final titleController = TextEditingController();
    final urlController = TextEditingController();

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('导入歌单'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DropdownButtonFormField<String>(
                      value: selectedPlugin.storageKey,
                      decoration: const InputDecoration(labelText: '插件'),
                      items: plugins
                          .map(
                            (plugin) => DropdownMenuItem<String>(
                              value: plugin.storageKey,
                              child: Text(plugin.displayName),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        final match = plugins.where(
                          (plugin) => plugin.storageKey == value,
                        );
                        if (match.isNotEmpty) {
                          setState(() {
                            selectedPlugin = match.first;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlController,
                      decoration: const InputDecoration(
                        labelText: '歌单链接 / ID',
                        hintText: '请输入插件可识别的歌单地址或 ID',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: '本地歌单名称',
                        hintText: '留空则使用“导入歌单”',
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('导入'),
                ),
              ],
            );
          },
        );
      },
    );

    if (accepted != true || urlController.text.trim().isEmpty) {
      return;
    }

    final methodService = await ref.read(pluginMethodServiceProvider.future);
    final tracks = await methodService.importMusicSheet(
      plugin: selectedPlugin,
      urlLike: urlController.text.trim(),
    );
    if (tracks.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('插件未返回可导入的歌曲。')));
      }
      return;
    }

    final sheets = await ref
        .read(localMusicSheetControllerProvider.notifier)
        .createSheet(
          titleController.text.trim().isEmpty
              ? '导入歌单'
              : titleController.text.trim(),
          musicList: tracks,
          artwork: tracks.first.artwork,
        );
    final created = sheets.lastOrNull;
    if (created != null && context.mounted) {
      context.go(_musicSheetRoute(localPluginName, created.id));
    }
  }
}

class _LibrarySection extends StatelessWidget {
  const _LibrarySection({
    required this.title,
    required this.child,
    this.actions = const <Widget>[],
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
                  child: Text(
                    title,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              ...actions,
            ],
          ),
          child,
        ],
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        Theme.of(context).iconTheme.color ?? const Color(0xFF6A6A6A);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: iconColor),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.label,
    required this.icon,
    required this.selected,
  });

  final String destination;
  final String label;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.colorsOf(context).accent;
    final softAccent = AppTheme.colorsOf(context).softAccent;
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.onSurface.withValues(alpha: 0.8);
    return InkWell(
      onTap: () => context.go(destination),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: selected ? softAccent : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: selected ? accent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 19, color: selected ? accent : baseColor),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: selected ? accent : baseColor,
                fontSize: 15,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibrarySidebarItem extends StatelessWidget {
  const _LibrarySidebarItem({
    required this.destination,
    required this.label,
    required this.icon,
    required this.selected,
    this.onRename,
    this.onDelete,
  });

  final String destination;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.colorsOf(context).accent;
    final softAccent = AppTheme.colorsOf(context).softAccent;
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.onSurface.withValues(alpha: 0.78);
    return InkWell(
      onTap: () => context.go(destination),
      child: Container(
        height: 34,
        padding: const EdgeInsets.only(left: 10, right: 4),
        decoration: BoxDecoration(
          color: selected ? softAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 16, color: selected ? accent : baseColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? accent : baseColor,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (onRename != null || onDelete != null)
              PopupMenuButton<String>(
                tooltip: '操作',
                padding: EdgeInsets.zero,
                iconSize: 16,
                onSelected: (value) {
                  if (value == 'rename') {
                    onRename?.call();
                  } else if (value == 'delete') {
                    onDelete?.call();
                  }
                },
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  if (onRename != null)
                    const PopupMenuItem<String>(
                      value: 'rename',
                      child: Text('重命名'),
                    ),
                  if (onDelete != null)
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text(onRename == null ? '取消收藏' : '删除'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionMessage extends StatelessWidget {
  const _SectionMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: TextStyle(fontSize: 12, color: color)),
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _PlayerIcon extends StatelessWidget {
  const _PlayerIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: 22, color: const Color(0xFF404040));
  }
}

class _TopBarIcon extends StatelessWidget {
  const _TopBarIcon({required this.icon, this.onTap, this.highlighted = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.colorsOf(context).accent;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: highlighted ? accent.withValues(alpha: 0.22) : null,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: highlighted ? accent : const Color(0x40FFFFFF),
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _TopBarWindowListener extends WindowListener {
  _TopBarWindowListener({required this.onMaximizeChanged});

  final ValueChanged<bool> onMaximizeChanged;

  @override
  void onWindowMaximize() {
    onMaximizeChanged(true);
  }

  @override
  void onWindowUnmaximize() {
    onMaximizeChanged(false);
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.icon,
    required this.onTap,
    this.hoverColor = const Color(0x20FFFFFF),
  });

  final IconData icon;
  final Future<void> Function() onTap;
  final Color hoverColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: hoverColor,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        width: 34,
        height: double.infinity,
        child: Center(child: Icon(icon, color: Colors.white, size: 18)),
      ),
    );
  }
}

class _PrimaryDestination {
  const _PrimaryDestination(this.path, this.label, this.icon);

  final String path;
  final String label;
  final IconData icon;
}

String _musicSheetRoute(String pluginId, String sheetId) {
  return '/music-sheet/${Uri.encodeComponent(pluginId)}/${Uri.encodeComponent(sheetId)}';
}

extension<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
