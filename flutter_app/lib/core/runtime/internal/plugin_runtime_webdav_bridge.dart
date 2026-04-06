import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class PluginRuntimeWebDavBridge {
  Future<String> handle(dynamic args) async {
    final payload = _readObject(args);
    final action = payload['action']?.toString() ?? '';

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
      default:
        return jsonEncode(<String, dynamic>{
          'error': 'Unknown webdav action: $action',
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
    <resourcetype />
  </prop>
</propfind>''';
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('WebDAV PROPFIND failed: HTTP ${response.statusCode}');
    }

    final document = XmlDocument.parse(response.body);
    final responses = document.findAllElements('response', namespace: 'DAV:');
    final normalizedPath = _normalizeRemotePath(path);

    return responses
        .map((node) {
          final href = _readNodeText(node, 'href');
          final typeNode =
              node.findAllElements('collection', namespace: 'DAV:').isNotEmpty
              ? 'directory'
              : 'file';
          final filename = Uri.decodeFull(href);
          final basename =
              filename.split('/').where((part) => part.isNotEmpty).lastOrNull ??
              '';
          final mime = _readNodeText(node, 'getcontenttype');
          return <String, dynamic>{
            'filename': filename,
            'basename': basename,
            'mime': mime.isEmpty && typeNode == 'file'
                ? 'application/octet-stream'
                : mime,
            'type': typeNode,
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

  String _getFileDownloadLink({
    required String baseUrl,
    required String remotePath,
    required String username,
    required String password,
  }) {
    final uri = _resolveUri(baseUrl, remotePath);
    if (username.isEmpty || password.isEmpty) {
      return uri.toString();
    }
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
    if (path.isEmpty) {
      return '/';
    }
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
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    return <String, dynamic>{};
  }
}
