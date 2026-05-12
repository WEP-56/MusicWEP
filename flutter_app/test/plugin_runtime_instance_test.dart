import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:flutter_app/core/filesystem/app_paths.dart';
import 'package:flutter_app/core/runtime/plugin_runtime_host.dart';
import 'package:flutter_app/core/runtime/plugin_runtime_instance.dart';

/// Regression tests for P0-1: each plugin gets its own instance and the
/// script executes exactly once, so top-level JS state is preserved across
/// calls and between multiple inspects/invokes.
///
/// These exercises require the native `flutter_js` QuickJS runtime, which
/// only loads when the Dart VM can resolve its shared library. On hosts
/// where the library is not present (CI without Windows artifacts) the
/// tests are skipped with a clear message instead of crashing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('PluginRuntimeInstance state preservation', () {
    late _RuntimeTestHarness harness;

    setUp(() async {
      harness = await _RuntimeTestHarness.create();
    });

    tearDown(() async {
      await harness.dispose();
    });

    test('script runs once: three invokes return the same random token', () async {
      const script = r'''
"use strict";
let token = Math.random().toString(36).slice(2);
module.exports = {
  platform: "FakeTokenPlugin",
  version: "1.0.0",
  supportedSearchType: ["music"],
  async search(query, page, type) {
    return { isEnd: true, data: [{ id: token, title: token, artist: query }] };
  },
};
''';

      PluginRuntimeInstance instance;
      try {
        instance = await PluginRuntimeInstance.load(
          script: script,
          scriptHash: 'fake-token',
          sourceUrl: 'test://fake-token.js',
          appVersion: '0.1.0',
          os: 'windows',
          language: 'zh-CN',
          appPaths: harness.appPaths,
        );
      } on Object catch (error) {
        if (_isNativeRuntimeMissing(error)) {
          markTestSkipped('QuickJS native library unavailable: $error');
          return;
        }
        rethrow;
      }

      try {
        final first = await instance.invoke(
          method: 'search',
          arguments: const <dynamic>['alpha', 1, 'music'],
        );
        final second = await instance.invoke(
          method: 'search',
          arguments: const <dynamic>['beta', 1, 'music'],
        );
        final third = await instance.invoke(
          method: 'search',
          arguments: const <dynamic>['gamma', 1, 'music'],
        );

        expect(first.success, isTrue, reason: first.errorMessage);
        expect(second.success, isTrue, reason: second.errorMessage);
        expect(third.success, isTrue, reason: third.errorMessage);

        final firstToken = _extractToken(first.data);
        final secondToken = _extractToken(second.data);
        final thirdToken = _extractToken(third.data);

        expect(firstToken, isNotEmpty);
        expect(secondToken, firstToken);
        expect(thirdToken, firstToken);
      } finally {
        instance.dispose();
      }
    });

    test('host caches instances by script hash so repeated invokes reuse state', () async {
      const script = r'''
"use strict";
let counter = 0;
module.exports = {
  platform: "CounterPlugin",
  version: "1.0.0",
  async search() {
    counter += 1;
    return { isEnd: true, data: [{ id: String(counter), title: String(counter) }] };
  },
};
''';

      final host = PluginRuntimeHost(appPaths: harness.appPaths);
      try {
        // Warm the cache using invokeMethod directly.
        final first = await host.invokeMethod(
          script: script,
          sourceUrl: 'test://counter.js',
          appVersion: '0.1.0',
          os: 'windows',
          language: 'zh-CN',
          method: 'search',
          arguments: const <dynamic>[],
        );
        expect(first.success, isTrue, reason: first.errorMessage);
        expect(_extractFirstId(first.data), '1');

        // Same script → cached instance → counter continues.
        final second = await host.invokeMethod(
          script: script,
          sourceUrl: 'test://counter.js',
          appVersion: '0.1.0',
          os: 'windows',
          language: 'zh-CN',
          method: 'search',
          arguments: const <dynamic>[],
        );
        expect(second.success, isTrue);
        expect(_extractFirstId(second.data), '2');

        final third = await host.invokeMethod(
          script: script,
          sourceUrl: 'test://counter.js',
          appVersion: '0.1.0',
          os: 'windows',
          language: 'zh-CN',
          method: 'search',
          arguments: const <dynamic>[],
        );
        expect(third.success, isTrue);
        expect(_extractFirstId(third.data), '3');
      } on Object catch (error) {
        if (_isNativeRuntimeMissing(error)) {
          markTestSkipped('QuickJS native library unavailable: $error');
          return;
        }
        rethrow;
      } finally {
        host.dispose();
      }
    });

    test('invoke timeout marks result as didTimeout but keeps instance usable', () async {
      const script = r'''
"use strict";
let counter = 0;
module.exports = {
  platform: "SlowPlugin",
  version: "1.0.0",
  async search() {
    counter += 1;
    // A hung Promise: never resolves.
    return new Promise(function() {});
  },
  async ping() {
    return { isEnd: true, data: [{ id: "ok" }] };
  }
};
''';
      PluginRuntimeInstance instance;
      try {
        instance = await PluginRuntimeInstance.load(
          script: script,
          scriptHash: 'slow-plugin',
          sourceUrl: 'test://slow.js',
          appVersion: '0.1.0',
          os: 'windows',
          language: 'zh-CN',
          appPaths: harness.appPaths,
        );
      } on Object catch (error) {
        if (_isNativeRuntimeMissing(error)) {
          markTestSkipped('QuickJS native library unavailable: $error');
          return;
        }
        rethrow;
      }
      try {
        final timed = await instance.invoke(
          method: 'search',
          arguments: const <dynamic>[],
          timeout: const Duration(milliseconds: 200),
        );
        expect(timed.success, isFalse);
        expect(timed.didTimeout, isTrue);
        expect(instance.hasTimedOut, isTrue);

        // The instance must still serve subsequent calls.
        final ping = await instance.invoke(
          method: 'ping',
          arguments: const <dynamic>[],
          timeout: const Duration(seconds: 2),
        );
        expect(ping.success, isTrue, reason: ping.errorMessage);
      } finally {
        instance.dispose();
      }
    });

    test('two different scripts run in isolated instances', () async {
      const scriptA = r'''
"use strict";
let tag = "A";
module.exports = {
  platform: "PluginA",
  version: "1.0.0",
  async search() { return { isEnd: true, data: [{ id: tag, title: tag }] }; },
};
''';
      const scriptB = r'''
"use strict";
let tag = "B";
module.exports = {
  platform: "PluginB",
  version: "1.0.0",
  async search() { return { isEnd: true, data: [{ id: tag, title: tag }] }; },
};
''';
      final host = PluginRuntimeHost(appPaths: harness.appPaths);
      try {
        final aResult = await host.invokeMethod(
          script: scriptA,
          sourceUrl: 'test://a.js',
          appVersion: '0.1.0',
          os: 'windows',
          language: 'zh-CN',
          method: 'search',
          arguments: const <dynamic>[],
        );
        final bResult = await host.invokeMethod(
          script: scriptB,
          sourceUrl: 'test://b.js',
          appVersion: '0.1.0',
          os: 'windows',
          language: 'zh-CN',
          method: 'search',
          arguments: const <dynamic>[],
        );
        expect(aResult.success, isTrue);
        expect(bResult.success, isTrue);
        expect(_extractFirstId(aResult.data), 'A');
        expect(_extractFirstId(bResult.data), 'B');
      } on Object catch (error) {
        if (_isNativeRuntimeMissing(error)) {
          markTestSkipped('QuickJS native library unavailable: $error');
          return;
        }
        rethrow;
      } finally {
        host.dispose();
      }
    });
  });
}

String _extractToken(dynamic data) {
  if (data is Map && data['data'] is List && (data['data'] as List).isNotEmpty) {
    final first = (data['data'] as List).first;
    if (first is Map) {
      return first['id']?.toString() ?? '';
    }
  }
  return '';
}

String _extractFirstId(dynamic data) => _extractToken(data);

/// Detects the error thrown when QuickJS native artifacts aren't staged on
/// the host. This keeps the suite green on environments where native
/// artifacts are not available (e.g. `flutter test` outside a full desktop
/// build).
bool _isNativeRuntimeMissing(Object error) {
  final message = error.toString();
  return message.contains('QuickJS') ||
      message.contains('libquickjs') ||
      message.contains('DynamicLibrary') ||
      message.contains('quickjs_c_bridge') ||
      message.contains('Failed to load dynamic library');
}

class _RuntimeTestHarness {
  _RuntimeTestHarness._(this.tempRoot, this.appPaths);

  final Directory tempRoot;
  final AppPaths appPaths;

  static Future<_RuntimeTestHarness> create() async {
    final tempRoot = await Directory.systemTemp.createTemp(
      'musicfree_runtime_instance_test_',
    );
    final rootDirectory = Directory(
      path.join(tempRoot.path, 'musicfree_flutter'),
    );
    final appDataDirectory = Directory(
      path.join(rootDirectory.path, 'app_data'),
    );
    final pluginsDirectory = Directory(
      path.join(rootDirectory.path, 'plugins'),
    );
    final cacheDirectory = Directory(path.join(rootDirectory.path, 'cache'));
    final runtimeCacheDirectory = Directory(
      path.join(cacheDirectory.path, 'plugin_runtime'),
    );
    final logsDirectory = Directory(path.join(rootDirectory.path, 'logs'));
    final pluginLogsDirectory = Directory(
      path.join(logsDirectory.path, 'plugins'),
    );
    for (final d in <Directory>[
      rootDirectory,
      appDataDirectory,
      pluginsDirectory,
      cacheDirectory,
      runtimeCacheDirectory,
      logsDirectory,
      pluginLogsDirectory,
    ]) {
      await d.create(recursive: true);
    }
    final appPaths = AppPaths(
      rootDirectory: rootDirectory,
      appDataDirectory: appDataDirectory,
      pluginsDirectory: pluginsDirectory,
      cacheDirectory: cacheDirectory,
      pluginRuntimeCacheDirectory: runtimeCacheDirectory,
      logsDirectory: logsDirectory,
      pluginLogsDirectory: pluginLogsDirectory,
      configFilePath: path.join(appDataDirectory.path, 'config.json'),
      pluginMetaFilePath: path.join(appDataDirectory.path, 'plugin_meta.json'),
      subscriptionsFilePath: path.join(
        appDataDirectory.path,
        'subscriptions.json',
      ),
      pluginStorageFilePath: path.join(
        appDataDirectory.path,
        'plugin_storage.json',
      ),
      pluginCookiesFilePath: path.join(
        appDataDirectory.path,
        'plugin_cookies.json',
      ),
    );
    return _RuntimeTestHarness._(tempRoot, appPaths);
  }

  Future<void> dispose() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  }
}
