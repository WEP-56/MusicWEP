import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:flutter_app/core/runtime/internal/plugin_runtime_logger.dart';

void main() {
  group('PluginRuntimeLogger', () {
    late Directory tempRoot;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp(
        'musicfree_runtime_logger_',
      );
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('writes lines to <storageKey>.log under the log directory', () async {
      final logger = PluginRuntimeLogger(
        directoryPath: tempRoot.path,
        storageKey: 'Example Plugin',
      );
      await logger.append(level: 'invoke', message: 'hello world');
      await logger.append(level: 'invoke', message: 'second line');

      final file = File(logger.logFilePath);
      expect(await file.exists(), isTrue);
      final contents = await file.readAsString();
      expect(contents, contains('[invoke] hello world'));
      expect(contents, contains('[invoke] second line'));
    });

    test('sanitises storage keys so they produce safe filenames', () {
      final logger = PluginRuntimeLogger(
        directoryPath: tempRoot.path,
        storageKey: '中文 Plugin / with\\slashes?',
      );
      expect(path.basename(logger.logFilePath), matches(r'^[A-Za-z0-9._-]+\.log$'));
    });

    test('ASCII-escapes non-printable bytes to keep lines single-line', () async {
      final logger = PluginRuntimeLogger(
        directoryPath: tempRoot.path,
        storageKey: 'ascii',
      );
      await logger.append(level: 'info', message: 'token=中\n');
      final contents = await File(logger.logFilePath).readAsString();
      // `中` (U+4E2D) is outside ASCII and should be escaped.
      expect(contents, contains('token=\\u4E2D'));
      // The line ends with a literal LF written by the logger itself.
      expect(contents.trimRight().contains('\n'), isFalse);
    });

    test('rotates to .log.1 when the main file crosses maxBytes', () async {
      final logger = PluginRuntimeLogger(
        directoryPath: tempRoot.path,
        storageKey: 'rolling',
        maxBytes: 200,
      );
      final long = 'x' * 120;
      await logger.append(level: 'info', message: long);
      await logger.append(level: 'info', message: long);
      await logger.append(level: 'info', message: long);

      final rotated = File(logger.rotatedFilePath);
      expect(await rotated.exists(), isTrue);
      final latest = File(logger.logFilePath);
      expect(await latest.exists(), isTrue);
      expect(await latest.length(), lessThanOrEqualTo(300));
    });
  });
}
