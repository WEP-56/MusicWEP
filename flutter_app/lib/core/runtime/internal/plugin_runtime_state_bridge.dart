import 'dart:convert';

import '../../filesystem/app_paths.dart';
import '../../storage/json_file_store.dart';
import 'plugin_runtime_cookie_store.dart';

class PluginRuntimeStateBridge {
  PluginRuntimeStateBridge(AppPaths appPaths)
    : _storageStore = JsonFileStore(appPaths.pluginStorageFilePath),
      cookieStore = PluginRuntimeCookieStore(
        JsonFileStore(appPaths.pluginCookiesFilePath),
      );

  PluginRuntimeStateBridge.withCookieStore({
    required AppPaths appPaths,
    required this.cookieStore,
  }) : _storageStore = JsonFileStore(appPaths.pluginStorageFilePath);

  static const int _maxStorageBytes = 1024 * 1024 * 10;

  final JsonFileStore _storageStore;
  final PluginRuntimeCookieStore cookieStore;

  Future<String> handleStorage(dynamic args) async {
    final payload = _readObject(args);
    final action = payload['action']?.toString() ?? '';
    final key = payload['key']?.toString() ?? '';

    switch (action) {
      case 'getItem':
        final storage = await _storageStore.readObject();
        return jsonEncode(<String, dynamic>{'value': storage[key]});
      case 'setItem':
        final storage = await _storageStore.readObject();
        storage[key] = payload['value']?.toString();
        final encoded = jsonEncode(storage);
        if (utf8.encode(encoded).length > _maxStorageBytes) {
          throw Exception('Storage size exceeds limit');
        }
        await _storageStore.writeJson(storage);
        return jsonEncode(<String, dynamic>{'ok': true});
      case 'removeItem':
        final storage = await _storageStore.readObject();
        storage.remove(key);
        await _storageStore.writeJson(storage);
        return jsonEncode(<String, dynamic>{'ok': true});
      default:
        return jsonEncode(<String, dynamic>{
          'error': 'Unknown storage action: $action',
        });
    }
  }

  Future<String> handleCookies(dynamic args) async {
    final payload = _readObject(args);
    final action = payload['action']?.toString() ?? '';
    final url = payload['url']?.toString() ?? '';

    switch (action) {
      case 'get':
        final host = _hostOf(url);
        final flat = host.isEmpty
            ? <String, Map<String, dynamic>>{}
            : await cookieStore.flatCookiesForHost(host);
        return jsonEncode(<String, dynamic>{'value': flat});
      case 'getAll':
        final all = await cookieStore.loadAll();
        final encoded = <String, Map<String, Map<String, dynamic>>>{};
        all.forEach((domain, cookies) {
          final nested = <String, Map<String, dynamic>>{};
          cookies.forEach((key, cookie) {
            nested[key] = cookie.toJson();
          });
          encoded[domain] = nested;
        });
        return jsonEncode(<String, dynamic>{'value': encoded});
      case 'set':
        final cookieJson = _readObject(payload['cookie']);
        final name = cookieJson['name']?.toString() ?? '';
        if (name.isEmpty) {
          return jsonEncode(<String, dynamic>{'value': false});
        }
        final cookieDomain = cookieJson['domain']?.toString().isNotEmpty == true
            ? cookieJson['domain']!.toString()
            : _hostOf(url);
        if (cookieDomain.isEmpty) {
          return jsonEncode(<String, dynamic>{'value': false});
        }
        final cookie = PluginRuntimeCookie.fromJson(<String, dynamic>{
          ...cookieJson,
          'domain': cookieDomain,
          'path': cookieJson['path']?.toString().isNotEmpty == true
              ? cookieJson['path']
              : '/',
        });
        await cookieStore.setCookie(cookie);
        return jsonEncode(<String, dynamic>{'value': true});
      case 'clearAll':
        await cookieStore.saveAll(<String, Map<String, PluginRuntimeCookie>>{});
        return jsonEncode(<String, dynamic>{'ok': true});
      case 'clearByName':
        final host = _hostOf(url);
        final name = payload['name']?.toString() ?? '';
        if (host.isEmpty || name.isEmpty) {
          return jsonEncode(<String, dynamic>{'value': false});
        }
        final all = Map<String, Map<String, PluginRuntimeCookie>>.from(
          await cookieStore.loadAll(),
        );
        final bucket = all[host];
        if (bucket != null) {
          final filtered = Map<String, PluginRuntimeCookie>.from(bucket)
            ..removeWhere((key, cookie) => cookie.name == name);
          if (filtered.isEmpty) {
            all.remove(host);
          } else {
            all[host] = filtered;
          }
          await cookieStore.saveAll(all);
        }
        return jsonEncode(<String, dynamic>{'value': true});
      case 'clearByDomain':
        final domain =
            payload['domain']?.toString().toLowerCase() ?? '';
        if (domain.isEmpty) {
          return jsonEncode(<String, dynamic>{'value': false});
        }
        final all = Map<String, Map<String, PluginRuntimeCookie>>.from(
          await cookieStore.loadAll(),
        );
        all.remove(domain);
        await cookieStore.saveAll(all);
        return jsonEncode(<String, dynamic>{'value': true});
      case 'flush':
        final snapshot = await cookieStore.loadAll();
        await cookieStore.saveAll(snapshot);
        return jsonEncode(<String, dynamic>{'ok': true});
      default:
        return jsonEncode(<String, dynamic>{
          'error': 'Unknown cookies action: $action',
        });
    }
  }

  String _hostOf(String rawUrl) {
    if (rawUrl.isEmpty) return '';
    try {
      final uri = Uri.parse(rawUrl);
      return uri.host.toLowerCase();
    } on FormatException {
      return '';
    }
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
