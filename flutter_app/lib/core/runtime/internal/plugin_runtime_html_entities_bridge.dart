import 'dart:convert';

/// Entity decode/encode for the plugin runtime `he` shim.
///
/// Supports:
/// - Named HTML5 entities in [_namedEntities] (the subset plugins actually use).
/// - Numeric decimal references: `&#160;` / `&#x00A0;` / `&#xAB;` (case
///   insensitive `x`).
/// - Round-trip encode covering `< > & " ' ` plus non-ASCII via `&#xNN;`.
///
/// We do not silently swallow bad sequences — invalid numeric references are
/// preserved verbatim in the output so plugin logs can surface the issue.
class PluginRuntimeHtmlEntitiesBridge {
  const PluginRuntimeHtmlEntitiesBridge();

  /// Decode HTML entity references in [input].
  String decode(String input) {
    if (input.isEmpty || !input.contains('&')) return input;

    final buffer = StringBuffer();
    var cursor = 0;
    while (cursor < input.length) {
      final ampAt = input.indexOf('&', cursor);
      if (ampAt < 0) {
        buffer.write(input.substring(cursor));
        break;
      }
      buffer.write(input.substring(cursor, ampAt));

      final semiAt = input.indexOf(';', ampAt);
      if (semiAt < 0) {
        // No semicolon after '&' → not an entity. Emit '&' and continue.
        buffer.write('&');
        cursor = ampAt + 1;
        continue;
      }

      final body = input.substring(ampAt + 1, semiAt);
      if (body.isEmpty) {
        buffer.write(input.substring(ampAt, semiAt + 1));
        cursor = semiAt + 1;
        continue;
      }

      final decoded = _decodeBody(body);
      if (decoded != null) {
        buffer.write(decoded);
        cursor = semiAt + 1;
      } else {
        // Unknown entity. Keep it verbatim so logs/UI can surface the failure
        // instead of silently dropping characters.
        buffer.write(input.substring(ampAt, semiAt + 1));
        cursor = semiAt + 1;
      }
    }
    return buffer.toString();
  }

  /// Encode [input] into an HTML-safe string.
  ///
  /// Always encodes the five XML-critical characters (`&<>"'`). Non-ASCII code
  /// points are encoded as hex numeric references, mirroring `he.encode`
  /// defaults closely enough for plugin use.
  String encode(String input) {
    if (input.isEmpty) return input;
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      switch (rune) {
        case 0x26: // &
          buffer.write('&amp;');
          break;
        case 0x3C: // <
          buffer.write('&lt;');
          break;
        case 0x3E: // >
          buffer.write('&gt;');
          break;
        case 0x22: // "
          buffer.write('&quot;');
          break;
        case 0x27: // '
          buffer.write('&#x27;');
          break;
        default:
          if (rune >= 0x20 && rune < 0x7F) {
            buffer.writeCharCode(rune);
          } else {
            buffer.write('&#x');
            buffer.write(rune.toRadixString(16).toUpperCase());
            buffer.write(';');
          }
      }
    }
    return buffer.toString();
  }

  String? _decodeBody(String body) {
    if (body.startsWith('#')) {
      return _decodeNumeric(body.substring(1));
    }
    return _namedEntities[body];
  }

  String? _decodeNumeric(String ref) {
    if (ref.isEmpty) return null;
    int? codePoint;
    if (ref[0] == 'x' || ref[0] == 'X') {
      codePoint = int.tryParse(ref.substring(1), radix: 16);
    } else {
      codePoint = int.tryParse(ref);
    }
    if (codePoint == null || codePoint < 0 || codePoint > 0x10FFFF) {
      return null;
    }
    return String.fromCharCode(codePoint);
  }

  /// The subset of HTML5 named entities plugins actually touch. We purposely
  /// keep this list short rather than embedding the 2000+ entity table —
  /// plugins that need more can use numeric references.
  static const Map<String, String> _namedEntities = <String, String>{
    'amp': '&',
    'AMP': '&',
    'lt': '<',
    'LT': '<',
    'gt': '>',
    'GT': '>',
    'quot': '"',
    'QUOT': '"',
    'apos': "'",
    'nbsp': '\u00A0',
    'copy': '\u00A9',
    'COPY': '\u00A9',
    'reg': '\u00AE',
    'REG': '\u00AE',
    'trade': '\u2122',
    'TRADE': '\u2122',
    'hellip': '\u2026',
    'mdash': '\u2014',
    'ndash': '\u2013',
    'lsquo': '\u2018',
    'rsquo': '\u2019',
    'ldquo': '\u201C',
    'rdquo': '\u201D',
    'laquo': '\u00AB',
    'raquo': '\u00BB',
    'middot': '\u00B7',
    'para': '\u00B6',
    'sect': '\u00A7',
    'deg': '\u00B0',
    'plusmn': '\u00B1',
    'times': '\u00D7',
    'divide': '\u00F7',
    'euro': '\u20AC',
    'pound': '\u00A3',
    'yen': '\u00A5',
    'cent': '\u00A2',
    'iexcl': '\u00A1',
    'iquest': '\u00BF',
    'micro': '\u00B5',
    'bull': '\u2022',
    'dagger': '\u2020',
    'Dagger': '\u2021',
  };
}

/// Message handler registered on the JS side via `MusicFreeHtmlEntities`.
/// Payload shape: `{ action: 'decode' | 'encode', value: String }`.
String handleHtmlEntitiesBridge(dynamic args) {
  final payload = _readObject(args);
  final action = payload['action']?.toString() ?? '';
  final value = payload['value']?.toString() ?? '';
  const bridge = PluginRuntimeHtmlEntitiesBridge();
  switch (action) {
    case 'decode':
      return jsonEncode(<String, dynamic>{'value': bridge.decode(value)});
    case 'encode':
      return jsonEncode(<String, dynamic>{'value': bridge.encode(value)});
    default:
      return jsonEncode(<String, dynamic>{
        'error': 'Unknown htmlEntities action: $action',
      });
  }
}

Map<String, dynamic> _readObject(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  return <String, dynamic>{};
}
