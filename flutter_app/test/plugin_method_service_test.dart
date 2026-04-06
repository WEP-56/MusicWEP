import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:flutter_app/core/media/media_models.dart';
import 'package:flutter_app/core/filesystem/app_paths.dart';
import 'package:flutter_app/core/runtime/plugin_runtime_adapter.dart';
import 'package:flutter_app/core/runtime/plugin_runtime_result.dart';
import 'package:flutter_app/core/storage/json_file_store.dart';
import 'package:flutter_app/features/plugins/application/plugin_manager_service.dart';
import 'package:flutter_app/features/plugins/application/plugin_method_service.dart';
import 'package:flutter_app/features/plugins/domain/internal_plugins.dart';
import 'package:flutter_app/features/plugins/domain/plugin.dart';
import 'package:flutter_app/features/plugins/domain/plugin_search.dart';
import 'package:flutter_app/features/plugins/infrastructure/plugin_file_repository.dart';
import 'package:flutter_app/features/plugins/infrastructure/plugin_meta_repository.dart';
import 'package:flutter_app/features/plugins/infrastructure/plugin_subscription_repository.dart';

void main() {
  group('PluginMethodService', () {
    test(
      'local plugin imports a single file and reads sibling lyric files',
      () async {
        final tempRoot = await Directory.systemTemp.createTemp(
          'musicfree_local_plugin_',
        );
        try {
          final methodService = PluginMethodService(_NoopManagerService());
          final plugin = buildLocalPluginRecord();
          final musicFile = File(path.join(tempRoot.path, 'track.mp3'));
          final lyricFile = File(path.join(tempRoot.path, 'track.lrc'));
          final translationFile = File(
            path.join(tempRoot.path, 'track-tr.lrc'),
          );
          await musicFile.writeAsString('audio');
          await lyricFile.writeAsString('[00:00.00]line');
          await translationFile.writeAsString('[00:00.00]translated');

          final item = await methodService.importMusicItem(
            plugin: plugin,
            urlLike: musicFile.path,
          );
          final lyric = await methodService.getLyric(
            plugin: plugin,
            musicItem: item!,
          );

          expect(item.platform, '本地');
          expect(item.title, 'track');
          expect(lyric?.rawLyric, '[00:00.00]line');
          expect(lyric?.translation, '[00:00.00]translated');
        } finally {
          await tempRoot.delete(recursive: true);
        }
      },
    );

    test(
      'local plugin imports only supported media files from a folder',
      () async {
        final tempRoot = await Directory.systemTemp.createTemp(
          'musicfree_local_sheet_',
        );
        try {
          final methodService = PluginMethodService(_NoopManagerService());
          final plugin = buildLocalPluginRecord();
          await File(path.join(tempRoot.path, 'a.mp3')).writeAsString('a');
          await File(path.join(tempRoot.path, 'b.flac')).writeAsString('b');
          await File(
            path.join(tempRoot.path, 'notes.txt'),
          ).writeAsString('skip');

          final items = await methodService.importMusicSheet(
            plugin: plugin,
            urlLike: tempRoot.path,
          );

          expect(items, hasLength(2));
          expect(items.map((item) => item.title).toSet(), {'a', 'b'});
        } finally {
          await tempRoot.delete(recursive: true);
        }
      },
    );

    test('delegates getMediaSource to runtime-backed plugins', () async {
      final harness = await _createHarness(
        runtime: _FakeRuntime(
          onInspect: ({required script, required sourceUrl}) {
            return PluginRuntimeResult(
              success: true,
              manifest: const PluginManifest(
                platform: 'RemotePlugin',
                supportedMethods: <String>['getMediaSource'],
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
                return const PluginMethodCallResult(
                  success: true,
                  data: <String, dynamic>{
                    'url': 'https://cdn.example.com/audio.mp3',
                    'headers': <String, String>{'user-agent': 'MusicFree'},
                  },
                  logs: <String>[],
                  requiredPackages: <String>[],
                  missingPackages: <String>[],
                );
              },
        ),
      );

      try {
        final sourceFile = File(path.join(harness.tempRoot.path, 'remote.js'));
        await sourceFile.writeAsString('const getMediaSource = true;');
        final snapshot = await harness.service.installFromLocal(
          sourceFile.path,
        );
        final plugin = snapshot.plugins.single;
        final methodService = PluginMethodService(harness.service);

        final result = await methodService.getMediaSource(
          plugin: plugin,
          musicItem: const MusicItem(
            platform: 'RemotePlugin',
            id: '1',
            title: 'Track',
            artist: 'Artist',
            url: 'https://fallback.example.com/a.mp3',
          ),
        );

        expect(result?.url, 'https://cdn.example.com/audio.mp3');
        expect(result?.userAgent, 'MusicFree');
      } finally {
        await harness.dispose();
      }
    });

    test('throws detailed getMediaSource errors when requested', () async {
      final harness = await _createHarness(
        runtime: _FakeRuntime(
          onInspect: ({required script, required sourceUrl}) {
            return PluginRuntimeResult(
              success: true,
              manifest: const PluginManifest(
                platform: 'RemotePlugin',
                supportedMethods: <String>['getMediaSource'],
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
                return const PluginMethodCallResult(
                  success: false,
                  errorMessage: 'remote rejected request',
                  logs: <String>['request id=abc123'],
                  requiredPackages: <String>[],
                  missingPackages: <String>[],
                );
              },
        ),
      );

      try {
        final sourceFile = File(
          path.join(harness.tempRoot.path, 'remote_error.js'),
        );
        await sourceFile.writeAsString('const getMediaSource = true;');
        final snapshot = await harness.service.installFromLocal(
          sourceFile.path,
        );
        final plugin = snapshot.plugins.single;
        final methodService = PluginMethodService(harness.service);

        expect(
          () => methodService.getMediaSource(
            plugin: plugin,
            musicItem: const MusicItem(
              platform: 'RemotePlugin',
              id: '1',
              title: 'Track',
              artist: 'Artist',
            ),
            throwOnFailure: true,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              allOf(
                contains('failed to resolve media source'),
                contains('remote rejected request'),
                contains('request id=abc123'),
              ),
            ),
          ),
        );
      } finally {
        await harness.dispose();
      }
    });

    test(
      'falls back to lower quality when requested quality returns empty url',
      () async {
        final harness = await _createHarness(
          runtime: _FakeRuntime(
            onInspect: ({required script, required sourceUrl}) {
              return PluginRuntimeResult(
                success: true,
                manifest: const PluginManifest(
                  platform: 'RemotePlugin',
                  supportedMethods: <String>['getMediaSource'],
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
                  final quality = arguments[1]?.toString();
                  if (quality == 'standard') {
                    return const PluginMethodCallResult(
                      success: true,
                      data: <String, dynamic>{'url': ''},
                      logs: <String>[],
                      requiredPackages: <String>[],
                      missingPackages: <String>[],
                    );
                  }
                  return const PluginMethodCallResult(
                    success: true,
                    data: <String, dynamic>{
                      'url': 'https://cdn.example.com/audio-low.mp3',
                    },
                    logs: <String>[],
                    requiredPackages: <String>[],
                    missingPackages: <String>[],
                  );
                },
          ),
        );

        try {
          final sourceFile = File(
            path.join(harness.tempRoot.path, 'remote_fallback.js'),
          );
          await sourceFile.writeAsString('const getMediaSource = true;');
          final snapshot = await harness.service.installFromLocal(
            sourceFile.path,
          );
          final plugin = snapshot.plugins.single;
          final methodService = PluginMethodService(harness.service);

          final result = await methodService.getMediaSource(
            plugin: plugin,
            musicItem: const MusicItem(
              platform: 'RemotePlugin',
              id: '1',
              title: 'Track',
              artist: 'Artist',
            ),
          );

          expect(result?.url, 'https://cdn.example.com/audio-low.mp3');
          expect(result?.quality, 'low');
        } finally {
          await harness.dispose();
        }
      },
    );

    test(
      'returns typed media structures for detail, recommend, and comment methods',
      () async {
        final harness = await _createHarness(
          runtime: _FakeRuntime(
            onInspect: ({required script, required sourceUrl}) {
              return PluginRuntimeResult(
                success: true,
                manifest: const PluginManifest(
                  platform: 'RemotePlugin',
                  supportedMethods: <String>[
                    'getMusicInfo',
                    'getAlbumInfo',
                    'getMusicSheetInfo',
                    'getArtistWorks',
                    'getTopLists',
                    'getTopListDetail',
                    'getRecommendSheetTags',
                    'getRecommendSheetsByTag',
                    'getMusicComments',
                  ],
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
                  final data = switch (method) {
                    'getMusicInfo' => <String, dynamic>{
                      'album': 'Patched Album',
                      'duration': 245,
                    },
                    'getAlbumInfo' => <String, dynamic>{
                      'isEnd': false,
                      'albumItem': <String, dynamic>{
                        'description': 'Album Desc',
                      },
                      'musicList': <Map<String, dynamic>>[
                        <String, dynamic>{
                          'platform': 'RemotePlugin',
                          'id': 'm1',
                          'title': 'Album Track',
                          'artist': 'Singer',
                        },
                      ],
                    },
                    'getMusicSheetInfo' => <String, dynamic>{
                      'isEnd': true,
                      'sheetItem': <String, dynamic>{
                        'description': 'Sheet Desc',
                      },
                      'musicList': <Map<String, dynamic>>[
                        <String, dynamic>{
                          'platform': 'RemotePlugin',
                          'id': 'm2',
                          'title': 'Sheet Track',
                          'artist': 'Singer',
                        },
                      ],
                    },
                    'getArtistWorks' => <String, dynamic>{
                      'isEnd': true,
                      'data': <Map<String, dynamic>>[
                        <String, dynamic>{
                          'platform': 'RemotePlugin',
                          'id': 'a1',
                          'title': 'Artist Album',
                          'artist': 'Singer',
                          'description': 'desc',
                        },
                      ],
                    },
                    'getTopLists' => <Map<String, dynamic>>[
                      <String, dynamic>{
                        'title': 'Hot',
                        'data': <Map<String, dynamic>>[
                          <String, dynamic>{
                            'platform': 'RemotePlugin',
                            'id': 's1',
                            'title': 'Top Sheet',
                          },
                        ],
                      },
                    ],
                    'getTopListDetail' => <String, dynamic>{
                      'isEnd': true,
                      'musicList': <Map<String, dynamic>>[
                        <String, dynamic>{
                          'platform': 'RemotePlugin',
                          'id': 'm3',
                          'title': 'Top Track',
                          'artist': 'Singer',
                        },
                      ],
                    },
                    'getRecommendSheetTags' => <String, dynamic>{
                      'pinned': <Map<String, dynamic>>[
                        <String, dynamic>{
                          'platform': 'RemotePlugin',
                          'id': 's2',
                          'title': 'Pinned Sheet',
                        },
                      ],
                      'data': <Map<String, dynamic>>[
                        <String, dynamic>{
                          'title': 'Mood',
                          'data': <Map<String, dynamic>>[
                            <String, dynamic>{
                              'platform': 'RemotePlugin',
                              'id': 's3',
                              'title': 'Tagged Sheet',
                            },
                          ],
                        },
                      ],
                    },
                    'getRecommendSheetsByTag' => <String, dynamic>{
                      'isEnd': false,
                      'data': <Map<String, dynamic>>[
                        <String, dynamic>{
                          'platform': 'RemotePlugin',
                          'id': 's4',
                          'title': 'Recommend Sheet',
                        },
                      ],
                    },
                    'getMusicComments' => <String, dynamic>{
                      'isEnd': true,
                      'data': <Map<String, dynamic>>[
                        <String, dynamic>{
                          'nickName': 'UserA',
                          'comment': 'Great song',
                          'replies': <Map<String, dynamic>>[
                            <String, dynamic>{
                              'nickName': 'UserB',
                              'comment': 'Indeed',
                            },
                          ],
                        },
                      ],
                    },
                    _ => <String, dynamic>{},
                  };

                  return PluginMethodCallResult(
                    success: true,
                    data: data,
                    logs: const <String>[],
                    requiredPackages: const <String>[],
                    missingPackages: const <String>[],
                  );
                },
          ),
        );

        try {
          final sourceFile = File(
            path.join(harness.tempRoot.path, 'remote_methods.js'),
          );
          await sourceFile.writeAsString('const methods = true;');
          final snapshot = await harness.service.installFromLocal(
            sourceFile.path,
          );
          final plugin = snapshot.plugins.single;
          final methodService = PluginMethodService(harness.service);

          final patch = await methodService.getMusicInfo(
            plugin: plugin,
            mediaItem: const MusicItem(
              platform: 'RemotePlugin',
              id: 'm0',
              title: 'Base',
              artist: 'Singer',
            ),
          );
          final albumInfo = await methodService.getAlbumInfo(
            plugin: plugin,
            albumItem: const AlbumItem(
              platform: 'RemotePlugin',
              id: 'al1',
              title: 'Album',
              artist: 'Singer',
            ),
          );
          final sheetInfo = await methodService.getMusicSheetInfo(
            plugin: plugin,
            sheetItem: const MusicSheetItem(
              platform: 'RemotePlugin',
              id: 'sh1',
              title: 'Sheet',
            ),
          );
          final artistWorks = await methodService.getArtistWorks(
            plugin: plugin,
            artistItem: const ArtistItem(
              platform: 'RemotePlugin',
              id: 'ar1',
              name: 'Singer',
            ),
            type: PluginSearchType.album,
          );
          final topLists = await methodService.getTopLists(plugin: plugin);
          final topDetail = await methodService.getTopListDetail(
            plugin: plugin,
            topListItem: const MusicSheetItem(
              platform: 'RemotePlugin',
              id: 's1',
              title: 'Top Sheet',
            ),
          );
          final recommendTags = await methodService.getRecommendSheetTags(
            plugin: plugin,
          );
          final recommendSheets = await methodService.getRecommendSheetsByTag(
            plugin: plugin,
            tag: const MediaTag(id: 'mood', name: 'Mood'),
          );
          final comments = await methodService.getMusicComments(
            plugin: plugin,
            musicItem: const MusicItem(
              platform: 'RemotePlugin',
              id: 'm0',
              title: 'Base',
              artist: 'Singer',
            ),
          );

          expect(patch?.album, 'Patched Album');
          expect(albumInfo?.musicList.single.title, 'Album Track');
          expect(albumInfo?.albumItem?.description, 'Album Desc');
          expect(sheetInfo?.sheetItem?.description, 'Sheet Desc');
          expect(sheetInfo?.musicList.single.title, 'Sheet Track');
          expect(artistWorks.items.single, isA<AlbumItem>());
          expect((artistWorks.items.single as AlbumItem).title, 'Artist Album');
          expect(topLists.single.title, 'Hot');
          expect(topLists.single.data.single.title, 'Top Sheet');
          expect(topDetail.musicList.single.title, 'Top Track');
          expect(recommendTags.pinned.single.title, 'Pinned Sheet');
          expect(recommendTags.data.single.data.single.title, 'Tagged Sheet');
          expect(recommendSheets.isEnd, isFalse);
          expect(recommendSheets.data.single.title, 'Recommend Sheet');
          expect(comments.data.single.nickName, 'UserA');
          expect(comments.data.single.replies.single.comment, 'Indeed');
        } finally {
          await harness.dispose();
        }
      },
    );
  });
}

class _NoopManagerService extends PluginManagerService {
  _NoopManagerService()
    : super(
        fileRepository: PluginFileRepository(
          AppPaths(
            rootDirectory: Directory.systemTemp,
            appDataDirectory: Directory.systemTemp,
            pluginsDirectory: Directory.systemTemp,
            cacheDirectory: Directory.systemTemp,
            pluginRuntimeCacheDirectory: Directory.systemTemp,
            logsDirectory: Directory.systemTemp,
            pluginLogsDirectory: Directory.systemTemp,
            configFilePath: '',
            pluginMetaFilePath: '',
            subscriptionsFilePath: '',
            pluginStorageFilePath: '',
            pluginCookiesFilePath: '',
          ),
        ),
        metaRepository: PluginMetaRepository(JsonFileStore('')),
        subscriptionRepository: PluginSubscriptionRepository(JsonFileStore('')),
        runtime: _FakeRuntime(
          onInspect: ({required script, required sourceUrl}) {
            throw UnimplementedError();
          },
        ),
        appVersion: '0.1.0',
      );
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
  const _Harness({required this.tempRoot, required this.service});

  final Directory tempRoot;
  final PluginManagerService service;

  Future<void> dispose() async {
    if (await tempRoot.exists()) {
      for (var attempt = 0; attempt < 5; attempt++) {
        try {
          await tempRoot.delete(recursive: true);
          return;
        } on FileSystemException {
          if (attempt == 4) {
            rethrow;
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    }
  }
}

Future<_Harness> _createHarness({required PluginRuntimeAdapter runtime}) async {
  final tempRoot = await Directory.systemTemp.createTemp(
    'musicfree_plugin_method_',
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

  final service = PluginManagerService(
    fileRepository: PluginFileRepository(appPaths),
    metaRepository: PluginMetaRepository(
      JsonFileStore(appPaths.pluginMetaFilePath),
    ),
    subscriptionRepository: PluginSubscriptionRepository(
      JsonFileStore(appPaths.subscriptionsFilePath),
    ),
    runtime: runtime,
    appVersion: '0.1.0',
  );

  return _Harness(tempRoot: tempRoot, service: service);
}
