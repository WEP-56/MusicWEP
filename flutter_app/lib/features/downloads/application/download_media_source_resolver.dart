import 'dart:io';
import 'dart:isolate';

import '../../../core/filesystem/app_paths.dart';
import '../../../core/media/media_constants.dart';
import '../../../core/media/media_models.dart';
import '../../../core/runtime/plugin_runtime_host.dart';
import '../../plugins/domain/plugin.dart';
import '../../plugins/domain/plugin_method_models.dart';
import 'download_debug_logger.dart';

Future<PluginMediaSourceResult?> resolveDownloadMediaSource({
  required AppPaths appPaths,
  required PluginRecord plugin,
  required String appVersion,
  required String os,
  required String language,
  required MusicItem track,
  required String requestedQuality,
  required String whenQualityMissing,
}) {
  final request = <String, dynamic>{
    'paths': <String, dynamic>{
      'rootDirectory': appPaths.rootDirectory.path,
      'appDataDirectory': appPaths.appDataDirectory.path,
      'pluginsDirectory': appPaths.pluginsDirectory.path,
      'cacheDirectory': appPaths.cacheDirectory.path,
      'pluginRuntimeCacheDirectory': appPaths.pluginRuntimeCacheDirectory.path,
      'logsDirectory': appPaths.logsDirectory.path,
      'pluginLogsDirectory': appPaths.pluginLogsDirectory.path,
      'configFilePath': appPaths.configFilePath,
      'pluginMetaFilePath': appPaths.pluginMetaFilePath,
      'subscriptionsFilePath': appPaths.subscriptionsFilePath,
      'pluginStorageFilePath': appPaths.pluginStorageFilePath,
      'pluginCookiesFilePath': appPaths.pluginCookiesFilePath,
    },
    'pluginFilePath': plugin.filePath,
    'pluginSourceUrl': Uri.file(plugin.filePath).toString(),
    'appVersion': appVersion,
    'os': os,
    'language': language,
    'track': track.toJson(),
    'requestedQuality': requestedQuality,
    'whenQualityMissing': whenQualityMissing,
    'logFilePath': pathForDownloadDebugLog(appPaths.logsDirectory.path),
  };
  return Isolate.run<PluginMediaSourceResult?>(() async {
    return _resolveInBackground(
      request.map((key, value) => MapEntry(key.toString(), value)),
    );
  });
}

Future<PluginMediaSourceResult?> _resolveInBackground(
  Map<String, dynamic> request,
) async {
  final logFilePath = request['logFilePath']?.toString();
  final appPaths = _readAppPaths(
    (request['paths'] as Map).map(
      (key, value) => MapEntry(key.toString(), value),
    ),
  );
  final host = PluginRuntimeHost(appPaths: appPaths);
  try {
    if (logFilePath != null && logFilePath.isNotEmpty) {
      await appendDownloadDebugLog(
        logFilePath,
        'resolver',
        'background start plugin=${request['pluginFilePath']}',
      );
    }
    final track = MusicItem.fromJson(
      (request['track'] as Map).map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
    final script = await File(
      request['pluginFilePath'].toString(),
    ).readAsString();
    final sourceUrl = request['pluginSourceUrl'].toString();
    final appVersion = request['appVersion'].toString();
    final os = request['os'].toString();
    final language = request['language'].toString();
    final requestedQuality = request['requestedQuality'].toString();
    final whenQualityMissing = request['whenQualityMissing'].toString();

    for (final quality in _buildQualityOrder(
      requestedQuality: requestedQuality,
      whenQualityMissing: whenQualityMissing,
    )) {
      try {
        if (logFilePath != null && logFilePath.isNotEmpty) {
          await appendDownloadDebugLog(
            logFilePath,
            'resolver',
            'invoke getMediaSource quality=$quality track=${track.platform}@${track.id}',
          );
        }
        final invocation = await host.invokeMethod(
          script: script,
          sourceUrl: sourceUrl,
          appVersion: appVersion,
          os: os,
          language: language,
          method: 'getMediaSource',
          arguments: <dynamic>[track.toJson(), quality],
        );
        if (!invocation.success) {
          continue;
        }
        final payload = _readMediaSourcePayload(invocation.data);
        final url =
            payload['url']?.toString() ??
            track.qualities[quality]?['url']?.toString() ??
            track.url;
        if (url == null || url.isEmpty) {
          if (logFilePath != null && logFilePath.isNotEmpty) {
            await appendDownloadDebugLog(
              logFilePath,
              'resolver',
              'empty url quality=$quality',
            );
          }
          continue;
        }
        final headers = _readStringMap(payload['headers']);
        if (logFilePath != null && logFilePath.isNotEmpty) {
          await appendDownloadDebugLog(
            logFilePath,
            'resolver',
            'resolved success quality=$quality url=$url',
          );
        }
        return PluginMediaSourceResult(
          url: url,
          headers: headers,
          userAgent: _readUserAgent(headers),
          quality: qualityKeys.contains(quality) ? quality : null,
        );
      } catch (error) {
        if (logFilePath != null && logFilePath.isNotEmpty) {
          await appendDownloadDebugLog(
            logFilePath,
            'resolver',
            'resolve failed quality=$quality error=$error',
          );
        }
        // keep trying lower/higher quality
      }
    }
    if (logFilePath != null && logFilePath.isNotEmpty) {
      await appendDownloadDebugLog(
        logFilePath,
        'resolver',
        'resolve exhausted without media source',
      );
    }
    return null;
  } finally {
    host.dispose();
  }
}

AppPaths _readAppPaths(Map<String, dynamic> raw) {
  return AppPaths(
    rootDirectory: Directory(raw['rootDirectory']?.toString() ?? ''),
    appDataDirectory: Directory(raw['appDataDirectory']?.toString() ?? ''),
    pluginsDirectory: Directory(raw['pluginsDirectory']?.toString() ?? ''),
    cacheDirectory: Directory(raw['cacheDirectory']?.toString() ?? ''),
    pluginRuntimeCacheDirectory: Directory(
      raw['pluginRuntimeCacheDirectory']?.toString() ?? '',
    ),
    logsDirectory: Directory(raw['logsDirectory']?.toString() ?? ''),
    pluginLogsDirectory: Directory(
      raw['pluginLogsDirectory']?.toString() ?? '',
    ),
    configFilePath: raw['configFilePath']?.toString() ?? '',
    pluginMetaFilePath: raw['pluginMetaFilePath']?.toString() ?? '',
    subscriptionsFilePath: raw['subscriptionsFilePath']?.toString() ?? '',
    pluginStorageFilePath: raw['pluginStorageFilePath']?.toString() ?? '',
    pluginCookiesFilePath: raw['pluginCookiesFilePath']?.toString() ?? '',
  );
}

List<String> _buildQualityOrder({
  required String requestedQuality,
  required String whenQualityMissing,
}) {
  final normalized = qualityKeys.contains(requestedQuality)
      ? requestedQuality
      : 'standard';
  final index = qualityKeys.indexOf(normalized);
  if (index < 0) {
    return const <String>['standard'];
  }
  if (whenQualityMissing == 'skip') {
    return <String>[normalized];
  }
  final lower = qualityKeys.sublist(0, index).reversed;
  final higher = qualityKeys.sublist(index + 1);
  if (whenQualityMissing == 'higher') {
    return <String>[normalized, ...higher, ...lower];
  }
  return <String>[normalized, ...lower, ...higher];
}

Map<String, dynamic> _readMediaSourcePayload(dynamic value) {
  if (value is String) {
    return <String, dynamic>{'url': value};
  }
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    final payload = value.map((key, entry) => MapEntry(key.toString(), entry));
    if (payload['url'] != null) {
      return payload;
    }
    final nested = payload['data'];
    if (nested is String) {
      return <String, dynamic>{...payload, 'url': nested};
    }
    if (nested is Map) {
      return nested.map((key, entry) => MapEntry(key.toString(), entry));
    }
    return payload;
  }
  return const <String, dynamic>{};
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

String? _readUserAgent(Map<String, String> headers) {
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == 'user-agent') {
      return entry.value;
    }
  }
  return null;
}
