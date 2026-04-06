import 'dart:convert';

import '../../filesystem/app_paths.dart';
import '../../storage/json_file_store.dart';

class PluginRuntimeStateBridge {
  PluginRuntimeStateBridge(AppPaths appPaths)
    : _storageStore = JsonFileStore(appPaths.pluginStorageFilePath),
      _cookiesStore = JsonFileStore(appPaths.pluginCookiesFilePath);

  static const int _maxStorageBytes = 1024 * 1024 * 10;

  final JsonFileStore _storageStore;
  final JsonFileStore _cookiesStore;

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
        final cookies = await _cookiesStore.readObject();
        final scoped = _readObject(cookies[url]);
        return jsonEncode(<String, dynamic>{'value': scoped});
      case 'set':
        final cookies = await _cookiesStore.readObject();
        final scoped = _readObject(cookies[url]);
        final cookie = _readObject(payload['cookie']);
        final name = cookie['name']?.toString() ?? '';
        if (name.isEmpty) {
          return jsonEncode(<String, dynamic>{'value': false});
        }
        scoped[name] = cookie;
        cookies[url] = scoped;
        await _cookiesStore.writeJson(cookies);
        return jsonEncode(<String, dynamic>{'value': true});
      case 'flush':
        final cookies = await _cookiesStore.readObject();
        await _cookiesStore.writeJson(cookies);
        return jsonEncode(<String, dynamic>{'ok': true});
      default:
        return jsonEncode(<String, dynamic>{
          'error': 'Unknown cookies action: $action',
        });
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
