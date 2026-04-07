import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/json_file_store.dart';
import '../../plugins/plugin_providers.dart';
import 'app_cache_manager.dart';
import '../domain/app_settings.dart';

class AppSettingsController extends AsyncNotifier<AppSettings> {
  JsonFileStore? _store;
  AppCacheManager? _cacheManager;
  Timer? _cacheMaintenanceTimer;
  bool _cacheMaintenanceRunning = false;

  @override
  Future<AppSettings> build() async {
    final appPaths = await ref.watch(appPathsProvider.future);
    _store = JsonFileStore(appPaths.configFilePath);
    _cacheManager = AppCacheManager(appPaths);
    ref.onDispose(() {
      _cacheMaintenanceTimer?.cancel();
    });
    final raw = await _store!.readObject();
    final settings = AppSettings.fromJson(raw);
    _startCacheMaintenance(settings);
    unawaited(_maintainCache(settings));
    return settings;
  }

  Future<void> setNormalCloseBehavior(String value) {
    final current = state.valueOrNull ?? AppSettings.defaults;
    return _save(
      current.copyWith(normal: current.normal.copyWith(closeBehavior: value)),
    );
  }

  Future<void> setPlayDefaultQuality(String value) {
    final current = state.valueOrNull ?? AppSettings.defaults;
    return _save(
      current.copyWith(
        playMusic: current.playMusic.copyWith(defaultQuality: value),
      ),
    );
  }

  Future<void> setPlayWhenQualityMissing(String value) {
    final current = state.valueOrNull ?? AppSettings.defaults;
    return _save(
      current.copyWith(
        playMusic: current.playMusic.copyWith(whenQualityMissing: value),
      ),
    );
  }

  Future<void> setPlayClickMusicList(String value) {
    final current = state.valueOrNull ?? AppSettings.defaults;
    return _save(
      current.copyWith(
        playMusic: current.playMusic.copyWith(clickMusicList: value),
      ),
    );
  }

  Future<void> setDownloadPath(String? value) {
    final current = state.valueOrNull ?? AppSettings.defaults;
    return _save(
      current.copyWith(
        download: current.download.copyWith(
          path: value?.trim(),
          clearPath: value == null || value.trim().isEmpty,
        ),
      ),
    );
  }

  Future<void> setDownloadConcurrency(int value) {
    final current = state.valueOrNull ?? AppSettings.defaults;
    return _save(
      current.copyWith(download: current.download.copyWith(concurrency: value)),
    );
  }

  Future<void> setDownloadDefaultQuality(String value) {
    final current = state.valueOrNull ?? AppSettings.defaults;
    return _save(
      current.copyWith(
        download: current.download.copyWith(defaultQuality: value),
      ),
    );
  }

  Future<void> setDownloadWhenQualityMissing(String value) {
    final current = state.valueOrNull ?? AppSettings.defaults;
    return _save(
      current.copyWith(
        download: current.download.copyWith(whenQualityMissing: value),
      ),
    );
  }

  Future<void> setDesktopLyricEnabled(bool value) {
    final current = state.valueOrNull ?? AppSettings.defaults;
    return _save(
      current.copyWith(
        lyric: current.lyric.copyWith(enableDesktopLyric: value),
      ),
    );
  }

  Future<void> setPluginAutoUpdate(bool value) {
    final current = state.valueOrNull ?? AppSettings.defaults;
    return _save(
      current.copyWith(
        plugin: current.plugin.copyWith(autoUpdatePlugin: value),
      ),
    );
  }

  Future<void> setPluginSkipVersionCheck(bool value) {
    final current = state.valueOrNull ?? AppSettings.defaults;
    return _save(
      current.copyWith(
        plugin: current.plugin.copyWith(notCheckPluginVersion: value),
      ),
    );
  }

  Future<void> setCacheMaxSizeMb(int value) {
    final current = state.valueOrNull ?? AppSettings.defaults;
    return _save(
      current.copyWith(cache: current.cache.copyWith(maxSizeMb: value)),
    );
  }

  Future<void> _save(AppSettings next) async {
    state = AsyncData(next);
    final store = _store;
    if (store == null) {
      return;
    }
    final raw = await store.readObject();
    raw.addAll(next.toJson());
    await store.writeJson(raw);
    _startCacheMaintenance(next);
    await _maintainCache(next);
  }

  void _startCacheMaintenance(AppSettings settings) {
    _cacheMaintenanceTimer?.cancel();
    _cacheMaintenanceTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      unawaited(_maintainCache(settings));
    });
  }

  Future<void> _maintainCache(AppSettings settings) async {
    final cacheManager = _cacheManager;
    if (cacheManager == null || _cacheMaintenanceRunning) {
      return;
    }
    _cacheMaintenanceRunning = true;
    try {
      await cacheManager.enforceLimit(
        maxBytes: settings.cache.maxSizeMb * 1024 * 1024,
      );
    } finally {
      _cacheMaintenanceRunning = false;
    }
  }
}

final appSettingsControllerProvider =
    AsyncNotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );
