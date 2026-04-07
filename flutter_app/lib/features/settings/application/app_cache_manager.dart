import 'dart:io';

import '../../../core/filesystem/app_paths.dart';

class AppCacheManager {
  const AppCacheManager(this._appPaths);

  final AppPaths _appPaths;

  Directory get _cacheDirectory => _appPaths.cacheDirectory;

  Future<int> getCacheSizeBytes() async {
    if (!await _cacheDirectory.exists()) {
      return 0;
    }

    var total = 0;
    await for (final entity in _cacheDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      try {
        total += await entity.length();
      } catch (_) {
        // Ignore transient files.
      }
    }
    return total;
  }

  Future<void> clearCache() async {
    if (!await _cacheDirectory.exists()) {
      await _cacheDirectory.create(recursive: true);
      return;
    }

    await for (final entity in _cacheDirectory.list(
      recursive: false,
      followLinks: false,
    )) {
      try {
        await entity.delete(recursive: true);
      } catch (_) {
        // Skip locked files; best-effort cleanup is enough.
      }
    }

    if (!await _cacheDirectory.exists()) {
      await _cacheDirectory.create(recursive: true);
    }
  }

  Future<void> enforceLimit({required int maxBytes}) async {
    if (maxBytes <= 0 || !await _cacheDirectory.exists()) {
      return;
    }

    final files = <_CacheFileEntry>[];
    var totalBytes = 0;

    await for (final entity in _cacheDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      try {
        final stat = await entity.stat();
        totalBytes += stat.size;
        files.add(
          _CacheFileEntry(
            file: entity,
            sizeBytes: stat.size,
            modified: stat.modified,
          ),
        );
      } catch (_) {
        // Ignore transient files.
      }
    }

    if (totalBytes <= maxBytes) {
      return;
    }

    files.sort((left, right) => left.modified.compareTo(right.modified));
    for (final entry in files) {
      if (totalBytes <= maxBytes) {
        break;
      }
      try {
        if (await entry.file.exists()) {
          await entry.file.delete();
          totalBytes -= entry.sizeBytes;
        }
      } catch (_) {
        // Continue with remaining files.
      }
    }

    await _pruneEmptyDirectories();
  }

  Future<void> _pruneEmptyDirectories() async {
    if (!await _cacheDirectory.exists()) {
      return;
    }

    final directories = <Directory>[];
    await for (final entity in _cacheDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is Directory) {
        directories.add(entity);
      }
    }

    directories.sort(
      (left, right) => right.path.length.compareTo(left.path.length),
    );
    for (final directory in directories) {
      try {
        if (await directory.exists() && await directory.list().isEmpty) {
          await directory.delete();
        }
      } catch (_) {
        // Ignore undeletable directories.
      }
    }
  }
}

class _CacheFileEntry {
  const _CacheFileEntry({
    required this.file,
    required this.sizeBytes,
    required this.modified,
  });

  final File file;
  final int sizeBytes;
  final DateTime modified;
}
