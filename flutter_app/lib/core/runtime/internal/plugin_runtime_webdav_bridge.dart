import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class PluginRuntimeWebDavBridge {
  PluginRuntimeWebDavBridge({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<String> handle(dynamic args) async {
    final payload = _readObject(args);
    final action = payload['action']?.toString() ?? '';
    try {
      switch (action) {
        case 'getDirectoryContents':
          return jsonEncode(<String, dynamic>{
            'value': await _getDirectoryContents(
              baseUrl: payload['baseUrl']?.toString() ?? '',
              path: payload['path']?.toString() ?? '/',
              username: payload['username']?.toString() ?? '',
              password: payload['password']?.toString() ?? '',
            ),
          });
        case 'getFileDownloadLink':
          return jsonEncode(<String, dynamic>{
            'value': _getFileDownloadLink(
              baseUrl: payload['baseUrl']?.toString() ?? '',
              remotePath: payload['path']?.toString() ?? '',
              username: payload['username']?.toString() ?? '',
              password: payload['password']?.toString() ?? '',
            ),
          });
        case 'getFileContents':
          return jsonEncode(<String, dynamic>{
            'value': await _getFileContents(
              baseUrl: payload['baseUrl']?.toString() ?? '',
              remotePath: payload['path']?.toString() ?? '',
              username: payload['username']?.toString() ?? '',
              password: payload['password']?.toString() ?? '',
              format: (payload['format']?.toString() ?? 'binary'),
            ),
          });
        case 'putFileContents':
          return jsonEncode(<String, dynamic>{
            'value': await _putFileContents(
              baseUrl: payload['baseUrl']?.toString() ?? '',
              remotePath: payload['path']?.toString() ?? '',
              username: payload['username']?.toString() ?? '',
              password: payload['password']?.toString() ?? '',
              data: payload['data'],
              overwrite: payload['overwrite'] as bool? ?? true,
            ),
          });
        case 'createDirectory':
          return jsonEncode(<String, dynamic>{
            'value': await _sendSimple(
              method: 'MKCOL',
              baseUrl: payload['baseUrl']?.toString() ?? '',
              remotePath: payload['path']?.toString() ?? '',
              username: payload['username']?.toString() ?? '',
              password: payload['password']?.toString() ?? '',
            ),
          });
        case 'exists':
          return jsonEncode(<String, dynamic>{
            'value': await _exists(
              baseUrl: payload['baseUrl']?.toString() ?? '',
              remotePath: payload['path']?.toString() ?? '',
              username: payload['username']?.toString() ?? '',
              password: payload['password']?.toString() ?? '',
            ),
          });
        case 'stat':
          return jsonEncode(<String, dynamic>{
            'value': await _stat(
              baseUrl: payload['baseUrl']?.toString() ?? '',
              remotePath: payload['path']?.toString() ?? '',
              username: payload['username']?.toString() ?? '',
              password: payload['password']?.toString() ?? '',
            ),
          });
        case 'moveFile':
          return jsonEncode(<String, dynamic>{
            'value': await _sendMoveOrCopy(
              method: 'MOVE',
              payload: payload,
            ),
          });
        case 'copyFile':
          return jsonEncode(<String, dynamic>{
            'value': await _sendMoveOrCopy(
              method: 'COPY',
              payload: payload,
            ),
          });
        case 'deleteFile':
          return jsonEncode(<String, dynamic>{
            'value': await _sendSimple(
              method: 'DELETE',
              baseUrl: payload['baseUrl']?.toString() ?? '',
              remotePath: payload['path']?.toString() ?? '',
              username: payload['username']?.toString() ?? '',
              password: payload['password']?.toString() ?? '',
            ),
          });
        default:
          return jsonEncode(<String, dynamic>{
            'error': 'Unknown webdav action: $action',
          });
      }
    } catch (error, stackTrace) {
      return jsonEncode(<String, dynamic>{
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getDirectoryContents({
    required String baseUrl,
    required String path,
    required String username,
    required String password,
  }) async {
    final uri = _resolveUri(baseUrl, path);
    final request = http.Request('PROPFIND', uri)
      ..headers.addAll(<String, String>{
        'Depth': '1',
        'Content-Type': 'application/xml; charset=utf-8',
        ..._buildAuthHeaders(username, password),
      })
      ..body = '''<?xml version="1.0" encoding="utf-8" ?>
<propfind xmlns="DAV:">
  <prop>
    <displayname />
    <getcontenttype />
    <getcontentlength />
    <getlastmodified />
    <resourcetype />
  </prop>
</propfind>''';
    final response = await _sendRequest(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('WebDAV PROPFIND failed: HTTP ${response.statusCode}');
    }

    final document = XmlDocument.parse(response.body);
    final responses = document.findAllElements('response', namespace: 'DAV:');
    final normalizedPath = _normalizeRemotePath(path);

    return responses
        .map((node) {
          final href = _readNodeText(node, 'href');
          final isDirectory =
              node.findAllElements('collection', namespace: 'DAV:').isNotEmpty;
          final filename = Uri.decodeFull(href);
          final basename =
              filename.split('/').where((part) => part.isNotEmpty).lastOrNull ??
              '';
          final mime = _readNodeText(node, 'getcontenttype');
          final length =
              int.tryParse(_readNodeText(node, 'getcontentlength')) ?? 0;
          final lastModifiedRaw = _readNodeText(node, 'getlastmodified');
          return <String, dynamic>{
            'filename': filename,
            'basename': basename,
            'type': isDirectory ? 'directory' : 'file',
            'mime': mime.isEmpty && !isDirectory
                ? 'application/octet-stream'
                : mime,
            'size': length,
            'lastmod': lastModifiedRaw,
            '_normalizedPath': _trimTrailingSlash(filename),
          };
        })
        .where((item) {
          final normalizedFilename = item['_normalizedPath']?.toString() ?? '';
          return normalizedFilename.isNotEmpty &&
              normalizedFilename != _trimTrailingSlash(normalizedPath);
        })
        .map((item) {
          final next = Map<String, dynamic>.from(item);
          next.remove('_normalizedPath');
          return next;
        })
        .toList(growable: false);
  }

  Future<dynamic> _getFileContents({
    required String baseUrl,
    required String remotePath,
    required String username,
    required String password,
    required String format,
  }) async {
    final uri = _resolveUri(baseUrl, remotePath);
    final request = http.Request('GET', uri)
      ..headers.addAll(_buildAuthHeaders(username, password));
    final response = await _sendRequest(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'WebDAV GET failed for $remotePath: HTTP ${response.statusCode}',
      );
    }
    if (format == 'text') {
      return response.body;
    }
    return response.bodyBytes.toList(growable: false);
  }

  Future<bool> _putFileContents({
    required String baseUrl,
    required String remotePath,
    required String username,
    required String password,
    required dynamic data,
    required bool overwrite,
  }) async {
    final uri = _resolveUri(baseUrl, remotePath);
    final request = http.Request('PUT', uri)
      ..headers.addAll(<String, String>{
        ..._buildAuthHeaders(username, password),
        if (!overwrite) 'If-None-Match': '*',
      });
    if (data is String) {
      request.body = data;
    } else if (data is List) {
      request.bodyBytes = Uint8List.fromList(
        data.map((e) => (e as num).toInt() & 0xFF).toList(growable: false),
      );
    } else if (data != null) {
      request.body = jsonEncode(data);
    }
    final response = await _sendRequest(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'WebDAV PUT failed for $remotePath: HTTP ${response.statusCode}',
      );
    }
    return true;
  }

  Future<bool> _sendSimple({
    required String method,
    required String baseUrl,
    required String remotePath,
    required String username,
    required String password,
  }) async {
    final uri = _resolveUri(baseUrl, remotePath);
    final request = http.Request(method, uri)
      ..headers.addAll(_buildAuthHeaders(username, password));
    final response = await _sendRequest(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'WebDAV $method failed for $remotePath: HTTP ${response.statusCode}',
      );
    }
    return true;
  }

  Future<bool> _sendMoveOrCopy({
    required String method,
    required Map<String, dynamic> payload,
  }) async {
    final baseUrl = payload['baseUrl']?.toString() ?? '';
    final from = payload['path']?.toString() ?? '';
    final to = payload['destination']?.toString() ?? '';
    final username = payload['username']?.toString() ?? '';
    final password = payload['password']?.toString() ?? '';
    final uri = _resolveUri(baseUrl, from);
    final destinationUri = _resolveUri(baseUrl, to);
    final request = http.Request(method, uri)
      ..headers.addAll(<String, String>{
        ..._buildAuthHeaders(username, password),
        'Destination': destinationUri.toString(),
        'Overwrite': 'T',
      });
    final response = await _sendRequest(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'WebDAV $method failed for $from -> $to: HTTP ${response.statusCode}',
      );
    }
    return true;
  }

  Future<bool> _exists({
    required String baseUrl,
    required String remotePath,
    required String username,
    required String password,
  }) async {
    try {
      await _stat(
        baseUrl: baseUrl,
        remotePath: remotePath,
        username: username,
        password: password,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> _stat({
    required String baseUrl,
    required String remotePath,
    required String username,
    required String password,
  }) async {
    final uri = _resolveUri(baseUrl, remotePath);
    final request = http.Request('PROPFIND', uri)
      ..headers.addAll(<String, String>{
        'Depth': '0',
        'Content-Type': 'application/xml; charset=utf-8',
        ..._buildAuthHeaders(username, password),
      })
      ..body = '''<?xml version="1.0" encoding="utf-8" ?>
<propfind xmlns="DAV:"><prop><displayname/><resourcetype/><getcontenttype/><getcontentlength/><getlastmodified/></prop></propfind>''';
    final response = await _sendRequest(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'WebDAV PROPFIND failed for $remotePath: HTTP ${response.statusCode}',
      );
    }
    final document = XmlDocument.parse(response.body);
    final node = document.findAllElements('response', namespace: 'DAV:').firstOrNull;
    if (node == null) return null;
    final href = _readNodeText(node, 'href');
    final isDirectory =
        node.findAllElements('collection', namespace: 'DAV:').isNotEmpty;
    return <String, dynamic>{
      'filename': Uri.decodeFull(href),
      'type': isDirectory ? 'directory' : 'file',
      'mime': _readNodeText(node, 'getcontenttype'),
      'size': int.tryParse(_readNodeText(node, 'getcontentlength')) ?? 0,
      'lastmod': _readNodeText(node, 'getlastmodified'),
    };
  }

  Future<http.Response> _sendRequest(http.Request request) async {
    final client = _client ?? http.Client();
    try {
      final streamed = await client.send(request);
      return http.Response.fromStream(streamed);
    } finally {
      if (_client == null) client.close();
    }
  }

  String _getFileDownloadLink({
    required String baseUrl,
    required String remotePath,
    required String username,
    required String password,
  }) {
    final uri = _resolveUri(baseUrl, remotePath);
    if (username.isEmpty || password.isEmpty) return uri.toString();
    return uri.replace(userInfo: '$username:$password').toString();
  }

  Uri _resolveUri(String baseUrl, String remotePath) {
    final base = Uri.parse(baseUrl);
    final normalizedPath = _normalizeRemotePath(remotePath);
    return base.resolve(
      normalizedPath.startsWith('/')
          ? normalizedPath.substring(1)
          : normalizedPath,
    );
  }

  String _normalizeRemotePath(String path) {
    if (path.isEmpty) return '/';
    return path.startsWith('/') ? path : '/$path';
  }

  String _trimTrailingSlash(String value) {
    if (value.endsWith('/') && value.length > 1) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }

  String _readNodeText(XmlElement root, String localName) {
    final match = root
        .findAllElements(localName, namespace: 'DAV:')
        .firstOrNull;
    return match?.innerText.trim() ?? '';
  }

  Map<String, String> _buildAuthHeaders(String username, String password) {
    if (username.isEmpty && password.isEmpty) {
      return const <String, String>{};
    }
    final token = base64Encode(utf8.encode('$username:$password'));
    return <String, String>{'Authorization': 'Basic $token'};
  }

  Map<String, dynamic> _readObject(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    return <String, dynamic>{};
  }
}
