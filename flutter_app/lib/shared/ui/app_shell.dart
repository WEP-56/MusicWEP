import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as path_util;
import 'package:window_manager/window_manager.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/theme_controller.dart';
import '../../app/theme/theme_customizer.dart';
import '../../core/media/media_constants.dart';
import '../../core/media/media_models.dart';
import '../../core/window/window_visibility_provider.dart';
import '../../features/media/application/local_music_sheet_repository.dart';
import '../../features/media/music_sheet_library_providers.dart';
import '../../features/player/player_providers.dart';
import '../../features/plugins/domain/plugin.dart';
import '../../features/plugins/plugin_providers.dart';
import '../../features/update/domain/app_update_models.dart';
import '../../features/update/update_providers.dart';
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

  @override
  Widget build(BuildContext context) => child;
}

class AppShellScaffold extends ConsumerWidget {
  const AppShellScaffold({
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
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    final compact = MediaQuery.of(context).size.width < 980;
    final theme = Theme.of(context);
    final shellBackground = theme.scaffoldBackgroundColor;
    final themeSettings =
        ref.watch(appThemeControllerProvider).valueOrNull ??
        AppThemeSettings.defaults;
    final appPaths = ref.watch(appPathsProvider).valueOrNull;
    final activeBackground = themeSettings.activeCustomTheme?.background;
    final backgroundMedia = activeBackground != null && appPaths != null
        ? _ResolvedBackgroundMedia(
            type: activeBackground.type,
            path: path_util.join(
              appPaths.appDataDirectory.path,
              activeBackground.relativePath,
            ),
          )
        : null;

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
              child: _ShellBackgroundSurface(
                background: backgroundMedia,
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _Sidebar(
                            path: path,
                            backgroundActive: backgroundMedia != null,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                16,
                                20,
                                12,
                              ),
                              child: child,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SharedBottomPlayerBar(
                      backgroundActive: backgroundMedia != null,
                    ),
                  ],
                ),
              ),
            ),
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

class _ShellBackgroundSurface extends ConsumerStatefulWidget {
  const _ShellBackgroundSurface({
    required this.background,
    required this.child,
  });

  final _ResolvedBackgroundMedia? background;
  final Widget child;

  @override
  ConsumerState<_ShellBackgroundSurface> createState() =>
      _ShellBackgroundSurfaceState();
}

class _ShellBackgroundSurfaceState
    extends ConsumerState<_ShellBackgroundSurface>
    with WindowListener {
  bool _windowFocused = true;
  bool _windowVisible = true;
  bool _windowMinimized = false;
  bool _listeningToWindowEvents = false;

  bool get _shouldRenderBackground {
    if (!Platform.isWindows) {
      return true;
    }
    return _windowVisible && !_windowMinimized;
  }

  bool get _shouldAnimateBackground {
    if (!Platform.isWindows) {
      return true;
    }
    return _windowVisible && !_windowMinimized && _windowFocused;
  }

  @override
  void initState() {
    super.initState();
    _initializeWindowState();
  }

  Future<void> _initializeWindowState() async {
    if (!Platform.isWindows) {
      return;
    }
    windowManager.addListener(this);
    _listeningToWindowEvents = true;
    final focused = await windowManager.isFocused();
    final visible = await windowManager.isVisible();
    final minimized = await windowManager.isMinimized();
    if (!mounted) {
      return;
    }
    setState(() {
      _windowFocused = focused;
      _windowVisible = visible;
      _windowMinimized = minimized;
    });
  }

  @override
  void dispose() {
    if (_listeningToWindowEvents) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appWindowVisible = ref.watch(appWindowVisibilityProvider);
    final theme = Theme.of(context);
    final shellSurface = theme.colorScheme.surface;
    final effectiveBackground = _shouldRenderBackground && appWindowVisible
        ? widget.background
        : null;
    final allowVideoMaintenance =
        !appWindowVisible ||
        !_windowVisible ||
        _windowMinimized ||
        !_windowFocused;
    final backgroundOpacity = effectiveBackground == null
        ? 1.0
        : theme.brightness == Brightness.dark
        ? 0.7
        : 0.56;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (effectiveBackground != null)
          Positioned.fill(
            child: _BackgroundMediaLayer(
              background: effectiveBackground,
              fallbackColor: shellSurface,
              animateVideo: _shouldAnimateBackground,
              allowVideoMaintenance: allowVideoMaintenance,
            ),
          ),
        Positioned.fill(
          child: ColoredBox(
            color: shellSurface.withValues(alpha: backgroundOpacity),
          ),
        ),
        widget.child,
      ],
    );
  }

  @override
  void onWindowBlur() {
    if (!mounted) {
      return;
    }
    setState(() {
      _windowFocused = false;
    });
  }

  @override
  void onWindowFocus() {
    if (!mounted) {
      return;
    }
    setState(() {
      _windowFocused = true;
    });
  }

  @override
  void onWindowMinimize() {
    if (!mounted) {
      return;
    }
    setState(() {
      _windowMinimized = true;
      _windowVisible = false;
    });
  }

  @override
  void onWindowRestore() {
    if (!mounted) {
      return;
    }
    setState(() {
      _windowMinimized = false;
      _windowVisible = true;
      _windowFocused = true;
    });
  }
}

class _ResolvedBackgroundMedia {
  const _ResolvedBackgroundMedia({required this.type, required this.path});

  final AppThemeBackgroundType type;
  final String path;
}

class _BackgroundMediaLayer extends StatelessWidget {
  const _BackgroundMediaLayer({
    required this.background,
    required this.fallbackColor,
    required this.animateVideo,
    required this.allowVideoMaintenance,
  });

  final _ResolvedBackgroundMedia background;
  final Color fallbackColor;
  final bool animateVideo;
  final bool allowVideoMaintenance;

  @override
  Widget build(BuildContext context) {
    return switch (background.type) {
      AppThemeBackgroundType.image => LayoutBuilder(
        builder: (context, constraints) {
          final pixelRatio = MediaQuery.devicePixelRatioOf(context);
          final width = constraints.maxWidth.isFinite
              ? (constraints.maxWidth * pixelRatio).round()
              : null;
          final height = constraints.maxHeight.isFinite
              ? (constraints.maxHeight * pixelRatio).round()
              : null;

          return Image.file(
            File(background.path),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
            cacheWidth: width == null || width <= 0 ? null : width,
            cacheHeight: height == null || height <= 0 ? null : height,
            errorBuilder: (context, error, stackTrace) {
              return ColoredBox(color: fallbackColor);
            },
          );
        },
      ),
      AppThemeBackgroundType.video => _BackgroundVideoLayer(
        path: background.path,
        fallbackColor: fallbackColor,
        playing: animateVideo,
        allowMaintenance: allowVideoMaintenance,
      ),
    };
  }
}

class _BackgroundVideoLayer extends StatefulWidget {
  const _BackgroundVideoLayer({
    required this.path,
    required this.fallbackColor,
    required this.playing,
    required this.allowMaintenance,
  });

  final String path;
  final Color fallbackColor;
  final bool playing;
  final bool allowMaintenance;

  @override
  State<_BackgroundVideoLayer> createState() => _BackgroundVideoLayerState();
}

class _BackgroundVideoLayerState extends State<_BackgroundVideoLayer> {
  static const Duration _backgroundVideoRecycleInterval = Duration(minutes: 6);
  static _CachedBackgroundVideoBackend? _cachedBackend;

  Player? _player;
  VideoController? _controller;
  StreamSubscription<bool>? _completedSubscription;
  Timer? _recycleTimer;
  bool _hasError = false;
  int? _lastOutputWidth;
  int? _lastOutputHeight;
  bool _pendingRecycle = false;
  bool _playbackSyncInProgress = false;
  bool _rebuildInProgress = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant _BackgroundVideoLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _pendingRecycle = false;
      _initialize();
      return;
    }
    if (oldWidget.playing != widget.playing) {
      unawaited(_syncPlaybackState());
    }
    if ((!oldWidget.allowMaintenance && widget.allowMaintenance) &&
        _pendingRecycle) {
      _pendingRecycle = false;
      unawaited(_rebuildVideoBackend(forcePlay: widget.playing));
    }
  }

  Future<void> _initialize() async {
    setState(() {
      _hasError = false;
    });
    try {
      final reused = _tryReuseCachedBackend();
      if (reused) {
        _attachPlaybackObservers();
        await _syncPlaybackState();
        if (!mounted) {
          return;
        }
        setState(() {
          _hasError = false;
        });
        return;
      }
      await _rebuildVideoBackend(
        resumePosition: Duration.zero,
        forcePlay: widget.playing,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hasError = true;
      });
    }
  }

  bool _tryReuseCachedBackend() {
    final cachedBackend = _cachedBackend;
    if (cachedBackend == null || cachedBackend.path != widget.path) {
      return false;
    }
    cachedBackend.disposeTimer?.cancel();
    _player = cachedBackend.player;
    _controller = cachedBackend.controller;
    return true;
  }

  Future<void> _syncPlaybackState() async {
    final player = _player;
    if (player == null || _rebuildInProgress) {
      return;
    }
    if (_playbackSyncInProgress) {
      return;
    }
    _playbackSyncInProgress = true;
    try {
      if (widget.playing) {
        await player.play();
      } else {
        await player.pause();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hasError = true;
      });
    } finally {
      _playbackSyncInProgress = false;
    }
  }

  Future<void> _rebuildVideoBackend({
    Duration? resumePosition,
    bool? forcePlay,
  }) async {
    if (_rebuildInProgress) {
      return;
    }
    _rebuildInProgress = true;

    final currentPlayer = _player;
    final targetPosition = resumePosition ?? currentPlayer?.state.position;

    try {
      final nextPlayer = Player(
        configuration: const PlayerConfiguration(
          muted: true,
          bufferSize: 4 * 1024 * 1024,
          title: 'MusicWEP Background',
        ),
      );
      final nextController = VideoController(
        nextPlayer,
        configuration: const VideoControllerConfiguration(scale: 0.75),
      );

      await nextPlayer.setPlaylistMode(PlaylistMode.single);
      await nextPlayer.open(
        Media(File(widget.path).uri.toString()),
        play: false,
      );

      if (targetPosition != null && targetPosition > Duration.zero) {
        try {
          await nextPlayer.seek(targetPosition);
        } catch (_) {
          // Ignore seek failures for short or non-seekable files.
        }
      }

      if ((forcePlay ?? widget.playing) == true) {
        await nextPlayer.play();
      }

      try {
        await nextController.waitUntilFirstFrameRendered.timeout(
          const Duration(seconds: 2),
        );
      } catch (_) {
        // Continue even if the first-frame signal is delayed.
      }

      if (!mounted) {
        await nextPlayer.dispose();
        return;
      }

      final previousPlayer = _player;
      setState(() {
        _player = nextPlayer;
        _controller = nextController;
        _hasError = false;
      });
      _cachedBackend = _CachedBackgroundVideoBackend(
        path: widget.path,
        player: nextPlayer,
        controller: nextController,
      );
      _attachPlaybackObservers();

      if (previousPlayer != null && !identical(previousPlayer, nextPlayer)) {
        await _safeDisposePlayer(previousPlayer);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hasError = true;
      });
      rethrow;
    } finally {
      _rebuildInProgress = false;
    }
  }

  void _attachPlaybackObservers() {
    if (_player == null) {
      return;
    }
    _completedSubscription?.cancel();
    _recycleTimer?.cancel();
    _completedSubscription = null;

    _recycleTimer = Timer.periodic(_backgroundVideoRecycleInterval, (_) {
      if (!mounted || !widget.playing) {
        return;
      }
      if (widget.allowMaintenance) {
        _pendingRecycle = false;
        unawaited(_rebuildVideoBackend(forcePlay: widget.playing));
        return;
      }
      _pendingRecycle = true;
    });
  }

  void _updateVideoOutputSize(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final width = constraints.maxWidth.isFinite
        ? (constraints.maxWidth * pixelRatio).round()
        : null;
    final height = constraints.maxHeight.isFinite
        ? (constraints.maxHeight * pixelRatio).round()
        : null;
    if (width == null ||
        height == null ||
        width <= 0 ||
        height <= 0 ||
        (_lastOutputWidth == width && _lastOutputHeight == height)) {
      return;
    }
    _lastOutputWidth = width;
    _lastOutputHeight = height;
    unawaited(controller.setSize(width: width, height: height));
  }

  @override
  void dispose() {
    _completedSubscription?.cancel();
    _recycleTimer?.cancel();
    final player = _player;
    final controller = _controller;
    final cachedBackend = _cachedBackend;
    if (player != null &&
        controller != null &&
        cachedBackend != null &&
        identical(cachedBackend.player, player) &&
        identical(cachedBackend.controller, controller)) {
      cachedBackend.disposeTimer?.cancel();
      cachedBackend.disposeTimer = Timer(const Duration(seconds: 2), () async {
        if (!identical(_cachedBackend, cachedBackend)) {
          return;
        }
        _cachedBackend = null;
        await _safeDisposePlayer(cachedBackend.player);
      });
    } else {
      unawaited(_safeDisposePlayer(_player));
    }
    super.dispose();
  }

  Future<void> _safeDisposePlayer(Player? player) async {
    if (player == null) {
      return;
    }
    try {
      await player.dispose();
    } catch (_) {
      // Ignore duplicate disposal races from fast widget churn.
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_hasError || controller == null) {
      return ColoredBox(color: widget.fallbackColor);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        _updateVideoOutputSize(context, constraints);
        return IgnorePointer(
          child: Video(
            controller: controller,
            width: constraints.maxWidth.isFinite ? constraints.maxWidth : null,
            height: constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : null,
            fit: BoxFit.cover,
            fill: widget.fallbackColor,
            controls: NoVideoControls,
            filterQuality: FilterQuality.low,
            pauseUponEnteringBackgroundMode: true,
            wakelock: false,
          ),
        );
      },
    );
  }
}

class _CachedBackgroundVideoBackend {
  _CachedBackgroundVideoBackend({
    required this.path,
    required this.player,
    required this.controller,
  });

  final String path;
  final Player player;
  final VideoController controller;
  Timer? disposeTimer;
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
              _TopBarIcon(
                icon: Icons.system_update_alt_rounded,
                onTap: () => _showAppUpdateDialog(context),
              ),
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

  Future<void> _showAppUpdateDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _AppUpdateDialog(
          onConfirmInstall: () => _showUpdateConfirmation(dialogContext),
        );
      },
    );
  }

  Future<void> _showUpdateConfirmation(BuildContext context) async {
    final updateStatus = ref.read(appUpdateControllerProvider).valueOrNull;
    if (updateStatus == null || !updateStatus.hasUpdate) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('发现新版本'),
          content: Text(
            '当前版本 ${updateStatus.currentVersion}\n'
            '最新版本 ${updateStatus.latestVersion ?? ''}\n\n'
            '是否下载并启动安装器？',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('更新'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    unawaited(
      ref.read(appUpdateControllerProvider.notifier).downloadAndInstallUpdate(),
    );
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return const _AppUpdateProgressDialog();
      },
    );
  }
}

class _AppUpdateDialog extends ConsumerWidget {
  const _AppUpdateDialog({required this.onConfirmInstall});

  final Future<void> Function() onConfirmInstall;

  static const String _logoAsset = 'assets/logo.png';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(appUpdateControllerProvider);
    final updateStatus = updateState.valueOrNull;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  _logoAsset,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                updateStatus?.currentVersion ?? '读取版本中...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if ((updateStatus?.latestVersion?.isNotEmpty ?? false) &&
                  updateStatus?.latestVersion !=
                      updateStatus?.currentVersion) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  '最新版本 ${updateStatus!.latestVersion!}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: updateStatus == null || updateStatus.isBusy
                      ? null
                      : () async {
                          final result = await ref
                              .read(appUpdateControllerProvider.notifier)
                              .checkForUpdates();
                          if (!context.mounted) {
                            return;
                          }
                          if (result == AppUpdateCheckResult.updateAvailable) {
                            await onConfirmInstall();
                          }
                        },
                  child: Text(
                    updateStatus?.stage == AppUpdateStage.checking
                        ? '检测中...'
                        : '检测更新',
                  ),
                ),
              ),
              if (updateState.isLoading) ...<Widget>[
                const SizedBox(height: 12),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
              if ((updateStatus?.message?.isNotEmpty ?? false) ||
                  (updateStatus?.errorDetails?.isNotEmpty ??
                      false)) ...<Widget>[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    updateStatus?.message ?? updateStatus?.errorDetails ?? '',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if ((updateStatus?.errorDetails?.isNotEmpty ?? false) &&
                    updateStatus?.message !=
                        updateStatus?.errorDetails) ...<Widget>[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      updateStatus!.errorDetails!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AppUpdateProgressDialog extends ConsumerWidget {
  const _AppUpdateProgressDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateStatus = ref.watch(appUpdateControllerProvider).valueOrNull;
    final progress = updateStatus?.progress;
    final isError = updateStatus?.stage == AppUpdateStage.error;

    if (isError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      });
      return const SizedBox.shrink();
    }

    return AlertDialog(
      title: const Text('应用更新'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(updateStatus?.message ?? '正在准备更新...'),
            const SizedBox(height: 14),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 10),
            Text(
              progress == null
                  ? '正在获取下载进度...'
                  : '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.path, required this.backgroundActive});

  final String path;
  final bool backgroundActive;

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
        color: backgroundActive
            ? sideBackground.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.5 : 0.4,
              )
            : sideBackground,
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          primary: true,
          padding: const EdgeInsets.only(top: 12, bottom: 16),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ...AppShellScaffold._primaryDestinations.map(
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
                                  path ==
                                  _musicSheetRoute(localPluginName, sheet.id),
                              onRename: sheet.id == defaultLocalMusicSheetId
                                  ? null
                                  : () => _showRenameSheetDialog(
                                      context,
                                      ref,
                                      sheet,
                                    ),
                              onDelete: sheet.id == defaultLocalMusicSheetId
                                  ? null
                                  : () => _deleteSheet(context, ref, sheet),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    error: (error, _) =>
                        _SectionMessage(text: error.toString()),
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
                                      starredMusicSheetControllerProvider
                                          .notifier,
                                    )
                                    .remove(sheet),
                              ),
                            )
                            .toList(growable: false),
                      );
                    },
                    error: (error, _) =>
                        _SectionMessage(text: error.toString()),
                    loading: () => const _SectionLoading(),
                  ),
                ),
              ],
            ),
          ),
        ),
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
