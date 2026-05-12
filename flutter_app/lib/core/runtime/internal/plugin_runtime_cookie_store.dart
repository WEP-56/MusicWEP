import 'dart:async';
import 'dart:io' show HttpDate;

import '../../storage/json_file_store.dart';

/// A single cookie record persisted under `<domain>/<path>:<name>`.
class PluginRuntimeCookie {
  const PluginRuntimeCookie({
    required this.name,
    required this.value,
    required this.domain,
    this.path = '/',
    this.secure = false,
    this.httpOnly = false,
    this.expiresAt,
  });

  final String name;
  final String value;
  final String domain;
  final String path;
  final bool secure;
  final bool httpOnly;
  final DateTime? expiresAt;

  bool get isExpired {
    final at = expiresAt;
    if (at == null) return false;
    return at.isBefore(DateTime.now());
  }

  PluginRuntimeCookie copyWith({
    String? value,
    DateTime? expiresAt,
    bool? secure,
    bool? httpOnly,
  }) {
    return PluginRuntimeCookie(
      name: name,
      value: value ?? this.value,
      domain: domain,
      path: path,
      secure: secure ?? this.secure,
      httpOnly: httpOnly ?? this.httpOnly,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'value': value,
      'domain': domain,
      'path': path,
      'secure': secure,
      'httpOnly': httpOnly,
      'expires': expiresAt?.toIso8601String(),
    };
  }

  factory PluginRuntimeCookie.fromJson(Map<String, dynamic> json) {
    return PluginRuntimeCookie(
      name: json['name']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      domain: json['domain']?.toString() ?? '',
      path: json['path']?.toString().isNotEmpty == true
          ? json['path']!.toString()
          : '/',
      secure: json['secure'] as bool? ?? false,
      httpOnly: json['httpOnly'] as bool? ?? false,
      expiresAt: _parseExpires(json['expires']),
    );
  }

  static DateTime? _parseExpires(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    final parsed = DateTime.tryParse(raw.toString());
    return parsed;
  }
}

/// Two-level, per-plugin cookie store. Keys are domains; each domain maps
/// to a map keyed by `<path>:<name>` so we preserve the `(domain, path,
/// name)` uniqueness rule.
///
/// Reads migrate the legacy per-URL flat schema transparently on first
/// access.
class PluginRuntimeCookieStore {
  PluginRuntimeCookieStore(this._store);

  final JsonFileStore _store;

  /// In-memory cache; `loadAll` populates it so subsequent reads during a
  /// single HTTP round-trip don't touch disk.
  Map<String, Map<String, PluginRuntimeCookie>>? _cache;
  final _writeMutex = _SerialQueue();

  Future<Map<String, Map<String, PluginRuntimeCookie>>> loadAll() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await _store.readObject();
    final parsed = _parseRaw(raw);
    _cache = parsed;
    return parsed;
  }

  Future<void> saveAll(Map<String, Map<String, PluginRuntimeCookie>> all) {
    return _writeMutex.run(() async {
      _cache = all;
      final encoded = <String, dynamic>{};
      all.forEach((domain, cookies) {
        final nested = <String, dynamic>{};
        cookies.forEach((key, cookie) {
          nested[key] = cookie.toJson();
        });
        encoded[domain] = nested;
      });
      await _store.writeJson(encoded);
    });
  }

  /// Returns all cookies that apply to [uri], filtering by domain suffix,
  /// path prefix, `secure`, and expiry.
  Future<List<PluginRuntimeCookie>> matchFor(Uri uri) async {
    final all = await loadAll();
    final host = uri.host.toLowerCase();
    final now = DateTime.now();
    final matched = <PluginRuntimeCookie>[];
    for (final entry in all.entries) {
      final domain = entry.key.toLowerCase();
      if (!_hostMatchesDomain(host: host, domain: domain)) continue;
      for (final cookie in entry.value.values) {
        if (cookie.isExpired) continue;
        if (cookie.expiresAt != null && cookie.expiresAt!.isBefore(now)) {
          continue;
        }
        if (!_pathMatches(cookiePath: cookie.path, requestPath: uri.path)) {
          continue;
        }
        if (cookie.secure && uri.scheme.toLowerCase() != 'https') continue;
        matched.add(cookie);
      }
    }
    return matched;
  }

  /// Builds a `Cookie: a=b; c=d` header value for [uri].
  Future<String> buildCookieHeader(Uri uri) async {
    final matches = await matchFor(uri);
    if (matches.isEmpty) return '';
    return matches.map((c) => '${c.name}=${c.value}').join('; ');
  }

  /// Upserts [cookie] into the store.
  Future<void> setCookie(PluginRuntimeCookie cookie) async {
    if (cookie.name.isEmpty || cookie.domain.isEmpty) return;
    final all = await loadAll();
    final domainKey = cookie.domain.toLowerCase();
    final domainMap = Map<String, PluginRuntimeCookie>.from(
      all[domainKey] ?? const <String, PluginRuntimeCookie>{},
    );
    domainMap[_compositeKey(path: cookie.path, name: cookie.name)] = cookie;
    final next = Map<String, Map<String, PluginRuntimeCookie>>.from(all);
    next[domainKey] = domainMap;
    await saveAll(next);
  }

  /// Parses every `Set-Cookie` header in [responseHeaders] and merges the
  /// resulting cookies, using [requestUri.host] as the default domain and
  /// `/` as the default path.
  Future<void> ingestSetCookies({
    required Uri requestUri,
    required Map<String, String> responseHeaders,
  }) async {
    final setCookieValues = <String>[];
    responseHeaders.forEach((key, value) {
      if (key.toLowerCase() == 'set-cookie' && value.isNotEmpty) {
        // Dart's http client joins multiple Set-Cookie headers with a comma.
        // Split on the comma that precedes a new `name=value;` pair.
        setCookieValues.addAll(_splitSetCookieList(value));
      }
    });
    if (setCookieValues.isEmpty) return;

    for (final raw in setCookieValues) {
      final parsed = _parseSetCookie(raw, fallbackHost: requestUri.host);
      if (parsed == null) continue;
      await setCookie(parsed);
    }
  }

  /// Returns the domain's cookies flattened to the legacy `{name: {...}}`
  /// shape so the `@react-native-cookies/cookies` shim contract keeps
  /// working.
  Future<Map<String, Map<String, dynamic>>> flatCookiesForHost(
    String host,
  ) async {
    final normalizedHost = host.toLowerCase();
    final all = await loadAll();
    final result = <String, Map<String, dynamic>>{};
    all.forEach((domain, cookies) {
      if (!_hostMatchesDomain(host: normalizedHost, domain: domain)) return;
      cookies.forEach((_, cookie) {
        if (cookie.isExpired) return;
        result[cookie.name] = cookie.toJson();
      });
    });
    return result;
  }

  Map<String, Map<String, PluginRuntimeCookie>> _parseRaw(
    Map<String, dynamic> raw,
  ) {
    final result = <String, Map<String, PluginRuntimeCookie>>{};
    raw.forEach((key, value) {
      if (value is! Map) return;
      final normalized = value.map(
        (k, v) => MapEntry(k.toString(), v),
      );
      // Heuristic for legacy flat `{url: {name: cookie}}` schema: every
      // entry is itself a cookie object. We migrate it into the new schema.
      final looksLikeLegacy = _looksLikeLegacyPayload(key, normalized);
      if (looksLikeLegacy) {
        final domain = _extractHost(key) ?? key.toLowerCase();
        final bucket = result.putIfAbsent(
          domain,
          () => <String, PluginRuntimeCookie>{},
        );
        normalized.forEach((_, cookieJson) {
          if (cookieJson is! Map) return;
          final cookie = PluginRuntimeCookie.fromJson(<String, dynamic>{
            ...cookieJson.map((ck, cv) => MapEntry(ck.toString(), cv)),
            'domain': (cookieJson['domain'] ?? domain).toString(),
            'path': (cookieJson['path'] ?? '/').toString(),
          });
          if (cookie.name.isEmpty) return;
          bucket[_compositeKey(path: cookie.path, name: cookie.name)] = cookie;
        });
        return;
      }

      // New schema: `{domain: {pathKey: cookieJson}}`.
      final domain = key.toLowerCase();
      final bucket = <String, PluginRuntimeCookie>{};
      normalized.forEach((compositeKey, cookieJson) {
        if (cookieJson is! Map) return;
        final cookie = PluginRuntimeCookie.fromJson(
          cookieJson.map((ck, cv) => MapEntry(ck.toString(), cv)),
        );
        if (cookie.name.isEmpty) return;
        bucket[compositeKey] = cookie;
      });
      result[domain] = bucket;
    });
    return result;
  }

  bool _looksLikeLegacyPayload(String key, Map<String, dynamic> value) {
    if (key.startsWith('http://') || key.startsWith('https://')) return true;
    for (final entry in value.entries) {
      if (entry.key.contains(':')) return false;
      final v = entry.value;
      if (v is Map && (v['name'] != null && v['value'] != null)) return true;
    }
    return false;
  }

  String? _extractHost(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl);
      return uri.host.isEmpty ? null : uri.host.toLowerCase();
    } catch (_) {
      return null;
    }
  }

  static String _compositeKey({required String path, required String name}) {
    final normalizedPath = path.isEmpty ? '/' : path;
    return '$normalizedPath:$name';
  }

  static bool _hostMatchesDomain({
    required String host,
    required String domain,
  }) {
    final normalizedDomain = domain.startsWith('.')
        ? domain.substring(1)
        : domain;
    if (host == normalizedDomain) return true;
    return host.endsWith('.$normalizedDomain');
  }

  static bool _pathMatches({
    required String cookiePath,
    required String requestPath,
  }) {
    if (cookiePath.isEmpty || cookiePath == '/') return true;
    final normalized = requestPath.isEmpty ? '/' : requestPath;
    if (normalized == cookiePath) return true;
    if (cookiePath.endsWith('/')) return normalized.startsWith(cookiePath);
    return normalized == cookiePath || normalized.startsWith('$cookiePath/');
  }

  static List<String> _splitSetCookieList(String raw) {
    // Split on commas that are followed by a `name=` (cookie boundary) while
    // leaving commas inside `Expires=Wed, 09 Jun 2021 ...` intact.
    final result = <String>[];
    var buffer = StringBuffer();
    var i = 0;
    while (i < raw.length) {
      final char = raw[i];
      if (char == ',') {
        // Look ahead: does a `name=` follow (after optional whitespace)?
        var lookahead = i + 1;
        while (lookahead < raw.length && raw[lookahead] == ' ') {
          lookahead++;
        }
        final rest = raw.substring(lookahead);
        final looksLikeNewCookie = RegExp(r'^[^=;\s]+=').hasMatch(rest);
        if (looksLikeNewCookie && !_isWeekday(rest)) {
          final chunk = buffer.toString().trim();
          if (chunk.isNotEmpty) result.add(chunk);
          buffer = StringBuffer();
          i = lookahead;
          continue;
        }
      }
      buffer.write(char);
      i++;
    }
    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) result.add(tail);
    return result;
  }

  static bool _isWeekday(String rest) {
    final lower = rest.toLowerCase();
    const days = <String>[
      'mon,',
      'tue,',
      'wed,',
      'thu,',
      'fri,',
      'sat,',
      'sun,',
    ];
    return days.any(lower.startsWith);
  }

  static PluginRuntimeCookie? _parseSetCookie(
    String raw, {
    required String fallbackHost,
  }) {
    final segments = raw.split(';').map((s) => s.trim()).toList(growable: false);
    if (segments.isEmpty) return null;
    final head = segments.first;
    final eqIndex = head.indexOf('=');
    if (eqIndex <= 0) return null;
    final name = head.substring(0, eqIndex).trim();
    final value = head.substring(eqIndex + 1).trim();
    if (name.isEmpty) return null;

    var domain = fallbackHost.toLowerCase();
    var path = '/';
    var secure = false;
    var httpOnly = false;
    DateTime? expires;

    for (final attribute in segments.skip(1)) {
      final normalized = attribute.toLowerCase();
      if (normalized == 'secure') {
        secure = true;
      } else if (normalized == 'httponly') {
        httpOnly = true;
      } else {
        final attrEq = attribute.indexOf('=');
        if (attrEq <= 0) continue;
        final key = attribute.substring(0, attrEq).trim().toLowerCase();
        final rawValue = attribute.substring(attrEq + 1).trim();
        switch (key) {
          case 'domain':
            final candidate = rawValue.toLowerCase();
            if (candidate.isNotEmpty) {
              domain = candidate.startsWith('.')
                  ? candidate.substring(1)
                  : candidate;
            }
            break;
          case 'path':
            path = rawValue.isEmpty ? '/' : rawValue;
            break;
          case 'expires':
            expires = _parseHttpDate(rawValue);
            break;
          case 'max-age':
            final seconds = int.tryParse(rawValue);
            if (seconds != null) {
              expires = DateTime.now().add(Duration(seconds: seconds));
            }
            break;
        }
      }
    }
    return PluginRuntimeCookie(
      name: name,
      value: value,
      domain: domain,
      path: path,
      secure: secure,
      httpOnly: httpOnly,
      expiresAt: expires,
    );
  }

  static DateTime? _parseHttpDate(String value) {
    // Most `Set-Cookie` timestamps are RFC 1123, which Dart's `HttpDate`
    // handles. Fall back to `DateTime.parse` for the odd ISO-8601 case.
    try {
      return HttpDate.parse(value).toUtc();
    } on FormatException {
      try {
        return DateTime.parse(value).toUtc();
      } on FormatException {
        return null;
      }
    }
  }
}

class _SerialQueue {
  Future<void> _tail = Future<void>.value();
  Future<void> run(Future<void> Function() task) {
    final completer = Completer<void>();
    _tail = _tail.then((_) async {
      try {
        await task();
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
