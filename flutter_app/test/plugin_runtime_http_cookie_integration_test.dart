import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:flutter_app/core/runtime/internal/plugin_runtime_cookie_store.dart';
import 'package:flutter_app/core/runtime/internal/plugin_runtime_http_bridge.dart';
import 'package:flutter_app/core/storage/json_file_store.dart';

/// Exercises the end-to-end cookie round-trip between the HTTP bridge and
/// the shared cookie store.
void main() {
  group('PluginRuntimeHttpBridge cookie round-trip', () {
    late Directory tempRoot;
    late HttpServer server;
    late PluginRuntimeCookieStore cookieStore;
    late PluginRuntimeHttpBridge bridge;
    final receivedCookies = <String>[];

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp(
        'musicfree_http_cookie_',
      );
      cookieStore = PluginRuntimeCookieStore(
        JsonFileStore(path.join(tempRoot.path, 'cookies.json')),
      );
      bridge = PluginRuntimeHttpBridge(cookieStore: cookieStore);
      receivedCookies.clear();

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        receivedCookies.add(request.headers.value('cookie') ?? '');
        if (request.uri.path == '/login') {
          request.response
            ..headers.add('set-cookie', 'sid=abc123; Path=/')
            ..write('ok');
        } else {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, dynamic>{
              'seenCookie': request.headers.value('cookie'),
            }));
        }
        await request.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('Set-Cookie on login flows back into subsequent requests', () async {
      final baseUrl = 'http://${server.address.host}:${server.port}';

      // First request: login. No cookie yet.
      await bridge.handle(<String, dynamic>{
        'action': 'request',
        'method': 'GET',
        'url': '$baseUrl/login',
      });

      // Second request: the store should now attach `sid=abc123`.
      final second = await bridge.handle(<String, dynamic>{
        'action': 'request',
        'method': 'GET',
        'url': '$baseUrl/me',
      });

      expect(receivedCookies[0], isEmpty);
      expect(receivedCookies[1], contains('sid=abc123'));

      final decoded = jsonDecode(second) as Map<String, dynamic>;
      final payload = decoded['data'] as Map<String, dynamic>;
      expect(payload['seenCookie'], 'sid=abc123');
    });

    test('plugin-supplied Cookie header is merged with stored cookies', () async {
      final baseUrl = 'http://${server.address.host}:${server.port}';
      await bridge.handle(<String, dynamic>{
        'action': 'request',
        'method': 'GET',
        'url': '$baseUrl/login',
      });

      await bridge.handle(<String, dynamic>{
        'action': 'request',
        'method': 'GET',
        'url': '$baseUrl/me',
        'headers': <String, String>{'Cookie': 'manual=1'},
      });

      expect(receivedCookies[1], contains('manual=1'));
      expect(receivedCookies[1], contains('sid=abc123'));
    });
  });
}
