import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../features/player/presentation/player_window_bridge.dart';
import '../features/player/presentation/widgets/player_overlays.dart';
import 'bootstrap/bootstrap.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

class MusicFreeApp extends ConsumerWidget {
  const MusicFreeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(bootstrapProvider);
    final themeSettings =
        ref.watch(appThemeControllerProvider).valueOrNull ??
        AppThemeSettings.defaults;

    return MaterialApp.router(
      title: 'MusicFree Flutter',
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

class _DesktopWindowFrame extends StatefulWidget {
  const _DesktopWindowFrame({required this.child});

  final Widget child;

  @override
  State<_DesktopWindowFrame> createState() => _DesktopWindowFrameState();
}

class _DesktopWindowFrameState extends State<_DesktopWindowFrame>
    with WindowListener {
  bool _isFocused = true;
  bool _isMaximized = false;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    if (_isWindowsDesktop) {
      windowManager.addListener(this);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final maximized = await windowManager.isMaximized();
        final fullScreen = await windowManager.isFullScreen();
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
  void onWindowUnmaximize() {
    setState(() {
      _isMaximized = false;
    });
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
