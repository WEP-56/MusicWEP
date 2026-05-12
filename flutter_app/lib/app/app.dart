import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/window/window_visibility_provider.dart';
import '../features/player/domain/player_models.dart';
import '../features/player/player_providers.dart';
import '../features/player/presentation/player_window_bridge.dart';
import '../features/player/presentation/widgets/player_overlays.dart';
import '../features/settings/application/app_settings_controller.dart';
import 'bootstrap/bootstrap.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

// Desktop-only imports — guarded by _isWindowsDesktop at runtime.
import 'app_desktop_frame.dart'
    if (dart.library.html) 'app_desktop_frame_stub.dart';

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
      theme: AppTheme.light(themeSettings.activePreset),
      darkTheme: AppTheme.dark(themeSettings.activePreset),
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

        return buildDesktopWindowFrame(
          context: context,
          child: PlayerWindowBridge(
            child: _BackPressHandler(
              child: Stack(
                children: <Widget>[
                  child ?? const SizedBox.shrink(),
                  const PlayerOverlays(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}


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

/// Intercepts the Android back button so it navigates back within the app
/// rather than immediately exiting. On the root route it minimises to
/// background (Android behaviour) instead of killing the process.
class _BackPressHandler extends StatelessWidget {
  const _BackPressHandler({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Never let the system handle the back press directly.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context, rootNavigator: false);
        if (navigator.canPop()) {
          navigator.pop();
        } else {
          // At the root — move app to background instead of exiting.
          await SystemNavigator.pop(animated: true);
        }
      },
      child: child,
    );
  }
}
