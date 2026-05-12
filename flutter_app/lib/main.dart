import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';

// Desktop-only imports — only referenced inside Platform.isWindows guards.
import 'main_desktop.dart' if (dart.library.html) 'main_stub.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await initDesktop(args);
    return;
  }

  // Android / iOS — straight to app.
  runApp(const ProviderScope(child: MusicWEPApp()));
}
