import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../core/filesystem/app_paths.dart';
import '../../../core/media/media_constants.dart';
import '../../../core/storage/json_file_store.dart';
import '../domain/download_models.dart';

class DownloadSettingsRepository {
  const DownloadSettingsRepository({
    required JsonFileStore configStore,
    required AppPaths appPaths,
  }) : _configStore = configStore,
       _appPaths = appPaths;

  final JsonFileStore _configStore;
  final AppPaths _appPaths;

  Future<DownloadSettings> load() async {
    final raw = await _configStore.readObject();
    final downloadConfig = (raw['download'] is Map)
        ? (raw['download'] as Map).map(
            (key, value) => MapEntry(key.toString(), value),
          )
        : const <String, dynamic>{};

    final fallbackDirectory =
        (await getDownloadsDirectory())?.path ??
        path.join(_appPaths.rootDirectory.path, 'downloads');
    final configuredDirectory = downloadConfig['path']?.toString().trim();
    final resolvedDirectory =
        configuredDirectory == null || configuredDirectory.isEmpty
        ? fallbackDirectory
        : configuredDirectory;

    final directory = Directory(resolvedDirectory);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final requestedConcurrency =
        (downloadConfig['concurrency'] as num?)?.toInt() ?? 5;
    final defaultQuality =
        qualityKeys.contains(downloadConfig['defaultQuality']?.toString())
        ? downloadConfig['defaultQuality'].toString()
        : 'standard';
    final whenQualityMissing = switch (downloadConfig['whenQualityMissing']
        ?.toString()) {
      'higher' => 'higher',
      _ => 'lower',
    };

    return DownloadSettings(
      downloadDirectoryPath: directory.path,
      concurrency: requestedConcurrency.clamp(1, 20).toInt(),
      defaultQuality: defaultQuality,
      whenQualityMissing: whenQualityMissing,
    );
  }
}
