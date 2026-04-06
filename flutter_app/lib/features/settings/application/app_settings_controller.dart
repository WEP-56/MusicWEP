import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/json_file_store.dart';
import '../../plugins/plugin_providers.dart';
import '../domain/app_settings.dart';

class AppSettingsController extends AsyncNotifier<AppSettings> {
  JsonFileStore? _store;

  @override
  Future<AppSettings> build() async {
    final appPaths = await ref.watch(appPathsProvider.future);
    _store = JsonFileStore(appPaths.configFilePath);
    final raw = await _store!.readObject();
    return AppSettings.fromJson(raw);
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

  Future<void> _save(AppSettings next) async {
    state = AsyncData(next);
    final store = _store;
    if (store == null) {
      return;
    }
    final raw = await store.readObject();
    raw.addAll(next.toJson());
    await store.writeJson(raw);
  }
}

final appSettingsControllerProvider =
    AsyncNotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );
