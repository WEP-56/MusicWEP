import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'features/player/infrastructure/android_audio_handler.dart';

// Desktop-only imports — only referenced inside Platform.isWindows guards.
import 'main_desktop.dart' if (dart.library.html) 'main_stub.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await initDesktop(args);
    return;
  }

  // Android / iOS — initialise audio_service for notification controls.
  if (Platform.isAndroid || Platform.isIOS) {
    final container = ProviderContainer();
    final handler = await AudioService.init(
      builder: () => MusicWEPAudioHandler(container),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.musicwep.app.channel.audio',
        androidNotificationChannelName: 'MusicWEP 播放控制',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        notificationColor: Color(0xFF1A1A2E),
      ),
    );
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: ProviderScope(
          overrides: <Override>[
            audioHandlerProvider.overrideWithValue(handler),
          ],
          child: const MusicWEPApp(),
        ),
      ),
    );
    return;
  }

  runApp(const ProviderScope(child: MusicWEPApp()));
}
