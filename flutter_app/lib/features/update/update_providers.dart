import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app/app_environment_provider.dart';
import '../plugins/plugin_providers.dart';
import 'application/app_update_service.dart';
import 'domain/app_update_models.dart';

enum AppUpdateCheckResult { upToDate, updateAvailable, error }

final appUpdateControllerProvider =
    AsyncNotifierProvider<AppUpdateController, AppUpdateStatus>(
      AppUpdateController.new,
    );

class AppUpdateController extends AsyncNotifier<AppUpdateStatus> {
  AppUpdateRelease? _latestRelease;
  late final AppUpdateService _service;
  late final String _currentVersion;

  @override
  Future<AppUpdateStatus> build() async {
    final appEnvironment = await ref.watch(appEnvironmentProvider.future);
    final appPaths = await ref.watch(appPathsProvider.future);
    _currentVersion = appEnvironment.version;
    _service = AppUpdateService(appPaths: appPaths);
    ref.onDispose(_service.dispose);

    return AppUpdateStatus(
      currentVersion: formatVersionLabel(_currentVersion),
      stage: AppUpdateStage.idle,
      message: '点击按钮检测新版本。',
    );
  }

  Future<AppUpdateCheckResult> checkForUpdates() async {
    final current = state.valueOrNull ?? await future;
    if (current.isBusy) {
      return current.hasUpdate
          ? AppUpdateCheckResult.updateAvailable
          : AppUpdateCheckResult.error;
    }

    state = AsyncData(
      current.copyWith(
        stage: AppUpdateStage.checking,
        clearMessage: true,
        clearErrorDetails: true,
        clearProgress: true,
      ),
    );

    try {
      final release = await _service.fetchLatestRelease(
        currentVersion: _currentVersion,
      );
      if (release == null) {
        _latestRelease = null;
        state = AsyncData(
          current.copyWith(
            stage: AppUpdateStage.upToDate,
            latestVersion: formatVersionLabel(_currentVersion),
            latestTagName: formatVersionLabel(_currentVersion),
            message: '当前已经是最新版本。',
            clearErrorDetails: true,
            clearProgress: true,
          ),
        );
        return AppUpdateCheckResult.upToDate;
      }

      _latestRelease = release;
      state = AsyncData(
        current.copyWith(
          stage: AppUpdateStage.updateAvailable,
          latestVersion: formatVersionLabel(release.version),
          latestTagName: release.tagName,
          message: '检测到新版本，是否开始更新？',
          clearErrorDetails: true,
          clearProgress: true,
        ),
      );
      return AppUpdateCheckResult.updateAvailable;
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          stage: AppUpdateStage.error,
          message: '检测更新失败。',
          errorDetails: error.toString(),
          clearProgress: true,
        ),
      );
      return AppUpdateCheckResult.error;
    }
  }

  Future<void> downloadAndInstallUpdate() async {
    final release = _latestRelease;
    final current = state.valueOrNull ?? await future;
    if (release == null || current.isBusy) {
      return;
    }

    state = AsyncData(
      current.copyWith(
        stage: AppUpdateStage.downloading,
        progress: 0,
        message: '正在下载安装包...',
        clearErrorDetails: true,
      ),
    );

    try {
      final installerPath = await _service.downloadInstaller(
        release,
        onProgress: (receivedBytes, totalBytes) {
          final progress = totalBytes == null || totalBytes <= 0
              ? null
              : receivedBytes / totalBytes;
          final next = state.valueOrNull ?? current;
          state = AsyncData(
            next.copyWith(
              stage: AppUpdateStage.downloading,
              progress: progress,
              message: _buildProgressMessage(
                receivedBytes: receivedBytes,
                totalBytes: totalBytes,
              ),
            ),
          );
        },
      );

      state = AsyncData(
        (state.valueOrNull ?? current).copyWith(
          stage: AppUpdateStage.launchingInstaller,
          progress: 1,
          message: '正在启动安装器...',
        ),
      );

      await _service.launchInstaller(installerPath);
      await Future<void>.delayed(const Duration(milliseconds: 800));
      exit(0);
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          stage: AppUpdateStage.error,
          message: '更新失败。',
          errorDetails: error.toString(),
          clearProgress: true,
        ),
      );
    }
  }

  String _buildProgressMessage({
    required int receivedBytes,
    required int? totalBytes,
  }) {
    if (totalBytes == null || totalBytes <= 0) {
      return '已下载 ${_formatBytes(receivedBytes)}';
    }
    return '已下载 ${_formatBytes(receivedBytes)} / ${_formatBytes(totalBytes)}';
  }
}

String _formatBytes(int bytes) {
  const units = <String>['B', 'KB', 'MB', 'GB'];
  var size = bytes.toDouble();
  var unitIndex = 0;

  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex += 1;
  }

  final fractionDigits = size >= 100 ? 0 : (size >= 10 ? 1 : 2);
  return '${size.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
}
