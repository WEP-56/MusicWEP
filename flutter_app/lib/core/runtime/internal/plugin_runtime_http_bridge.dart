import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class PluginRuntimeHttpBridge {
  PluginRuntimeHttpBridge();

  Future<String> handle(dynamic args) async {
    final payload = _readObject(args);
    final action = payload['action']?.toString() ?? '';

    if (action != 'request') {
      return jsonEncode(<String, dynamic>{
        'error': 'Unknown http action: $action',
      });
    }

    try {
      final method = (payload['method']?.toString() ?? 'GET').toUpperCase();
      final url = payload['url']?.toString() ?? '';
      final headers = _readStringMapStatic(payload['headers']);
      final body = payload['body']?.toString();
      final responseType = payload['responseType']?.toString() ?? '';
      final timeoutMs = _readTimeoutMs(payload['timeout']);

      final requestFuture = Isolate.run(
        () => _sendInIsolate(<String, dynamic>{
          'method': method,
          'url': url,
          'headers': headers,
          'body': body,
          'responseType': responseType,
        }),
      );
      final response = timeoutMs == null
          ? await requestFuture
          : await requestFuture.timeout(Duration(milliseconds: timeoutMs));

      return jsonEncode(response);
    } catch (error, stackTrace) {
      return jsonEncode(<String, dynamic>{
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
      });
    }
  }

  static Future<Map<String, dynamic>> _sendInIsolate(
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse(payload['url'] as String);
    final request = http.Request(payload['method'] as String, uri);
    final normalizedHeaders = _normalizeRequestHeadersStatic(
      _readStringMapStatic(payload['headers']),
    );

    normalizedHeaders.forEach((key, value) {
      if (value.isEmpty) {
        return;
      }
      request.headers[key] = value;
    });

    final body = payload['body']?.toString();
    final method = (payload['method']?.toString() ?? 'GET').toUpperCase();
    if (body != null &&
        body.isNotEmpty &&
        method != 'GET' &&
        method != 'HEAD') {
      request.body = body;
    }

    final client = IOClient(
      HttpClient()..badCertificateCallback = (_, __, ___) => true,
    );
    try {
      final streamedResponse = await client.send(request);
      final bytes = await streamedResponse.stream.toBytes();
      final responseHeaders = <String, String>{};

      streamedResponse.headers.forEach((name, value) {
        responseHeaders[name] = value;
      });

      return <String, dynamic>{
        'status': streamedResponse.statusCode,
        'statusText': streamedResponse.reasonPhrase,
        'headers': responseHeaders,
        'data': _decodeResponseBodyStatic(
          bytes,
          responseHeaders: responseHeaders,
          responseType: payload['responseType']?.toString() ?? '',
        ),
      };
    } finally {
      client.close();
    }
  }

  static Map<String, String> _normalizeRequestHeadersStatic(
    Map<String, String> headers,
  ) {
    if (headers.isEmpty) {
      return headers;
    }

    final normalized = <String, String>{};
    headers.forEach((key, value) {
      if (key.toLowerCase() == 'accept-encoding') {
        final supported = value
            .split(',')
            .map((entry) => entry.trim())
            .where((entry) {
              final normalizedEntry = entry.toLowerCase();
              return normalizedEntry == 'gzip' || normalizedEntry == 'deflate';
            })
            .join(', ');
        if (supported.isNotEmpty) {
          normalized[key] = supported;
        }
        return;
      }
      normalized[key] = value;
    });
    return normalized;
  }

  static dynamic _decodeResponseBodyStatic(
    List<int> bytes, {
    required Map<String, String> responseHeaders,
    required String responseType,
  }) {
    if (responseType == 'arraybuffer' || responseType == 'blob') {
      return bytes;
    }

    final text = utf8.decode(bytes, allowMalformed: true);
    final trimmed = text.trim();
    final sanitized = _stripJsonEnvelopeNoiseStatic(trimmed);
    final contentType = responseHeaders.entries
        .firstWhere(
          (entry) => entry.key.toLowerCase() == 'content-type',
          orElse: () => const MapEntry<String, String>('', ''),
        )
        .value
        .toLowerCase();

    if (responseType == 'json' ||
        contentType.contains('application/json') ||
        ((sanitized.startsWith('{') && sanitized.endsWith('}')) ||
            (sanitized.startsWith('[') && sanitized.endsWith(']')))) {
      try {
        return jsonDecode(sanitized);
      } catch (_) {
        return text;
      }
    }

    return text;
  }

  static String _stripJsonEnvelopeNoiseStatic(String value) {
    if (value.isEmpty) {
      return value;
    }

    var start = 0;
    var end = value.length;

    bool isJsonBoundary(String char) => char == '{' || char == '[';
    bool isJsonClosing(String char) => char == '}' || char == ']';
    bool isControlNoise(int codeUnit) =>
        codeUnit <= 0x1F &&
        codeUnit != 0x09 &&
        codeUnit != 0x0A &&
        codeUnit != 0x0D;

    while (start < end &&
        isControlNoise(value.codeUnitAt(start)) &&
        !isJsonBoundary(value[start])) {
      start++;
    }
    while (end > start &&
        isControlNoise(value.codeUnitAt(end - 1)) &&
        !isJsonClosing(value[end - 1])) {
      end--;
    }
    return value.substring(start, end).trim();
  }

  int? _readTimeoutMs(dynamic value) {
    if (value is int) {
      return value > 0 ? value : null;
    }
    if (value is num) {
      return value > 0 ? value.toInt() : null;
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }
    return null;
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

  static Map<String, String> _readStringMapStatic(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value.map((key, entry) => MapEntry(key, entry.toString()));
    }
    if (value is Map) {
      return value.map(
        (key, entry) => MapEntry(key.toString(), entry.toString()),
      );
    }
    return const <String, String>{};
  }

  void dispose() {}
}
