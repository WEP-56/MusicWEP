import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:flutter_app/core/filesystem/app_paths.dart';
import 'package:flutter_app/core/runtime/internal/plugin_runtime_state_bridge.dart';
import 'package:flutter_app/core/runtime/internal/plugin_runtime_webdav_bridge.dart';

void main() {
  group('plugin runtime state bridges', () {
    test('storage bridge persists values', () async {
      final harness = await _createAppPathsHarness();
      try {
        final bridge = PluginRuntimeStateBridge(harness);
        await bridge.handleStorage(<String, dynamic>{
          'action': 'setItem',
          'key': 'token',
          'value': 'abc',
        });
        final result =
            jsonDecode(
                  await bridge.handleStorage(<String, dynamic>{
                    'action': 'getItem',
                    'key': 'token',
                  }),
                )
                as Map<String, dynamic>;
        expect(result['value'], 'abc');
      } finally {
        await harness.rootDirectory.delete(recursive: true);
      }
    });

    test('cookies bridge stores values by url and cookie name', () async {
      final harness = await _createAppPathsHarness();
      try {
        final bridge = PluginRuntimeStateBridge(harness);
        await bridge.handleCookies(<String, dynamic>{
          'action': 'set',
          'url': 'https://example.com',
          'cookie': <String, dynamic>{'name': 'sid', 'value': '123'},
        });
        final result =
            jsonDecode(
                  await bridge.handleCookies(<String, dynamic>{
                    'action': 'get',
                    'url': 'https://example.com',
                  }),
                )
                as Map<String, dynamic>;
        expect(result['value']['sid']['value'], '123');
      } finally {
        await harness.rootDirectory.delete(recursive: true);
      }
    });

    test(
      'webdav bridge returns download link with embedded credentials',
      () async {
        final bridge = PluginRuntimeWebDavBridge();
        final result =
            jsonDecode(
                  await bridge.handle(<String, dynamic>{
                    'action': 'getFileDownloadLink',
                    'baseUrl': 'https://dav.example.com/music/',
                    'path': '/songs/track.mp3',
                    'username': 'user',
                    'password': 'pass',
                  }),
                )
                as Map<String, dynamic>;

        expect(
          result['value'],
          'https://user:pass@dav.example.com/music/songs/track.mp3',
        );
      },
    );
  });
}

Future<AppPaths> _createAppPathsHarness() async {
  final tempRoot = await Directory.systemTemp.createTemp(
    'musicfree_runtime_state_',
  );
  final rootDirectory = Directory(
    path.join(tempRoot.path, 'musicfree_flutter'),
  );
  final appDataDirectory = Directory(path.join(rootDirectory.path, 'app_data'));
  final pluginsDirectory = Directory(path.join(rootDirectory.path, 'plugins'));
  final cacheDirectory = Directory(path.join(rootDirectory.path, 'cache'));
  final runtimeCacheDirectory = Directory(
    path.join(cacheDirectory.path, 'plugin_runtime'),
  );
  final logsDirectory = Directory(path.join(rootDirectory.path, 'logs'));
  final pluginLogsDirectory = Directory(
    path.join(logsDirectory.path, 'plugins'),
  );

  for (final directory in <Directory>[
    rootDirectory,
    appDataDirectory,
    pluginsDirectory,
    cacheDirectory,
    runtimeCacheDirectory,
    logsDirectory,
    pluginLogsDirectory,
  ]) {
    await directory.create(recursive: true);
  }

  return AppPaths(
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
}
