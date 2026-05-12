import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:flutter_app/core/runtime/internal/plugin_runtime_cookie_store.dart';
import 'package:flutter_app/core/storage/json_file_store.dart';

void main() {
  group('PluginRuntimeCookieStore', () {
    late Directory tempRoot;
    late PluginRuntimeCookieStore store;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp(
        'musicfree_cookie_store_',
      );
      final jsonPath = path.join(tempRoot.path, 'cookies.json');
      store = PluginRuntimeCookieStore(JsonFileStore(jsonPath));
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('keeps (domain, path, name) uniqueness when setting cookies', () async {
      await store.setCookie(const PluginRuntimeCookie(
        name: 'sid',
        value: 'one',
        domain: 'example.com',
        path: '/',
      ));
      await store.setCookie(const PluginRuntimeCookie(
        name: 'sid',
        value: 'two',
        domain: 'example.com',
        path: '/app',
      ));
      await store.setCookie(const PluginRuntimeCookie(
        name: 'sid',
        value: 'three',
        domain: 'other.com',
        path: '/',
      ));

      final matches = await store.matchFor(Uri.parse('https://example.com/app/page'));
      expect(matches.map((c) => c.value).toSet(), {'one', 'two'});
    });

    test('builds a Cookie header for matching domain and path', () async {
      await store.setCookie(const PluginRuntimeCookie(
        name: 'token',
        value: 'abc',
        domain: 'example.com',
        path: '/',
      ));
      final header = await store.buildCookieHeader(
        Uri.parse('https://example.com/home'),
      );
      expect(header, 'token=abc');
    });

    test('ingests Set-Cookie headers from a response', () async {
      await store.ingestSetCookies(
        requestUri: Uri.parse('https://api.example.com/v1/login'),
        responseHeaders: <String, String>{
          'set-cookie':
              'session=xyz; Path=/; HttpOnly, csrf=qrs; Path=/; Secure',
        },
      );
      final uri = Uri.parse('https://api.example.com/v1/me');
      final matches = await store.matchFor(uri);
      expect(matches, hasLength(2));
      final names = matches.map((c) => c.name).toSet();
      expect(names, {'session', 'csrf'});
      final secureCookie = matches.firstWhere((c) => c.name == 'csrf');
      expect(secureCookie.secure, isTrue);
    });

    test('excludes secure cookies when the request is plain http', () async {
      await store.ingestSetCookies(
        requestUri: Uri.parse('https://example.com/login'),
        responseHeaders: <String, String>{
          'set-cookie': 'locked=1; Path=/; Secure',
        },
      );
      final https = await store.matchFor(Uri.parse('https://example.com/'));
      final http = await store.matchFor(Uri.parse('http://example.com/'));
      expect(https.map((c) => c.name), contains('locked'));
      expect(http.map((c) => c.name), isNot(contains('locked')));
    });

    test('migrates legacy {url: {name: cookie}} schema on first load', () async {
      // Write a legacy payload directly and make sure loadAll normalises it.
      final jsonPath = path.join(tempRoot.path, 'legacy.json');
      final legacyStore = JsonFileStore(jsonPath);
      await legacyStore.writeJson(<String, dynamic>{
        'https://example.com': <String, dynamic>{
          'sid': <String, dynamic>{
            'name': 'sid',
            'value': 'legacy',
          },
        },
      });
      final migrated = PluginRuntimeCookieStore(legacyStore);
      final matches = await migrated.matchFor(
        Uri.parse('https://example.com/home'),
      );
      expect(matches.single.name, 'sid');
      expect(matches.single.value, 'legacy');
    });
  });
}
