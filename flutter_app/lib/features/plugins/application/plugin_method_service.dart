import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/media/media_constants.dart';
import '../../../core/media/media_models.dart';
import '../../../core/media/media_utils.dart';
import '../domain/plugin.dart';
import '../domain/plugin_method_models.dart';
import '../domain/plugin_search.dart';
import 'local_plugin_service.dart';
import 'plugin_manager_service.dart';

class PluginMethodService {
  const PluginMethodService(this._pluginManagerService)
    : _localPluginService = const LocalPluginService();

  final PluginManagerService _pluginManagerService;
  final LocalPluginService _localPluginService;

  Future<List<PluginSearchResult>> searchAllEnabled({
    required String query,
    required PluginSearchType type,
    int page = 1,
  }) async {
    final results = await _pluginManagerService.searchAllEnabled(
      query: query,
      type: type,
      page: page,
    );

    return results
        .map(
          (result) => PluginSearchResult(
            plugin: result.plugin,
            items: result.items
                .map(
                  (item) => PluginSearchResultItem(
                    media: _parseMediaByType(
                      type.mediaType,
                      resetMediaItem(
                        item.toJson(),
                        platform: result.plugin.manifest?.platform,
                        clone: true,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
            logs: result.logs,
            requiredPackages: result.requiredPackages,
            missingPackages: result.missingPackages,
            isEnd: result.isEnd,
            errorMessage: result.errorMessage,
          ),
        )
        .toList(growable: false);
  }

  Future<PluginSearchResult?> searchSinglePlugin({
    required PluginRecord plugin,
    required String query,
    required PluginSearchType type,
    int page = 1,
  }) async {
    final result = await _pluginManagerService.searchPlugin(
      plugin: plugin,
      query: query,
      type: type,
      page: page,
    );
    return PluginSearchResult(
      plugin: result.plugin,
      items: result.items
          .map(
            (item) => PluginSearchResultItem(
              media: _parseMediaByType(
                type.mediaType,
                resetMediaItem(
                  item.toJson(),
                  platform: result.plugin.manifest?.platform,
                  clone: true,
                ),
              ),
            ),
          )
          .toList(growable: false),
      logs: result.logs,
      requiredPackages: result.requiredPackages,
      missingPackages: result.missingPackages,
      isEnd: result.isEnd,
      errorMessage: result.errorMessage,
    );
  }

  Future<PluginMediaSourceResult?> getMediaSource({
    required PluginRecord plugin,
    required MusicItem musicItem,
    String quality = 'standard',
    int retryCount = 1,
    bool throwOnFailure = false,
  }) async {
    if (_isLocalPlugin(plugin)) {
      return _localPluginService.getMediaSource(musicItem, quality: quality);
    }

    Object? lastError;
    StackTrace? lastStackTrace;
    final attemptedQualities = _buildQualityFallbackOrder(
      requestedQuality: quality,
    );
    final failureMessages = <String>[];

    for (final candidateQuality in attemptedQualities) {
      for (var attempt = 0; attempt <= retryCount; attempt++) {
        try {
          final invocation = await _pluginManagerService.invokePluginMethod(
            plugin,
            method: 'getMediaSource',
            arguments: <dynamic>[musicItem.toJson(), candidateQuality],
          );
          if (!invocation.success) {
            throw StateError(
              _buildMediaSourceAttemptMessage(
                plugin: plugin,
                musicItem: musicItem,
                quality: candidateQuality,
                message: invocation.errorMessage ?? 'getMediaSource failed.',
                logs: invocation.logs,
              ),
            );
          }

          final payload = _readMediaSourcePayload(invocation.data);
          final url =
              payload['url']?.toString() ??
              musicItem.qualities[candidateQuality]?['url']?.toString() ??
              musicItem.url;
          if (url == null || url.isEmpty) {
            final message =
                payload['msg']?.toString() ??
                payload['message']?.toString() ??
                payload['error']?.toString();
            throw StateError(
              'Plugin ${plugin.displayName} returned an empty media source for '
              '"${musicItem.title}" [$candidateQuality]'
              '${message == null || message.isEmpty ? '' : ': $message'}.',
            );
          }

          final headers = _readStringMap(payload['headers']);
          return PluginMediaSourceResult(
            url: url,
            headers: headers,
            userAgent: _readUserAgent(headers),
            quality: qualityKeys.contains(candidateQuality)
                ? candidateQuality
                : null,
          );
        } catch (error, stackTrace) {
          lastError = error;
          lastStackTrace = stackTrace;
          final message = error.toString();
          if (!failureMessages.contains(message)) {
            failureMessages.add(message);
          }
        }
      }
    }

    if (throwOnFailure && lastError != null && lastStackTrace != null) {
      Error.throwWithStackTrace(
        StateError(
          _buildMediaSourceFailureSummary(
            plugin: plugin,
            musicItem: musicItem,
            attemptedQualities: attemptedQualities,
            failureMessages: failureMessages,
          ),
        ),
        lastStackTrace,
      );
    }
    return null;
  }

  Future<MusicInfoPatch?> getMusicInfo({
    required PluginRecord plugin,
    required MediaItem mediaItem,
  }) async {
    if (_isLocalPlugin(plugin)) {
      return null;
    }

    try {
      final invocation = await _pluginManagerService.invokePluginMethod(
        plugin,
        method: 'getMusicInfo',
        arguments: <dynamic>[resetMediaItem(mediaItem.toJson(), clone: true)],
      );
      if (!invocation.success || invocation.data == null) {
        return null;
      }
      final patch = MusicInfoPatch.fromJson(_readObject(invocation.data));
      return patch.isEmpty ? null : patch;
    } catch (_) {
      return null;
    }
  }

  Future<PluginLyricResult?> getLyric({
    required PluginRecord plugin,
    required MusicItem musicItem,
  }) async {
    if (_isLocalPlugin(plugin)) {
      return _localPluginService.getLyric(musicItem);
    }

    if (musicItem.rawLyric?.isNotEmpty == true) {
      return PluginLyricResult(
        lyricUrl: musicItem.lyricUrl,
        rawLyric: musicItem.rawLyric,
      );
    }

    final localLyric = await _localPluginService.getLyric(musicItem);
    if (localLyric?.hasContent ?? false) {
      return localLyric;
    }

    try {
      final invocation = await _pluginManagerService.invokePluginMethod(
        plugin,
        method: 'getLyric',
        arguments: <dynamic>[resetMediaItem(musicItem.toJson(), clone: true)],
      );
      if (invocation.success) {
        final payload = _readObject(invocation.data);
        final pluginLyric = PluginLyricResult(
          lyricUrl: payload['lrc']?.toString() ?? musicItem.lyricUrl,
          rawLyric: payload['rawLrc']?.toString(),
          translation: payload['translation']?.toString(),
        );
        if (pluginLyric.hasContent) {
          return pluginLyric.rawLyric?.isNotEmpty == true
              ? pluginLyric
              : PluginLyricResult(rawLyric: pluginLyric.translation);
        }
      }
    } catch (_) {
      // align with legacy behavior and continue to URL fetch
    }

    if (musicItem.lyricUrl == null || musicItem.lyricUrl!.isEmpty) {
      return null;
    }

    final response = await http.get(Uri.parse(musicItem.lyricUrl!));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    return PluginLyricResult(
      lyricUrl: musicItem.lyricUrl,
      rawLyric: response.body,
      translation: localLyric?.translation,
    );
  }

  Future<PluginAlbumInfoResult?> getAlbumInfo({
    required PluginRecord plugin,
    required AlbumItem albumItem,
    int page = 1,
  }) async {
    if (_supports(plugin, 'getAlbumInfo')) {
      try {
        final invocation = await _pluginManagerService.invokePluginMethod(
          plugin,
          method: 'getAlbumInfo',
          arguments: <dynamic>[
            resetMediaItem(albumItem.toJson(), clone: true),
            page,
          ],
        );
        if (invocation.success) {
          final payload = _readObject(invocation.data);
          final musicList = _readMusicItems(
            payload['musicList'],
            platform: plugin.manifest?.platform,
            albumTitle: albumItem.title,
          );
          final mergedAlbum = page <= 1 && payload['albumItem'] != null
              ? AlbumItem.fromJson(<String, dynamic>{
                  ...albumItem.toJson(),
                  ...resetMediaItem(
                    _readObject(payload['albumItem']),
                    platform: plugin.manifest?.platform,
                    clone: true,
                  ),
                })
              : (page <= 1 ? albumItem : null);
          return PluginAlbumInfoResult(
            isEnd: payload['isEnd'] as bool? ?? true,
            albumItem: mergedAlbum,
            musicList: musicList,
          );
        }
      } catch (_) {
        return null;
      }
      return null;
    }

    return PluginAlbumInfoResult(
      isEnd: true,
      albumItem: albumItem,
      musicList: albumItem.musicList,
    );
  }

  Future<PluginMusicSheetInfoResult?> getMusicSheetInfo({
    required PluginRecord plugin,
    required MusicSheetItem sheetItem,
    int page = 1,
  }) async {
    if (_supports(plugin, 'getMusicSheetInfo')) {
      try {
        final invocation = await _pluginManagerService.invokePluginMethod(
          plugin,
          method: 'getMusicSheetInfo',
          arguments: <dynamic>[
            resetMediaItem(sheetItem.toJson(), clone: true),
            page,
          ],
        );
        if (invocation.success) {
          final payload = _readObject(invocation.data);
          final musicList = _readMusicItems(
            payload['musicList'],
            platform: plugin.manifest?.platform,
          );
          final mergedSheet = page <= 1 && payload['sheetItem'] != null
              ? MusicSheetItem.fromJson(<String, dynamic>{
                  ...sheetItem.toJson(),
                  ...resetMediaItem(
                    _readObject(payload['sheetItem']),
                    platform: plugin.manifest?.platform,
                    clone: true,
                  ),
                })
              : (page <= 1 ? sheetItem : null);
          return PluginMusicSheetInfoResult(
            isEnd: payload['isEnd'] as bool? ?? true,
            sheetItem: mergedSheet,
            musicList: musicList,
          );
        }
      } catch (_) {
        return null;
      }
      return null;
    }

    return PluginMusicSheetInfoResult(
      isEnd: true,
      sheetItem: sheetItem,
      musicList: sheetItem.musicList,
    );
  }

  Future<PluginArtistWorksResult> getArtistWorks({
    required PluginRecord plugin,
    required ArtistItem artistItem,
    required PluginSearchType type,
    int page = 1,
  }) async {
    if (!_supports(plugin, 'getArtistWorks')) {
      return PluginArtistWorksResult(
        isEnd: true,
        items: const <MediaItem>[],
        type: type.mediaType,
      );
    }

    try {
      final invocation = await _pluginManagerService.invokePluginMethod(
        plugin,
        method: 'getArtistWorks',
        arguments: <dynamic>[artistItem.toJson(), page, type.value],
      );
      if (!invocation.success) {
        throw Exception(invocation.errorMessage ?? 'getArtistWorks failed.');
      }
      final payload = _readObject(invocation.data);
      final rawItems = payload['data'] as List<dynamic>? ?? const <dynamic>[];
      return PluginArtistWorksResult(
        isEnd: payload['isEnd'] as bool? ?? true,
        items: rawItems
            .whereType<Map>()
            .map(
              (item) => _parseMediaByType(
                type.mediaType,
                resetMediaItem(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                  platform: plugin.manifest?.platform,
                  clone: true,
                ),
              ),
            )
            .toList(growable: false),
        type: type.mediaType,
      );
    } catch (_) {
      return PluginArtistWorksResult(
        isEnd: true,
        items: const <MediaItem>[],
        type: type.mediaType,
      );
    }
  }

  Future<MusicItem?> importMusicItem({
    required PluginRecord plugin,
    required String urlLike,
  }) async {
    if (_isLocalPlugin(plugin)) {
      return _localPluginService.importMusicItem(urlLike);
    }

    try {
      final invocation = await _pluginManagerService.invokePluginMethod(
        plugin,
        method: 'importMusicItem',
        arguments: <dynamic>[urlLike],
      );
      if (!invocation.success || invocation.data == null) {
        return null;
      }
      return MusicItem.fromJson(
        resetMediaItem(
          _readObject(invocation.data),
          platform: plugin.manifest?.platform,
          clone: true,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<MusicItem>> importMusicSheet({
    required PluginRecord plugin,
    required String urlLike,
  }) async {
    if (_isLocalPlugin(plugin)) {
      return _localPluginService.importMusicSheet(urlLike);
    }

    try {
      final invocation = await _pluginManagerService.invokePluginMethod(
        plugin,
        method: 'importMusicSheet',
        arguments: <dynamic>[urlLike],
      );
      if (!invocation.success || invocation.data is! List) {
        return const <MusicItem>[];
      }
      return _readMusicItems(
        invocation.data,
        platform: plugin.manifest?.platform,
      );
    } catch (_) {
      return const <MusicItem>[];
    }
  }

  Future<List<MusicSheetGroup>> getTopLists({
    required PluginRecord plugin,
  }) async {
    if (!_supports(plugin, 'getTopLists')) {
      return const <MusicSheetGroup>[];
    }

    try {
      final invocation = await _pluginManagerService.invokePluginMethod(
        plugin,
        method: 'getTopLists',
      );
      if (!invocation.success || invocation.data is! List) {
        return const <MusicSheetGroup>[];
      }
      return (invocation.data as List<dynamic>)
          .whereType<Map>()
          .map(
            (item) => MusicSheetGroup(
              title: item['title']?.toString(),
              data: _readMusicSheetItems(
                item['data'],
                platform: plugin.manifest?.platform,
              ),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <MusicSheetGroup>[];
    }
  }

  Future<PluginTopListDetailResult> getTopListDetail({
    required PluginRecord plugin,
    required MusicSheetItem topListItem,
    int page = 1,
  }) async {
    if (!_supports(plugin, 'getTopListDetail')) {
      return PluginTopListDetailResult(
        isEnd: true,
        topListItem: topListItem,
        musicList: const <MusicItem>[],
      );
    }

    try {
      final invocation = await _pluginManagerService.invokePluginMethod(
        plugin,
        method: 'getTopListDetail',
        arguments: <dynamic>[topListItem.toJson(), page],
      );
      if (!invocation.success) {
        throw Exception(invocation.errorMessage ?? 'getTopListDetail failed.');
      }
      final payload = _readObject(invocation.data);
      return PluginTopListDetailResult(
        isEnd: payload['isEnd'] as bool? ?? true,
        topListItem: topListItem,
        musicList: _readMusicItems(
          payload['musicList'],
          platform: plugin.manifest?.platform,
        ),
      );
    } catch (error, stackTrace) {
      throw StateError(
        'getTopListDetail failed for ${plugin.displayName} with item '
        '${jsonEncode(topListItem.toJson())}: $error\n$stackTrace',
      );
    }
  }

  Future<PluginTopListDetailResult> getTopListDetailSafe({
    required PluginRecord plugin,
    required MusicSheetItem topListItem,
    int page = 1,
  }) async {
    try {
      return await getTopListDetail(
        plugin: plugin,
        topListItem: topListItem,
        page: page,
      );
    } catch (_) {
      return PluginTopListDetailResult(
        isEnd: true,
        topListItem: topListItem,
        musicList: const <MusicItem>[],
      );
    }
  }

  Future<PluginRecommendSheetTagsResult> getRecommendSheetTags({
    required PluginRecord plugin,
  }) async {
    if (!_supports(plugin, 'getRecommendSheetTags')) {
      return const PluginRecommendSheetTagsResult();
    }

    try {
      final invocation = await _pluginManagerService.invokePluginMethod(
        plugin,
        method: 'getRecommendSheetTags',
      );
      if (!invocation.success) {
        throw Exception(
          invocation.errorMessage ?? 'getRecommendSheetTags failed.',
        );
      }
      final payload = _readObject(invocation.data);
      final pinned = _readMusicSheetItems(
        payload['pinned'],
        platform: plugin.manifest?.platform,
      );
      final groups = (payload['data'] is List)
          ? (payload['data'] as List<dynamic>)
                .whereType<Map>()
                .map(
                  (item) => MusicSheetGroup(
                    title: item['title']?.toString(),
                    data: _readMusicSheetItems(
                      item['data'],
                      platform: plugin.manifest?.platform,
                    ),
                  ),
                )
                .toList(growable: false)
          : const <MusicSheetGroup>[];
      return PluginRecommendSheetTagsResult(pinned: pinned, data: groups);
    } catch (_) {
      return const PluginRecommendSheetTagsResult();
    }
  }

  Future<PluginRecommendSheetsResult> getRecommendSheetsByTag({
    required PluginRecord plugin,
    required MediaTag tag,
    int page = 1,
  }) async {
    if (!_supports(plugin, 'getRecommendSheetsByTag')) {
      return const PluginRecommendSheetsResult(isEnd: true);
    }

    try {
      final invocation = await _pluginManagerService.invokePluginMethod(
        plugin,
        method: 'getRecommendSheetsByTag',
        arguments: <dynamic>[tag.toJson(), page],
      );
      if (!invocation.success) {
        throw Exception(
          invocation.errorMessage ?? 'getRecommendSheetsByTag failed.',
        );
      }
      final payload = _readObject(invocation.data);
      return PluginRecommendSheetsResult(
        isEnd: payload['isEnd'] as bool? ?? true,
        data: _readMusicSheetItems(
          payload['data'],
          platform: plugin.manifest?.platform,
        ),
      );
    } catch (_) {
      return const PluginRecommendSheetsResult(isEnd: true);
    }
  }

  Future<PluginMusicCommentsResult> getMusicComments({
    required PluginRecord plugin,
    required MusicItem musicItem,
    int page = 1,
  }) async {
    if (!_supports(plugin, 'getMusicComments')) {
      return const PluginMusicCommentsResult(isEnd: true);
    }

    try {
      final invocation = await _pluginManagerService.invokePluginMethod(
        plugin,
        method: 'getMusicComments',
        arguments: <dynamic>[musicItem.toJson(), page],
      );
      if (!invocation.success) {
        throw Exception(invocation.errorMessage ?? 'getMusicComments failed.');
      }
      final payload = _readObject(invocation.data);
      return PluginMusicCommentsResult(
        isEnd: payload['isEnd'] as bool? ?? true,
        data: _readComments(payload['data']),
      );
    } catch (_) {
      return const PluginMusicCommentsResult(isEnd: true);
    }
  }

  bool _supports(PluginRecord plugin, String method) {
    return plugin.manifest?.supportedMethods.contains(method) ?? false;
  }

  bool _isLocalPlugin(PluginRecord plugin) {
    return plugin.hash == localPluginHash ||
        plugin.storageKey == localPluginName ||
        plugin.manifest?.platform == localPluginName;
  }

  List<MusicItem> _readMusicItems(
    dynamic value, {
    String? platform,
    String? albumTitle,
  }) {
    if (value is! List) {
      return const <MusicItem>[];
    }
    return value
        .whereType<Map>()
        .map((item) {
          final normalized = resetMediaItem(
            item.map((key, entry) => MapEntry(key.toString(), entry)),
            platform: platform,
            clone: true,
          );
          if (albumTitle != null &&
              (normalized['album']?.toString().isEmpty ?? true)) {
            normalized['album'] = albumTitle;
          }
          return MusicItem.fromJson(normalized);
        })
        .toList(growable: false);
  }

  List<MusicSheetItem> _readMusicSheetItems(dynamic value, {String? platform}) {
    if (value is! List) {
      return const <MusicSheetItem>[];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => MusicSheetItem.fromJson(
            resetMediaItem(
              item.map((key, entry) => MapEntry(key.toString(), entry)),
              platform: platform,
              clone: true,
            ),
          ),
        )
        .toList(growable: false);
  }

  List<CommentItem> _readComments(dynamic value) {
    if (value is! List) {
      return const <CommentItem>[];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => CommentItem.fromJson(
            item.map((key, entry) => MapEntry(key.toString(), entry)),
          ),
        )
        .toList(growable: false);
  }

  MediaItem _parseMediaByType(MediaType type, Map<String, dynamic> json) {
    return switch (type) {
      MediaType.music || MediaType.lyric => MusicItem.fromJson(json),
      MediaType.album => AlbumItem.fromJson(json),
      MediaType.artist => ArtistItem.fromJson(json),
      MediaType.sheet => MusicSheetItem.fromJson(json),
    };
  }

  Map<String, dynamic> _readObject(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _readMediaSourcePayload(dynamic value) {
    if (value is String) {
      return <String, dynamic>{'url': value};
    }

    final payload = _readObject(value);
    if (payload['url'] != null) {
      return payload;
    }

    final nested = payload['data'];
    if (nested is String) {
      return <String, dynamic>{...payload, 'url': nested};
    }
    if (nested is Map) {
      final nestedPayload = _readObject(nested);
      if (nestedPayload.isNotEmpty) {
        return nestedPayload;
      }
    }

    return payload;
  }

  List<String> _buildQualityFallbackOrder({required String requestedQuality}) {
    final normalized = qualityKeys.contains(requestedQuality)
        ? requestedQuality
        : 'standard';
    final index = qualityKeys.indexOf(normalized);
    if (index < 0) {
      return const <String>['standard', 'low', 'high', 'super'];
    }

    final lower = qualityKeys.sublist(0, index).reversed;
    final higher = qualityKeys.sublist(index + 1);
    return <String>[normalized, ...lower, ...higher];
  }

  String _buildMediaSourceAttemptMessage({
    required PluginRecord plugin,
    required MusicItem musicItem,
    required String quality,
    required String message,
    required List<String> logs,
  }) {
    final normalizedLogs = logs
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .take(3)
        .toList(growable: false);
    final buffer = StringBuffer()
      ..write('Plugin ')
      ..write(plugin.displayName)
      ..write(' failed to resolve media source for ')
      ..write('"${musicItem.title}"')
      ..write(' [')
      ..write(quality)
      ..write(']');
    if (message.trim().isNotEmpty) {
      buffer
        ..write(': ')
        ..write(message.trim());
    }
    if (normalizedLogs.isNotEmpty) {
      buffer
        ..write(' Logs: ')
        ..write(normalizedLogs.join(' | '));
    }
    return buffer.toString();
  }

  String _buildMediaSourceFailureSummary({
    required PluginRecord plugin,
    required MusicItem musicItem,
    required List<String> attemptedQualities,
    required List<String> failureMessages,
  }) {
    final buffer = StringBuffer()
      ..write('Plugin ')
      ..write(plugin.displayName)
      ..write(' could not resolve a playable media source for ')
      ..write('"${musicItem.title}"')
      ..write('. Tried qualities: ')
      ..write(attemptedQualities.join(', '));
    if (failureMessages.isNotEmpty) {
      buffer
        ..write('. Failures: ')
        ..write(failureMessages.join(' || '));
    }
    return buffer.toString();
  }

  String? _readUserAgent(Map<String, String> headers) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'user-agent') {
        return entry.value;
      }
    }
    return null;
  }

  Map<String, String> _readStringMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value.map((key, entry) => MapEntry(key, entry.toString()));
    }
    if (value is Map) {
      return value.map(
        (key, entry) => MapEntry(key.toString(), entry.toString()),
      );
    }
    return const <String, String>{};
  }
}
