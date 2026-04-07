import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../core/filesystem/app_paths.dart';
import '../../core/storage/json_file_store.dart';
import '../../features/plugins/plugin_providers.dart';
import 'app_theme.dart';

class ThemeController extends AsyncNotifier<AppThemeSettings> {
  JsonFileStore? _store;
  AppPaths? _appPaths;

  @override
  Future<AppThemeSettings> build() async {
    final appPaths = await ref.watch(appPathsProvider.future);
    _appPaths = appPaths;
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

  Future<void> setTheme(String themeId) async {
    final current = state.valueOrNull ?? AppThemeSettings.defaults;
    await _save(current.copyWith(activeThemeId: themeId));
  }

  Future<String> saveCustomTheme({
    String? themeId,
    required String name,
    required Color seedColor,
    String? backgroundSourcePath,
    bool clearBackground = false,
    bool activate = true,
  }) async {
    final current = state.valueOrNull ?? AppThemeSettings.defaults;
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw StateError('Theme name is required');
    }

    final effectiveThemeId = themeId?.trim().isNotEmpty == true
        ? themeId!.trim()
        : 'custom-theme-${DateTime.now().microsecondsSinceEpoch}';
    final existingTheme = current.customThemes.firstWhereOrNull(
      (theme) => theme.id == effectiveThemeId,
    );

    AppThemeBackgroundData? background = existingTheme?.background;
    if (clearBackground) {
      await _deleteThemeAsset(background?.relativePath);
      background = null;
    }

    if (backgroundSourcePath != null &&
        backgroundSourcePath.trim().isNotEmpty) {
      final copiedBackground = await _copyBackgroundAsset(
        themeId: effectiveThemeId,
        sourcePath: backgroundSourcePath,
      );
      if (background != null &&
          background.relativePath != copiedBackground.relativePath) {
        await _deleteThemeAsset(background.relativePath);
      }
      background = copiedBackground;
    }

    final nextTheme = AppCustomThemeData(
      id: effectiveThemeId,
      name: normalizedName,
      seedColorValue: seedColor.toARGB32(),
      background: background,
    );
    final nextThemes = <AppCustomThemeData>[
      for (final item in current.customThemes)
        if (item.id == effectiveThemeId) nextTheme else item,
      if (current.customThemes.every((item) => item.id != effectiveThemeId))
        nextTheme,
    ];

    await _save(
      current.copyWith(
        activeThemeId: activate ? effectiveThemeId : current.activeThemeId,
        customThemes: nextThemes,
      ),
    );
    return effectiveThemeId;
  }

  Future<void> deleteCustomTheme(String themeId) async {
    final current = state.valueOrNull ?? AppThemeSettings.defaults;
    final removedTheme = current.customThemes.firstWhereOrNull(
      (theme) => theme.id == themeId,
    );
    if (removedTheme == null) {
      return;
    }

    await _deleteThemeAsset(removedTheme.background?.relativePath);
    final nextThemes = current.customThemes
        .where((theme) => theme.id != themeId)
        .toList(growable: false);
    final fallbackActiveThemeId = current.activeThemeId == themeId
        ? (nextThemes.isNotEmpty
              ? nextThemes.first.id
              : AppThemePreset.sunset.id)
        : current.activeThemeId;
    await _save(
      current.copyWith(
        activeThemeId: fallbackActiveThemeId,
        customThemes: nextThemes,
      ),
    );
  }

  Future<AppThemeBackgroundData> _copyBackgroundAsset({
    required String themeId,
    required String sourcePath,
  }) async {
    final appPaths = _appPaths;
    if (appPaths == null) {
      throw StateError('App paths are not initialized');
    }

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw StateError('Background asset not found');
    }

    final type = AppThemeBackgroundType.fromPath(sourcePath);
    if (type == null) {
      throw StateError('Unsupported background format');
    }

    final themeAssetsDirectory = Directory(
      path.join(appPaths.appDataDirectory.path, 'theme_assets', themeId),
    );
    if (await themeAssetsDirectory.exists()) {
      await themeAssetsDirectory.delete(recursive: true);
    }
    await themeAssetsDirectory.create(recursive: true);

    final extension = path.extension(sourceFile.path).toLowerCase();
    final targetFile = File(
      path.join(themeAssetsDirectory.path, 'background$extension'),
    );
    await sourceFile.copy(targetFile.path);

    return AppThemeBackgroundData(
      type: type,
      relativePath: path.relative(
        targetFile.path,
        from: appPaths.appDataDirectory.path,
      ),
    );
  }

  Future<void> _deleteThemeAsset(String? relativePath) async {
    final appPaths = _appPaths;
    if (appPaths == null ||
        relativePath == null ||
        relativePath.trim().isEmpty) {
      return;
    }

    final assetFile = File(
      path.join(appPaths.appDataDirectory.path, relativePath),
    );
    if (await assetFile.exists()) {
      final assetDirectory = assetFile.parent;
      await assetFile.delete();
      if (await assetDirectory.exists() &&
          (await assetDirectory.list().isEmpty)) {
        await assetDirectory.delete(recursive: true);
      }
    }
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

extension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T item) test) {
    for (final item in this) {
      if (test(item)) {
        return item;
      }
    }
    return null;
  }
}
