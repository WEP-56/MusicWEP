import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../../core/app/app_environment_provider.dart';
import '../../../core/filesystem/app_paths.dart';
import '../../../core/media/media_constants.dart';
import '../../../core/media/media_models.dart';
import '../../../core/storage/json_file_store.dart';
import '../../plugins/application/plugin_method_service.dart';
import '../../plugins/domain/plugin.dart';
import '../../plugins/plugin_providers.dart';
import '../../settings/application/app_settings_controller.dart';
import '../../settings/domain/app_settings.dart';
import '../domain/download_models.dart';
import 'download_debug_logger.dart';
import 'download_file_service.dart';
import 'download_repository.dart';
import 'download_settings_repository.dart';

const Duration _progressPublishInterval = Duration(milliseconds: 180);
const int _progressPublishStepBytes = 128 * 1024;

class DownloadController extends AsyncNotifier<List<DownloadTask>> {
  AppPaths? _appPaths;
  DownloadRepository? _repository;
  DownloadSettings? _settings;
  PluginMethodService? _pluginMethodService;
  String? _appVersion;
  String? _runtimeOs;
  DownloadDebugLogger? _logger;
  final DownloadFileService _fileService = const DownloadFileService();
  final Set<String> _runningTaskIds = <String>{};
  Future<void> _persistQueue = Future<void>.value();
  bool _disposed = false;
  bool _pumpScheduled = false;

  @override
  Future<List<DownloadTask>> build() async {
    ref.onDispose(() {
      _disposed = true;
    });

    _appPaths = await ref.watch(appPathsProvider.future);
    final appEnvironment = await ref.watch(appEnvironmentProvider.future);
    _appVersion = appEnvironment.version;
    _runtimeOs = appEnvironment.runtimeOs;
    _logger = DownloadDebugLogger(
      pathForDownloadDebugLog(_appPaths!.logsDirectory.path),
    );
    _logger?.log(
      'controller',
      'build start appVersion=$_appVersion os=$_runtimeOs',
    );
    _repository = DownloadRepository(
      JsonFileStore(
        path.join(_appPaths!.appDataDirectory.path, 'download_tasks.json'),
      ),
    );
    _settings = await DownloadSettingsRepository(
      configStore: JsonFileStore(_appPaths!.configFilePath),
      appPaths: _appPaths!,
    ).load();
    _pluginMethodService = await ref.watch(pluginMethodServiceProvider.future);
    ref.listen<AsyncValue<AppSettings>>(appSettingsControllerProvider, (
      _,
      next,
    ) {
      final settings = next.valueOrNull;
      if (settings == null) {
        return;
      }
      _settings = DownloadSettings(
        downloadDirectoryPath: settings.download.path?.trim().isNotEmpty == true
            ? settings.download.path!.trim()
            : (_settings?.downloadDirectoryPath ??
                  _appPaths!.rootDirectory.path),
        concurrency: settings.download.concurrency.clamp(1, 20).toInt(),
        defaultQuality: settings.download.defaultQuality,
        whenQualityMissing: settings.download.whenQualityMissing,
      );
    });

    final loaded = await _repository!.loadAll();
    _logger?.log('controller', 'loaded persisted tasks=${loaded.length}');
    final normalized = loaded
        .map((task) {
          if (task.status == DownloadTaskStatus.waiting ||
              task.status == DownloadTaskStatus.downloading) {
            return task.copyWith(
              status: DownloadTaskStatus.failed,
              updatedAt: DateTime.now(),
              errorMessage: '上次下载已中断，请重试。',
            );
          }
          return task;
        })
        .toList(growable: false);
    final changed = !_sameTaskSnapshot(loaded, normalized);
    if (changed) {
      await _repository!.saveAll(normalized);
    }
    return normalized;
  }

  Future<DownloadEnqueueResult> enqueueTrack(MusicItem track) async {
    _logger?.log(
      'enqueue',
      'request track=${track.platform}@${track.id} title=${track.title}',
    );
    if (_isLocalTrack(track)) {
      _logger?.log('enqueue', 'skip local track');
      return DownloadEnqueueResult.localTrack;
    }

    final plugin = _resolvePlugin(track);
    if (plugin == null) {
      _logger?.log(
        'enqueue',
        'plugin missing for ${track.platform}@${track.id}',
      );
      return DownloadEnqueueResult.missingPlugin;
    }

    final currentTasks = _tasks.toList(growable: true);
    final index = currentTasks.indexWhere(
      (task) => task.trackKey == _trackKey(track),
    );
    final now = DateTime.now();
    if (index >= 0) {
      final existing = currentTasks[index];
      if (existing.status == DownloadTaskStatus.completed) {
        _logger?.log('enqueue', 'already downloaded taskId=${existing.id}');
        return DownloadEnqueueResult.alreadyDownloaded;
      }
      if (existing.status == DownloadTaskStatus.waiting ||
          existing.status == DownloadTaskStatus.downloading) {
        _logger?.log(
          'enqueue',
          'already queued taskId=${existing.id} status=${existing.status.name}',
        );
        return DownloadEnqueueResult.alreadyQueued;
      }
      currentTasks[index] = existing.copyWith(
        status: DownloadTaskStatus.waiting,
        updatedAt: now,
        downloadedBytes: 0,
        clearTotalBytes: true,
        clearErrorMessage: true,
        clearFilePath: true,
        pluginId: plugin.storageKey,
        requestedQuality: _settings!.defaultQuality,
      );
    } else {
      currentTasks.add(
        DownloadTask(
          id: '${now.microsecondsSinceEpoch}_${track.platform}_${track.id}',
          track: track,
          createdAt: now,
          updatedAt: now,
          pluginId: plugin.storageKey,
          requestedQuality: _settings!.defaultQuality,
        ),
      );
    }

    await _replaceTasks(currentTasks, persist: true);
    _logger?.log(
      'enqueue',
      'queued track=${track.platform}@${track.id} totalTasks=${currentTasks.length}',
    );
    _schedulePump();
    return DownloadEnqueueResult.queued;
  }

  Future<void> retryTask(String taskId) async {
    final currentTasks = _tasks.toList(growable: true);
    final index = currentTasks.indexWhere((task) => task.id == taskId);
    if (index < 0) {
      return;
    }
    final current = currentTasks[index];
    if (current.status != DownloadTaskStatus.failed) {
      return;
    }
    currentTasks[index] = current.copyWith(
      status: DownloadTaskStatus.waiting,
      updatedAt: DateTime.now(),
      downloadedBytes: 0,
      clearTotalBytes: true,
      clearErrorMessage: true,
      clearFilePath: true,
    );
    await _replaceTasks(currentTasks, persist: true);
    _schedulePump();
  }

  Future<void> removeTask(String taskId, {bool deleteFile = false}) async {
    final currentTasks = _tasks.toList(growable: true);
    final index = currentTasks.indexWhere((task) => task.id == taskId);
    if (index < 0) {
      return;
    }
    final task = currentTasks[index];
    if (_runningTaskIds.contains(taskId)) {
      return;
    }
    currentTasks.removeAt(index);
    await _replaceTasks(currentTasks, persist: true);
    if (deleteFile && task.filePath?.isNotEmpty == true) {
      await _fileService.deleteFile(task.filePath!);
    }
  }

  Future<void> _pumpQueue() async {
    if (_disposed) {
      return;
    }
    final settings = _settings;
    if (settings == null) {
      return;
    }
    while (_runningTaskIds.length < settings.concurrency) {
      final nextTask = _tasks.firstWhereOrNull(
        (task) => task.status == DownloadTaskStatus.waiting,
      );
      if (nextTask == null) {
        break;
      }
      _logger?.log(
        'pump',
        'start taskId=${nextTask.id} running=${_runningTaskIds.length}/${settings.concurrency}',
      );
      _runningTaskIds.add(nextTask.id);
      unawaited(_runTask(nextTask.id));
    }
  }

  void _schedulePump() {
    if (_pumpScheduled || _disposed) {
      return;
    }
    _pumpScheduled = true;
    scheduleMicrotask(() async {
      _pumpScheduled = false;
      await _pumpQueue();
    });
  }

  Future<void> _runTask(String taskId) async {
    final taskStopwatch = Stopwatch()..start();
    try {
      final task = _taskById(taskId);
      if (task == null) {
        _logger?.log('task', 'task missing taskId=$taskId');
        return;
      }
      _logger?.log('task', 'run start taskId=$taskId track=${task.trackKey}');
      final plugin = _resolvePlugin(
        task.track,
        preferredPluginId: task.pluginId,
      );
      if (plugin == null) {
        _logger?.log('task', 'plugin missing taskId=$taskId');
        await _markTaskFailed(taskId, '未找到对应插件，无法下载。');
        return;
      }
      _logger?.log(
        'task',
        'plugin resolved taskId=$taskId plugin=${plugin.storageKey}',
      );

      await _updateTask(
        taskId,
        (current) => current.copyWith(
          status: DownloadTaskStatus.downloading,
          updatedAt: DateTime.now(),
          downloadedBytes: 0,
          clearTotalBytes: true,
          clearErrorMessage: true,
          clearFilePath: true,
          pluginId: plugin.storageKey,
        ),
        persist: true,
      );

      final pluginMethodService = _pluginMethodService;
      if (pluginMethodService == null) {
        _logger?.log('task', 'plugin method service missing taskId=$taskId');
        await _markTaskFailed(taskId, '下载环境未初始化完成。');
        return;
      }

      final resolveStopwatch = Stopwatch()..start();
      _logger?.log('task', 'resolve media source start taskId=$taskId');
      final mediaSource = await pluginMethodService.getMediaSource(
        plugin: plugin,
        musicItem: task.track,
        quality: task.requestedQuality,
      );
      resolveStopwatch.stop();
      _logger?.log(
        'task',
        'resolve media source end taskId=$taskId ms=${resolveStopwatch.elapsedMilliseconds} success=${mediaSource != null}',
      );
      if (mediaSource == null) {
        await _markTaskFailed(taskId, '插件未返回可下载的音频地址。');
        return;
      }

      final extension = _fileService.resolveFileExtension(mediaSource);
      final baseName = _fileService.sanitizeFileName(
        '${task.track.title}-${task.track.artist}',
      );
      final savePath = await _resolveAvailableFilePath(
        _settings!.downloadDirectoryPath,
        '$baseName$extension',
      );
      var lastPublishedAt = DateTime.fromMillisecondsSinceEpoch(0);
      var lastPublishedBytes = -1;
      int? lastPublishedTotal;
      var latestDownloadedBytes = 0;
      int? latestTotalBytes;

      _logger?.log('task', 'download start taskId=$taskId file=$savePath');
      await _fileService.download(
        mediaSource: mediaSource,
        filePath: savePath,
        onLog: (message) => _logger?.log('http', 'taskId=$taskId $message'),
        onProgress: (downloaded, total) {
          latestDownloadedBytes = downloaded;
          latestTotalBytes = total;
          final now = DateTime.now();
          if (!_shouldPublishProgress(
            now: now,
            downloaded: downloaded,
            total: total,
            lastPublishedAt: lastPublishedAt,
            lastPublishedBytes: lastPublishedBytes,
            lastPublishedTotal: lastPublishedTotal,
          )) {
            return;
          }
          lastPublishedAt = now;
          lastPublishedBytes = downloaded;
          lastPublishedTotal = total;
          unawaited(
            _updateTask(
              taskId,
              (current) => current.copyWith(
                status: DownloadTaskStatus.downloading,
                updatedAt: now,
                downloadedBytes: downloaded,
                totalBytes: total,
                filePath: savePath,
              ),
              persist: false,
            ),
          );
        },
      );

      await _updateTask(taskId, (current) {
        final resolvedTrack = attachDownloadData(
          current.track,
          filePath: savePath,
          quality: mediaSource.quality ?? current.requestedQuality,
        );
        return current.copyWith(
          track: resolvedTrack,
          status: DownloadTaskStatus.completed,
          updatedAt: DateTime.now(),
          downloadedBytes: latestDownloadedBytes,
          totalBytes: latestTotalBytes ?? current.totalBytes,
          filePath: savePath,
          clearErrorMessage: true,
        );
      }, persist: true);
      _logger?.log(
        'task',
        'completed taskId=$taskId bytes=$latestDownloadedBytes file=$savePath',
      );
    } catch (error) {
      _logger?.log('task', 'failed taskId=$taskId error=$error');
      await _markTaskFailed(taskId, error.toString());
    } finally {
      taskStopwatch.stop();
      _logger?.log(
        'task',
        'run end taskId=$taskId ms=${taskStopwatch.elapsedMilliseconds}',
      );
      _runningTaskIds.remove(taskId);
      _schedulePump();
    }
  }

  Future<void> _markTaskFailed(String taskId, String message) {
    return _updateTask(
      taskId,
      (current) => current.copyWith(
        status: DownloadTaskStatus.failed,
        updatedAt: DateTime.now(),
        errorMessage: message,
      ),
      persist: true,
    );
  }

  Future<void> _updateTask(
    String taskId,
    DownloadTask Function(DownloadTask current) transform, {
    required bool persist,
  }) async {
    final currentTasks = _tasks.toList(growable: true);
    final index = currentTasks.indexWhere((task) => task.id == taskId);
    if (index < 0) {
      return;
    }
    currentTasks[index] = transform(currentTasks[index]);
    await _replaceTasks(currentTasks, persist: persist);
  }

  Future<void> _replaceTasks(
    List<DownloadTask> tasks, {
    required bool persist,
  }) async {
    state = AsyncData(
      tasks.toList(growable: false)
        ..sort((left, right) => right.createdAt.compareTo(left.createdAt)),
    );
    _logger?.log(
      'state',
      'replace tasks count=${tasks.length} persist=$persist '
          'active=${tasks.where((it) => it.isActive).length} '
          'completed=${tasks.where((it) => it.isCompleted).length}',
    );
    if (persist) {
      await _persistTasks(state.valueOrNull ?? const <DownloadTask>[]);
    }
  }

  Future<void> _persistTasks(List<DownloadTask> tasks) {
    final repository = _repository;
    if (repository == null) {
      return Future<void>.value();
    }
    final snapshot = tasks.toList(growable: false);
    _persistQueue = _persistQueue.then((_) => repository.saveAll(snapshot));
    return _persistQueue;
  }

  PluginRecord? _resolvePlugin(MusicItem track, {String? preferredPluginId}) {
    if (_isLocalTrack(track)) {
      return null;
    }
    final snapshot = ref.read(pluginControllerProvider).valueOrNull;
    if (snapshot == null) {
      _logger?.log(
        'plugin',
        'plugin snapshot unavailable for ${track.platform}@${track.id}',
      );
      return null;
    }
    for (final plugin in snapshot.plugins) {
      if (!plugin.meta.enabled) {
        continue;
      }
      if ((preferredPluginId != null &&
              plugin.storageKey == preferredPluginId) ||
          plugin.storageKey == track.platform ||
          plugin.manifest?.platform == track.platform ||
          plugin.hash == track.platform) {
        return plugin;
      }
    }
    return null;
  }

  Future<String> _resolveAvailableFilePath(
    String directoryPath,
    String fileName,
  ) async {
    final extension = path.extension(fileName);
    final baseName = extension.isEmpty
        ? fileName
        : fileName.substring(0, fileName.length - extension.length);
    var candidate = path.join(directoryPath, fileName);
    var index = 1;
    while (await File(candidate).exists()) {
      candidate = path.join(directoryPath, '$baseName ($index)$extension');
      index += 1;
    }
    return candidate;
  }

  bool _isLocalTrack(MusicItem track) => track.platform == localPluginName;

  DownloadTask? _taskById(String taskId) {
    return _tasks.firstWhereOrNull((task) => task.id == taskId);
  }

  List<DownloadTask> get _tasks => state.valueOrNull ?? const <DownloadTask>[];
}

bool _shouldPublishProgress({
  required DateTime now,
  required int downloaded,
  required int? total,
  required DateTime lastPublishedAt,
  required int lastPublishedBytes,
  required int? lastPublishedTotal,
}) {
  if (lastPublishedBytes < 0) {
    return true;
  }
  if (total != null && downloaded >= total) {
    return true;
  }
  if (lastPublishedTotal != total) {
    return true;
  }
  if ((downloaded - lastPublishedBytes).abs() >= _progressPublishStepBytes) {
    return true;
  }
  return now.difference(lastPublishedAt) >= _progressPublishInterval;
}

bool _sameTaskSnapshot(List<DownloadTask> left, List<DownloadTask> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index].toJson().toString() != right[index].toJson().toString()) {
      return false;
    }
  }
  return true;
}

String _trackKey(MusicItem track) => '${track.platform}@${track.id}';

extension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}
