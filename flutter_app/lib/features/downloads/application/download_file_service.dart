import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import '../../plugins/domain/plugin_method_models.dart';

typedef DownloadProgressCallback = void Function(int downloaded, int? total);

class DownloadFileService {
  const DownloadFileService();

  Future<void> download({
    required PluginMediaSourceResult mediaSource,
    required String filePath,
    DownloadProgressCallback? onProgress,
    void Function(String message)? onLog,
  }) async {
    final targetFile = File(filePath);
    if (!await targetFile.parent.exists()) {
      await targetFile.parent.create(recursive: true);
    }

    final requestUri = Uri.parse(mediaSource.url);
    final sanitizedUri = requestUri.userInfo.isEmpty
        ? requestUri
        : requestUri.replace(userInfo: '');
    final request = http.Request('GET', sanitizedUri);
    request.headers.addAll(mediaSource.headers);
    if (mediaSource.userAgent?.trim().isNotEmpty == true) {
      request.headers['user-agent'] = mediaSource.userAgent!.trim();
    }
    final authorization = _buildAuthorizationHeader(requestUri);
    if (authorization != null && authorization.isNotEmpty) {
      request.headers['authorization'] = authorization;
    }

    final client = http.Client();
    IOSink? sink;
    try {
      onLog?.call('request start url=${sanitizedUri.toString()}');
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}', uri: sanitizedUri);
      }
      onLog?.call('response status=${response.statusCode}');

      final contentLength = response.contentLength;
      final total = contentLength != null && contentLength > 0
          ? contentLength
          : null;
      var downloaded = 0;
      onProgress?.call(0, total);

      sink = targetFile.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        onProgress?.call(downloaded, total);
      }
      await sink.flush();
      onLog?.call('stream completed bytes=$downloaded total=${total ?? -1}');
    } catch (error) {
      onLog?.call('download failed error=$error file=$filePath');
      await _cleanup(targetFile);
      rethrow;
    } finally {
      await sink?.close();
      client.close();
    }
  }

  String sanitizeFileName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return sanitized.isEmpty ? 'music' : sanitized;
  }

  String resolveFileExtension(PluginMediaSourceResult mediaSource) {
    try {
      final uri = Uri.parse(mediaSource.url);
      final extension = path.extension(uri.path).trim();
      if (extension.isEmpty || extension.length > 8) {
        return '.mp3';
      }
      return extension;
    } catch (_) {
      return '.mp3';
    }
  }

  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    await _cleanup(file);
  }

  String? _buildAuthorizationHeader(Uri uri) {
    if (uri.userInfo.isEmpty) {
      return null;
    }
    final parts = uri.userInfo.split(':');
    final username = Uri.decodeComponent(parts.first);
    final password = Uri.decodeComponent(
      parts.length > 1 ? parts.sublist(1).join(':') : '',
    );
    final encoded = base64Encode(utf8.encode('$username:$password'));
    return 'Basic $encoded';
  }

  Future<void> _cleanup(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
