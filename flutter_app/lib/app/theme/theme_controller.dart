import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/json_file_store.dart';
import '../../features/plugins/plugin_providers.dart';
import 'app_theme.dart';

class ThemeController extends AsyncNotifier<AppThemeSettings> {
  JsonFileStore? _store;

  @override
  Future<AppThemeSettings> build() async {
    final appPaths = await ref.watch(appPathsProvider.future);
    _store = JsonFileStore(appPaths.configFilePath);
    final raw = await _store!.readObject();
    final theme = raw['theme'];
    return AppThemeSettings.fromJson(
      theme is Map<String, dynamic>
          ? theme
          : theme is Map
          ? theme.map((key, value) => MapEntry(key.toString(), value))
          : null,
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    await _save(
      (state.valueOrNull ?? AppThemeSettings.defaults).copyWith(mode: mode),
    );
  }

  Future<void> setPreset(String presetId) async {
    await _save(
      (state.valueOrNull ?? AppThemeSettings.defaults).copyWith(
        presetId: presetId,
      ),
    );
  }

  Future<void> _save(AppThemeSettings next) async {
    state = AsyncData(next);
    final store = _store;
    if (store == null) {
      return;
    }
    final raw = await store.readObject();
    raw['theme'] = next.toJson();
    await store.writeJson(raw);
  }
}

final appThemeControllerProvider =
    AsyncNotifierProvider<ThemeController, AppThemeSettings>(
      ThemeController.new,
    );
