import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'core/window/window_size_storage.dart';
import 'features/player/presentation/desktop_lyric_window.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final windowController = await WindowController.fromCurrentEngine();
  final parsedArgs = DesktopLyricWindowArgs.parse(windowController.arguments);

  if (parsedArgs.type == DesktopLyricWindowArgs.lyric) {
    runApp(DesktopLyricWindowApp(args: parsedArgs));
    return;
  }
  if (parsedArgs.type == DesktopLyricWindowArgs.miniMode) {
    runApp(DesktopMiniModeWindowApp(args: parsedArgs));
    return;
  }

  final initialSize =
      await WindowSizeStorage.readWindowSize() ??
      WindowSizeStorage.fallbackSize;

  unawaited(
    windowManager.waitUntilReadyToShow(
      WindowOptions(
        backgroundColor: Colors.transparent,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
        minimumSize: WindowSizeStorage.minimumSize,
        size: initialSize,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    ),
  );

  MediaKit.ensureInitialized();
  runApp(const ProviderScope(child: MusicWEPApp()));
}
