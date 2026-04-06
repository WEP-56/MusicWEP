import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:flutter_app/core/filesystem/app_paths.dart';
import 'package:flutter_app/core/runtime/plugin_runtime_adapter.dart';
import 'package:flutter_app/core/runtime/plugin_runtime_result.dart';
import 'package:flutter_app/core/storage/json_file_store.dart';
import 'package:flutter_app/features/plugins/application/plugin_manager_service.dart';
import 'package:flutter_app/features/plugins/domain/plugin.dart';
import 'package:flutter_app/features/plugins/domain/plugin_search.dart';
import 'package:flutter_app/features/plugins/infrastructure/plugin_file_repository.dart';
import 'package:flutter_app/features/plugins/infrastructure/plugin_meta_repository.dart';
import 'package:flutter_app/features/plugins/infrastructure/plugin_subscription_repository.dart';

void main() {
  group('PluginManagerService', () {
    test(
      'rejects invalid plugins before writing them into the plugins directory',
      () async {
        final harness = await _createHarness(
          runtime: _FakeRuntime(
            onInspect: ({required script, required sourceUrl}) {
              return PluginRuntimeResult(
                success: false,
                diagnostics: PluginDiagnostics(
                  status: PluginParseStatus.error,
                  checkedAt: DateTime(2026),
                  message: 'Plugin export is missing platform.',
                ),
              );
            },
          ),
        );

        try {
          final sourceFile = File(
            path.join(harness.tempRoot.path, 'broken.js'),
          );
          await sourceFile.writeAsString('module.exports = {};');

          await expectLater(
            harness.service.installFromLocal(sourceFile.path),
            throwsA(isA<Exception>()),
          );

          final files = await harness.fileRepository.listPluginFiles();
          expect(files, isEmpty);
        } finally {
          await harness.dispose();
        }
      },
    );

    test(
      'keeps local installs without a remote update URL when srcUrl is absent',
      () async {
        final harness = await _createHarness(
          runtime: _FakeRuntime(
            onInspect: ({required script, required sourceUrl}) {
              return PluginRuntimeResult(
                success: true,
                manifest: const PluginManifest(
                  platform: 'LocalOnly',
                  version: '1.0.0',
                  supportedMethods: <String>['search'],
                ),
                diagnostics: PluginDiagnostics(
                  status: PluginParseStatus.mounted,
                  checkedAt: DateTime(2026),
                  message: 'Plugin inspected successfully.',
                ),
              );
            },
          ),
        );

        try {
          final sourceFile = File(
            path.join(harness.tempRoot.path, 'local_only.js'),
          );
          await sourceFile.writeAsString('module.exports = {};');

          final snapshot = await harness.service.installFromLocal(
            sourceFile.path,
          );
          expect(snapshot.plugins, hasLength(1));
          expect(snapshot.plugins.single.sourceUrl, isNull);
        } finally {
          await harness.dispose();
        }
      },
    );

    test(
      'installs all plugin URLs referenced by a local subscription json file',
      () async {
        final harness = await _createHarness(
          runtime: _FakeRuntime(
            onInspect: ({required script, required sourceUrl}) {
              final platform = script.contains('plugin_two')
                  ? 'PluginTwo'
                  : 'PluginOne';
              return PluginRuntimeResult(
                success: true,
                manifest: PluginManifest(
                  platform: platform,
                  version: '1.0.0',
                  sourceUrl: sourceUrl,
                  supportedMethods: const <String>['search'],
                ),
                diagnostics: PluginDiagnostics(
                  status: PluginParseStatus.mounted,
                  checkedAt: DateTime(2026),
                  message: 'Plugin inspected successfully.',
                ),
              );
            },
          ),
        );

        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          final body = switch (request.uri.path) {
            '/plugin-one.js' => 'const plugin_one = true;',
            '/plugin-two.js' => 'const plugin_two = true;',
            _ => '',
          };
          request.response.headers.contentType = ContentType.text;
          request.response.write(body);
          await request.response.close();
        });

        try {
          final feedFile = File(path.join(harness.tempRoot.path, 'feed.json'));
          final baseUrl = 'http://${server.address.host}:${server.port}';
          await feedFile.writeAsString('''
{
  "plugins": [
    {"url": "$baseUrl/plugin-one.js"},
    {"url": "$baseUrl/plugin-two.js"}
  ]
}
''');

          final snapshot = await harness.service.installFromLocal(
            feedFile.path,
          );
          expect(snapshot.plugins, hasLength(2));
          expect(snapshot.plugins.map((plugin) => plugin.displayName).toSet(), {
            'PluginOne',
            'PluginTwo',
          });
        } finally {
          await server.close(force: true);
          await harness.dispose();
        }
      },
    );

    test(
      'preserves enabled state and custom order when replacing an installed plugin',
      () async {
        final harness = await _createHarness(
          runtime: _FakeRuntime(
            onInspect: ({required script, required sourceUrl}) {
              final version = script.contains('v2') ? '2.0.0' : '1.0.0';
              return PluginRuntimeResult(
                success: true,
                manifest: PluginManifest(
                  platform: 'ReplaceablePlugin',
                  version: version,
                  supportedMethods: const <String>['search'],
                ),
                diagnostics: PluginDiagnostics(
                  status: PluginParseStatus.mounted,
                  checkedAt: DateTime(2026),
                  message: 'Plugin inspected successfully.',
                ),
              );
            },
          ),
        );

        try {
          final sourceFile = File(
            path.join(harness.tempRoot.path, 'replaceable.js'),
          );
          await sourceFile.writeAsString('const v1 = true;');
          await harness.service.installFromLocal(sourceFile.path);

          await harness.metaRepository.saveAll(<String, PluginMetaRecord>{
            'ReplaceablePlugin': PluginMetaRecord.initial().copyWith(
              enabled: false,
              order: 7,
            ),
          });

          await sourceFile.writeAsString('const v2 = true;');
          final snapshot = await harness.service.installFromLocal(
            sourceFile.path,
          );
          final plugin = snapshot.plugins.single;

          expect(plugin.version, '2.0.0');
          expect(plugin.meta.enabled, isFalse);
          expect(plugin.meta.order, 7);
        } finally {
          await harness.dispose();
        }
      },
    );

    test('searches only enabled plugins that export search', () async {
      final harness = await _createHarness(
        runtime: _FakeRuntime(
          onInspect: ({required script, required sourceUrl}) {
            if (script.contains('disabled')) {
              return PluginRuntimeResult(
                success: true,
                manifest: const PluginManifest(
                  platform: 'DisabledPlugin',
                  version: '1.0.0',
                  supportedMethods: <String>['search'],
                ),
                diagnostics: PluginDiagnostics(
                  status: PluginParseStatus.mounted,
                  checkedAt: DateTime(2026),
                  message: 'ok',
                ),
              );
            }
            if (script.contains('no_search')) {
              return PluginRuntimeResult(
                success: true,
                manifest: const PluginManifest(
                  platform: 'NoSearchPlugin',
                  version: '1.0.0',
                  supportedMethods: <String>['getLyric'],
                ),
                diagnostics: PluginDiagnostics(
                  status: PluginParseStatus.mounted,
                  checkedAt: DateTime(2026),
                  message: 'ok',
                ),
              );
            }
            return PluginRuntimeResult(
              success: true,
              manifest: const PluginManifest(
                platform: 'SearchPlugin',
                version: '1.0.0',
                supportedMethods: <String>['search'],
              ),
              diagnostics: PluginDiagnostics(
                status: PluginParseStatus.mounted,
                checkedAt: DateTime(2026),
                message: 'ok',
              ),
            );
          },
          onInvoke:
              ({
                required script,
                required sourceUrl,
                required method,
                required arguments,
              }) {
                return PluginMethodCallResult(
                  success: true,
                  data: <String, dynamic>{
                    'isEnd': true,
                    'data': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'title': arguments.first,
                        'artist': 'Plugin Artist',
                      },
                    ],
                  },
                  logs: const <String>[],
                  requiredPackages: const <String>['axios'],
                  missingPackages: const <String>[],
                );
              },
        ),
      );

      try {
        final enabledFile = File(
          path.join(harness.tempRoot.path, 'enabled.js'),
        );
        await enabledFile.writeAsString('const enabled = true;');
        final disabledFile = File(
          path.join(harness.tempRoot.path, 'disabled.js'),
        );
        await disabledFile.writeAsString('const disabled = true;');
        final noSearchFile = File(
          path.join(harness.tempRoot.path, 'no_search.js'),
        );
        await noSearchFile.writeAsString('const no_search = true;');

        await harness.service.installFromLocal(enabledFile.path);
        await harness.service.installFromLocal(disabledFile.path);
        await harness.service.installFromLocal(noSearchFile.path);

        await harness.metaRepository.saveAll(<String, PluginMetaRecord>{
          'SearchPlugin': PluginMetaRecord.initial().copyWith(enabled: true),
          'DisabledPlugin': PluginMetaRecord.initial().copyWith(enabled: false),
          'NoSearchPlugin': PluginMetaRecord.initial().copyWith(enabled: true),
        });

        final results = await harness.service.searchAllEnabled(
          query: 'hello',
          type: PluginSearchType.music,
        );

        expect(results, hasLength(1));
        expect(results.single.plugin.displayName, 'SearchPlugin');
        expect(results.single.items.single.title, 'hello');
      } finally {
        await harness.dispose();
      }
    });

    test(
      'preserves supported search types exposed by inspected plugins',
      () async {
        final harness = await _createHarness(
          runtime: _FakeRuntime(
            onInspect: ({required script, required sourceUrl}) {
              return PluginRuntimeResult(
                success: true,
                manifest: const PluginManifest(
                  platform: 'TypedSearchPlugin',
                  version: '1.0.0',
                  supportedMethods: <String>['search'],
                  supportedSearchTypes: <String>['music', 'artist'],
                ),
                diagnostics: PluginDiagnostics(
                  status: PluginParseStatus.mounted,
                  checkedAt: DateTime(2026),
                  message: 'ok',
                ),
              );
            },
          ),
        );

        try {
          final sourceFile = File(
            path.join(harness.tempRoot.path, 'typed_search.js'),
          );
          await sourceFile.writeAsString('const typed = true;');

          final snapshot = await harness.service.installFromLocal(
            sourceFile.path,
          );

          expect(
            snapshot.plugins.single.manifest?.supportedSearchTypes,
            <String>['music', 'artist'],
          );
        } finally {
          await harness.dispose();
        }
      },
    );
  });
}

class _FakeRuntime implements PluginRuntimeAdapter {
  _FakeRuntime({required this.onInspect, this.onInvoke});

  final PluginRuntimeResult Function({
    required String script,
    required String sourceUrl,
  })
  onInspect;
  final PluginMethodCallResult Function({
    required String script,
    required String sourceUrl,
    required String method,
    required List<dynamic> arguments,
  })?
  onInvoke;

  @override
  Future<PluginRuntimeResult> inspectPlugin({
    required String script,
    required String sourceUrl,
    required String appVersion,
    required String os,
    required String language,
    Map<String, String> userVariables = const <String, String>{},
  }) async {
    return onInspect(script: script, sourceUrl: sourceUrl);
  }

  @override
  Future<PluginMethodCallResult> invokeMethod({
    required String script,
    required String sourceUrl,
    required String appVersion,
    required String os,
    required String language,
    required String method,
    List<dynamic> arguments = const <dynamic>[],
    Map<String, String> userVariables = const <String, String>{},
  }) async {
    if (onInvoke == null) {
      return const PluginMethodCallResult(
        success: false,
        errorMessage: 'invoke not configured',
        logs: <String>[],
        requiredPackages: <String>[],
        missingPackages: <String>[],
      );
    }
    return onInvoke!(
      script: script,
      sourceUrl: sourceUrl,
      method: method,
      arguments: arguments,
    );
  }

  @override
  void dispose() {}
}

class _Harness {
  const _Harness({
    required this.tempRoot,
    required this.fileRepository,
    required this.metaRepository,
    required this.service,
  });

  final Directory tempRoot;
  final PluginFileRepository fileRepository;
  final PluginMetaRepository metaRepository;
  final PluginManagerService service;

  Future<void> dispose() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  }
}

Future<_Harness> _createHarness({required PluginRuntimeAdapter runtime}) async {
  final tempRoot = await Directory.systemTemp.createTemp(
    'musicfree_plugin_test_',
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

  final fileRepository = PluginFileRepository(appPaths);
  final metaRepository = PluginMetaRepository(
    JsonFileStore(appPaths.pluginMetaFilePath),
  );

  final service = PluginManagerService(
    fileRepository: fileRepository,
    metaRepository: metaRepository,
    subscriptionRepository: PluginSubscriptionRepository(
      JsonFileStore(appPaths.subscriptionsFilePath),
    ),
    runtime: runtime,
    appVersion: '0.1.0',
  );

  return _Harness(
    tempRoot: tempRoot,
    fileRepository: fileRepository,
    metaRepository: metaRepository,
    service: service,
  );
}
