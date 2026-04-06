import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import '../../../core/media/media_constants.dart';
import '../../../core/media/media_models.dart';
import '../domain/plugin_method_models.dart';

class LocalPluginService {
  const LocalPluginService();

  Future<MusicItem> importMusicItem(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Local file not found: $filePath');
    }

    return MusicItem(
      title: path.basenameWithoutExtension(filePath),
      artist: '未知作者',
      album: '未知专辑',
      url: file.uri.toString(),
      localPath: filePath,
      platform: localPluginName,
      id: md5.convert(utf8.encode(filePath)).toString(),
    );
  }

  Future<List<MusicItem>> importMusicSheet(String folderPath) async {
    final directory = Directory(folderPath);
    if (!await directory.exists()) {
      throw Exception('Local folder not found: $folderPath');
    }

    final files = await directory
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    final audioFiles = files
        .where((file) {
          final extension = path.extension(file.path).toLowerCase();
          return supportedLocalMediaTypes.contains(extension);
        })
        .toList(growable: false);

    final items = <MusicItem>[];
    for (final file in audioFiles) {
      items.add(await importMusicItem(file.path));
    }
    return items;
  }

  Future<PluginMediaSourceResult?> getMediaSource(
    MusicItem musicItem, {
    String quality = 'standard',
  }) async {
    final qualityUrl = musicItem.qualities[quality]?['url']?.toString();
    if (qualityUrl != null && qualityUrl.isNotEmpty) {
      return PluginMediaSourceResult(url: qualityUrl, quality: quality);
    }

    final url = musicItem.url;
    if (url == null || url.isEmpty) {
      return null;
    }
    return PluginMediaSourceResult(
      url: url.startsWith('file:') ? url : Uri.file(url).toString(),
      quality: quality,
    );
  }

  Future<PluginLyricResult?> getLyric(MusicItem musicItem) async {
    if (musicItem.rawLyric != null && musicItem.rawLyric!.isNotEmpty) {
      return PluginLyricResult(
        lyricUrl: musicItem.lyricUrl,
        rawLyric: musicItem.rawLyric,
      );
    }

    final localPath =
        musicItem.localPath ??
        musicItem.extra[r'$$localPath']?.toString() ??
        ((musicItem.extra[r'$'] is Map)
            ? (musicItem.extra[r'$']['downloadData']?['path']?.toString())
            : null);
    if (localPath == null || localPath.isEmpty) {
      return null;
    }

    final fileName = path.basenameWithoutExtension(localPath);
    final basePath = path.join(path.dirname(localPath), fileName);
    const extensions = <String>['.lrc', '.LRC', '.txt'];

    for (final extension in extensions) {
      final lyricFile = File('$basePath$extension');
      if (!await lyricFile.exists()) {
        continue;
      }
      final translationFile = File('$basePath-tr$extension');
      return PluginLyricResult(
        lyricUrl: musicItem.lyricUrl,
        rawLyric: await lyricFile.readAsString(),
        translation: await translationFile.exists()
            ? await translationFile.readAsString()
            : null,
      );
    }

    return null;
  }
}
