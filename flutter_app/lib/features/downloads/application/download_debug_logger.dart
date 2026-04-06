import 'dart:io';

import 'package:flutter/foundation.dart';

String pathForDownloadDebugLog(String logsDirectoryPath) {
  return '$logsDirectoryPath${Platform.pathSeparator}download_debug.log';
}

Future<void> appendDownloadDebugLog(
  String filePath,
  String source,
  String message,
) async {
  final file = File(filePath);
  final parent = file.parent;
  if (!await parent.exists()) {
    await parent.create(recursive: true);
  }
  final timestamp = DateTime.now().toIso8601String();
  final line = '[$timestamp][$source] $message';
  debugPrint(line);
  await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
}

class DownloadDebugLogger {
  DownloadDebugLogger(this.filePath);

  final String filePath;
  Future<void> _queue = Future<void>.value();

  void log(String source, String message) {
    _queue = _queue.then(
      (_) => appendDownloadDebugLog(filePath, source, message),
    );
  }
}
