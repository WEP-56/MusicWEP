import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../features/player/domain/player_models.dart';
import '../features/player/player_providers.dart';
import '../features/player/presentation/player_window_bridge.dart';
import '../features/player/presentation/widgets/player_overlays.dart';
import '../features/settings/application/app_settings_controller.dart';
import 'bootstrap/bootstrap.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

class MusicWEPApp extends ConsumerWidget {
  const MusicWEPApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(bootstrapProvider);
    final themeSettings =
        ref.watch(appThemeControllerProvider).valueOrNull ??
        AppThemeSettings.defaults;

    return MaterialApp.router(
      title: 'MusicWEP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(themeSettings.preset),
      darkTheme: AppTheme.dark(themeSettings.preset),
      themeMode: themeSettings.mode,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) {
        if (bootstrap.isLoading) {
          return const _BootstrapScaffold(
            title: 'Preparing workspace',
            message: 'Initializing plugin directories and runtime.',
            loading: true,
          );
        }

        if (bootstrap.hasError) {
          return _BootstrapScaffold(
            title: 'Bootstrap failed',
            message: bootstrap.error.toString(),
          );
        }

        return _DesktopWindowFrame(
          child: PlayerWindowBridge(
            child: Stack(
              children: <Widget>[
                child ?? const SizedBox.shrink(),
                const PlayerOverlays(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DesktopWindowFrame extends ConsumerStatefulWidget {
  const _DesktopWindowFrame({required this.child});

  final Widget child;

  @override
  ConsumerState<_DesktopWindowFrame> createState() =>
      _DesktopWindowFrameState();
}

class _DesktopWindowFrameState extends ConsumerState<_DesktopWindowFrame>
    with WindowListener, TrayListener {
  bool _isFocused = true;
  bool _isMaximized = false;
  bool _isFullScreen = false;
  bool _trayReady = false;

  static const String _trayIconAsset = 'windows/runner/resources/app_icon.ico';

  @override
  void initState() {
    super.initState();
    if (_isWindowsDesktop) {
      windowManager.addListener(this);
      trayManager.addListener(this);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await windowManager.setPreventClose(true);
        final maximized = await windowManager.isMaximized();
        final fullScreen = await windowManager.isFullScreen();
        await _setupTray();
        if (!mounted) {
          return;
        }
        setState(() {
          _isMaximized = maximized;
          _isFullScreen = fullScreen;
        });
      });
    }
  }

  @override
  void dispose() {
    if (_isWindowsDesktop) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isWindowsDesktop) {
      return widget.child;
    }

    final radius = (_isMaximized || _isFullScreen) ? 0.0 : 8.0;
    return DragToResizeArea(
      resizeEdgeSize: 8,
      resizeEdgeMargin: const EdgeInsets.all(1),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: const Color(0xFFE3E3E3),
            width: (_isMaximized || _isFullScreen) ? 0 : 1,
          ),
          boxShadow: <BoxShadow>[
            if (!_isMaximized && !_isFullScreen)
              BoxShadow(
                color: Colors.black.withValues(alpha: _isFocused ? 0.12 : 0.08),
                blurRadius: 18,
                offset: Offset(0, _isFocused ? 6 : 3),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: widget.child,
        ),
      ),
    );
  }

  @override
  void onWindowBlur() {
    setState(() {
      _isFocused = false;
    });
  }

  @override
  void onWindowFocus() {
    setState(() {
      _isFocused = true;
    });
  }

  @override
  void onWindowEnterFullScreen() {
    setState(() {
      _isFullScreen = true;
    });
  }

  @override
  void onWindowLeaveFullScreen() {
    setState(() {
      _isFullScreen = false;
    });
  }

  @override
  void onWindowMaximize() {
    setState(() {
      _isMaximized = true;
    });
  }

  @override
  void onWindowClose() {
    final closeBehavior = _closeBehavior;
    unawaited(_applyCloseBehavior(closeBehavior));
  }

  @override
  void onWindowUnmaximize() {
    setState(() {
      _isMaximized = false;
    });
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_showMainWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(_showTrayContextMenu());
  }

  @override
  void onTrayIconRightMouseUp() {
    unawaited(_showTrayContextMenu());
  }

  String get _closeBehavior =>
      ref
          .read(appSettingsControllerProvider)
          .valueOrNull
          ?.normal
          .closeBehavior ??
      'tray';

  Future<void> _setupTray() async {
    if (_trayReady) {
      return;
    }
    await trayManager.setIcon(_trayIconAsset);
    await trayManager.setToolTip('MusicWEP');
    await _refreshTrayMenu();
    _trayReady = true;
  }

  Future<void> _applyCloseBehavior(String behavior) async {
    switch (behavior) {
      case 'exit_app':
        await _exitApplication();
        return;
      case 'tray':
        await _hideToTray();
        return;
      default:
        await windowManager.minimize();
        return;
    }
  }

  Future<void> _showMainWindow() async {
    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setSkipTaskbar(false);
  }

  Future<void> _showTrayContextMenu() async {
    await _refreshTrayMenu();
    await trayManager.popUpContextMenu();
  }

  Future<void> _refreshTrayMenu() async {
    final playerState = ref.read(playerControllerProvider);
    await trayManager.setContextMenu(
      Menu(
        items: <MenuItem>[
          MenuItem(
            key: 'previous_track',
            label: '上一首',
            disabled: !playerState.hasTrack || !playerState.hasPrevious,
            onClick: (_) => unawaited(
              ref.read(playerControllerProvider.notifier).playPrevious(),
            ),
          ),
          MenuItem(
            key: 'next_track',
            label: '下一首',
            disabled: !playerState.hasTrack || !playerState.hasNext,
            onClick: (_) => unawaited(
              ref.read(playerControllerProvider.notifier).playNext(),
            ),
          ),
          MenuItem.submenu(
            key: 'play_mode',
            label: '播放模式',
            submenu: Menu(
              items: <MenuItem>[
                _buildRepeatModeMenuItem(
                  label: '列表循环',
                  mode: RepeatMode.listLoop,
                  currentMode: playerState.repeatMode,
                ),
                _buildRepeatModeMenuItem(
                  label: '单曲循环',
                  mode: RepeatMode.singleLoop,
                  currentMode: playerState.repeatMode,
                ),
                _buildRepeatModeMenuItem(
                  label: '随机播放',
                  mode: RepeatMode.shuffle,
                  currentMode: playerState.repeatMode,
                ),
              ],
            ),
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'open_settings',
            label: '设置',
            onClick: (_) => unawaited(_openSettings()),
          ),
          MenuItem(
            key: 'exit_app',
            label: '退出',
            onClick: (_) => unawaited(_exitApplication()),
          ),
        ],
      ),
    );
  }

  MenuItem _buildRepeatModeMenuItem({
    required String label,
    required RepeatMode mode,
    required RepeatMode currentMode,
  }) {
    return MenuItem.checkbox(
      key: 'repeat_mode_${mode.name}',
      label: label,
      checked: currentMode == mode,
      onClick: (_) => _handleRepeatModeSelection(mode),
    );
  }

  void _handleRepeatModeSelection(RepeatMode mode) {
    ref.read(playerControllerProvider.notifier).setRepeatMode(mode);
    unawaited(_refreshTrayMenu());
  }

  Future<void> _openSettings() async {
    await _showMainWindow();
    ref.read(appRouterProvider).go('/settings');
  }

  Future<void> _hideToTray() async {
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }

  Future<void> _exitApplication() async {
    try {
      if (_trayReady) {
        await trayManager.destroy();
      }
    } catch (_) {
      // ignore tray teardown failures on exit
    }
    await windowManager.destroy();
  }
}

final bool _isWindowsDesktop = !kIsWeb && Platform.isWindows;

class _BootstrapScaffold extends StatelessWidget {
  const _BootstrapScaffold({
    required this.title,
    required this.message,
    this.loading = false,
  });

  final String title;
  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (loading) ...<Widget>[
                    const CircularProgressIndicator(strokeWidth: 2),
                    const SizedBox(height: 20),
                  ],
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text(message, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
