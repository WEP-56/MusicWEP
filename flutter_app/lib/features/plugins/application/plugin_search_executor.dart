import '../../../core/media/media_models.dart';
import '../../../core/media/media_utils.dart';
import '../../../core/runtime/plugin_runtime_adapter.dart';
import '../domain/plugin.dart';
import '../domain/plugin_search.dart';
import '../infrastructure/plugin_file_repository.dart';

class PluginSearchExecutor {
  const PluginSearchExecutor({
    required PluginFileRepository fileRepository,
    required PluginRuntimeAdapter runtime,
    required Future<List<PluginRecord>> Function() loadPlugins,
    required this.appVersion,
    required this.os,
    required this.language,
  }) : _fileRepository = fileRepository,
       _runtime = runtime,
       _loadPlugins = loadPlugins;

  final PluginFileRepository _fileRepository;
  final PluginRuntimeAdapter _runtime;
  final Future<List<PluginRecord>> Function() _loadPlugins;
  final String appVersion;
  final String os;
  final String language;

  Future<List<PluginSearchResult>> searchAllEnabled({
    required String query,
    required PluginSearchType type,
    int page = 1,
  }) async {
    final plugins = await _loadPlugins();
    final searchablePlugins = plugins
        .where((plugin) {
          return plugin.meta.enabled &&
              (plugin.manifest?.supportedMethods.contains('search') ?? false);
        })
        .toList(growable: false);

    final results = <PluginSearchResult>[];
    for (final plugin in searchablePlugins) {
      final script = await _fileRepository.readScript(plugin.filePath);
      final invocation = await _runtime.invokeMethod(
        script: script,
        sourceUrl: Uri.file(plugin.filePath).toString(),
        appVersion: appVersion,
        os: os,
        language: language,
        method: 'search',
        arguments: <dynamic>[query, page, type.value],
      );

      if (!invocation.success) {
        results.add(
          PluginSearchResult(
            plugin: plugin,
            items: const <PluginSearchResultItem>[],
            logs: invocation.logs,
            requiredPackages: invocation.requiredPackages,
            missingPackages: invocation.missingPackages,
            errorMessage: invocation.errorMessage ?? 'Search failed.',
          ),
        );
        continue;
      }

      final payload = invocation.data;
      final mapPayload = payload is Map<String, dynamic>
          ? payload
          : payload is Map
          ? payload.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};
      final rawItems =
          mapPayload['data'] as List<dynamic>? ?? const <dynamic>[];

      results.add(
        PluginSearchResult(
          plugin: plugin,
          items: rawItems
              .whereType<Map>()
              .map(
                (item) => PluginSearchResultItem(
                  media: _parseMediaByType(
                    type.mediaType,
                    resetMediaItem(
                      item.map((key, value) => MapEntry(key.toString(), value)),
                      platform: plugin.manifest?.platform,
                      clone: true,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
          logs: invocation.logs,
          requiredPackages: invocation.requiredPackages,
          missingPackages: invocation.missingPackages,
          isEnd: mapPayload['isEnd'] as bool? ?? true,
        ),
      );
    }

    return results;
  }

  Future<PluginSearchResult> searchPlugin({
    required PluginRecord plugin,
    required String query,
    required PluginSearchType type,
    int page = 1,
  }) async {
    final script = await _fileRepository.readScript(plugin.filePath);
    final invocation = await _runtime.invokeMethod(
      script: script,
      sourceUrl: Uri.file(plugin.filePath).toString(),
      appVersion: appVersion,
      os: os,
      language: language,
      method: 'search',
      arguments: <dynamic>[query, page, type.value],
    );

    if (!invocation.success) {
      return PluginSearchResult(
        plugin: plugin,
        items: const <PluginSearchResultItem>[],
        logs: invocation.logs,
        requiredPackages: invocation.requiredPackages,
        missingPackages: invocation.missingPackages,
        errorMessage: invocation.errorMessage ?? 'Search failed.',
      );
    }

    final payload = invocation.data;
    final mapPayload = payload is Map<String, dynamic>
        ? payload
        : payload is Map
        ? payload.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    final rawItems = mapPayload['data'] as List<dynamic>? ?? const <dynamic>[];

    return PluginSearchResult(
      plugin: plugin,
      items: rawItems
          .whereType<Map>()
          .map(
            (item) => PluginSearchResultItem(
              media: _parseMediaByType(
                type.mediaType,
                resetMediaItem(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                  platform: plugin.manifest?.platform,
                  clone: true,
                ),
              ),
            ),
          )
          .toList(growable: false),
      logs: invocation.logs,
      requiredPackages: invocation.requiredPackages,
      missingPackages: invocation.missingPackages,
      isEnd: mapPayload['isEnd'] as bool? ?? true,
    );
  }

  MediaItem _parseMediaByType(MediaType type, Map<String, dynamic> json) {
    return switch (type) {
      MediaType.music || MediaType.lyric => MusicItem.fromJson(json),
      MediaType.album => AlbumItem.fromJson(json),
      MediaType.artist => ArtistItem.fromJson(json),
      MediaType.sheet => MusicSheetItem.fromJson(json),
    };
  }
}
