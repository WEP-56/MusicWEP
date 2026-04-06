import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import 'package:pointycastle/export.dart';

String handleCryptoBridge(dynamic args) {
  final payload = _readObject(args);
  final action = payload['action']?.toString() ?? '';

  switch (action) {
    case 'hash':
      return jsonEncode(_handleHash(payload));
    case 'base64Parse':
      return jsonEncode(_handleBase64Parse(payload));
    case 'base64Stringify':
      return jsonEncode(_handleBase64Stringify(payload));
    case 'utf8Parse':
      return jsonEncode(_handleUtf8Parse(payload));
    case 'utf8Stringify':
      return jsonEncode(_handleUtf8Stringify(payload));
    case 'hexStringify':
      return jsonEncode(_handleHexStringify(payload));
    case 'hexParse':
      return jsonEncode(_handleHexParse(payload));
    case 'aesEncrypt':
      return jsonEncode(_handleAesEncrypt(payload));
    default:
      return jsonEncode(<String, dynamic>{
        'error': 'Unknown crypto action: $action',
      });
  }
}

String handleCheerioBridge(dynamic args) {
  final payload = _readObject(args);
  final html = payload['html']?.toString() ?? '';
  final selector = payload['selector']?.toString() ?? '';
  final fragments =
      (payload['fragments'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => entry.toString())
          .toList(growable: false);

  final nodes = <Map<String, dynamic>>[];
  if (fragments.isNotEmpty) {
    for (final fragment in fragments) {
      final document = html_parser.parse(fragment);
      nodes.addAll(_selectNodes(document, selector));
    }
  } else {
    final document = html_parser.parse(html);
    nodes.addAll(_selectNodes(document, selector));
  }

  return jsonEncode(<String, dynamic>{'nodes': nodes});
}

Map<String, dynamic> _handleHash(Map<String, dynamic> payload) {
  final algorithm = payload['algorithm']?.toString().toLowerCase() ?? '';
  final value = payload['value']?.toString() ?? '';
  final key = payload['key']?.toString() ?? '';

  final bytes = utf8.encode(value);
  final digestBytes = switch (algorithm) {
    'md5' => md5.convert(bytes).bytes,
    'sha1' => sha1.convert(bytes).bytes,
    'sha256' => sha256.convert(bytes).bytes,
    'hmacsha1' => Hmac(sha1, utf8.encode(key)).convert(bytes).bytes,
    'hmacsha256' => Hmac(sha256, utf8.encode(key)).convert(bytes).bytes,
    _ => <int>[],
  };

  return <String, dynamic>{
    'bytes': digestBytes,
    'hex': _toHex(digestBytes),
    'base64': base64Encode(digestBytes),
  };
}

Map<String, dynamic> _handleBase64Parse(Map<String, dynamic> payload) {
  final value = payload['value']?.toString() ?? '';
  final bytes = base64.decode(value);
  return <String, dynamic>{
    'bytes': bytes,
    'text': utf8.decode(bytes, allowMalformed: true),
  };
}

Map<String, dynamic> _handleBase64Stringify(Map<String, dynamic> payload) {
  final bytes = _readBytes(payload['bytes']);
  return <String, dynamic>{'value': base64Encode(bytes)};
}

Map<String, dynamic> _handleUtf8Parse(Map<String, dynamic> payload) {
  final value = payload['value']?.toString() ?? '';
  final bytes = utf8.encode(value);
  return <String, dynamic>{'bytes': bytes, 'text': value};
}

Map<String, dynamic> _handleUtf8Stringify(Map<String, dynamic> payload) {
  final bytes = _readBytes(payload['bytes']);
  return <String, dynamic>{'value': utf8.decode(bytes, allowMalformed: true)};
}

Map<String, dynamic> _handleHexStringify(Map<String, dynamic> payload) {
  final bytes = _readBytes(payload['bytes']);
  return <String, dynamic>{'value': _toHex(bytes)};
}

Map<String, dynamic> _handleHexParse(Map<String, dynamic> payload) {
  final value = payload['value']?.toString() ?? '';
  final normalized = value.length.isOdd ? '0$value' : value;
  final bytes = <int>[];
  for (var index = 0; index < normalized.length; index += 2) {
    bytes.add(int.parse(normalized.substring(index, index + 2), radix: 16));
  }
  return <String, dynamic>{
    'bytes': bytes,
    'text': utf8.decode(bytes, allowMalformed: true),
  };
}

Map<String, dynamic> _handleAesEncrypt(Map<String, dynamic> payload) {
  final value =
      payload['valueText']?.toString() ??
      utf8.decode(_readBytes(payload['valueBytes']), allowMalformed: true);
  final key = Uint8List.fromList(_readBytes(payload['keyBytes']));
  final ivBytes = _readBytes(payload['ivBytes']);
  final mode = payload['mode']?.toString().toUpperCase() ?? 'CBC';

  final plaintext = Uint8List.fromList(utf8.encode(value));
  final cipher = _createAesCipher(key: key, ivBytes: ivBytes, mode: mode);
  final paddedPlaintext = _applyPkcs7(plaintext, 16);

  final output = Uint8List(paddedPlaintext.length);
  for (
    var offset = 0;
    offset < paddedPlaintext.length;
    offset += cipher.blockSize
  ) {
    cipher.processBlock(paddedPlaintext, offset, output, offset);
  }

  return <String, dynamic>{
    'bytes': output,
    'hex': _toHex(output),
    'base64': base64Encode(output),
  };
}

List<Map<String, dynamic>> _selectNodes(dynamic document, String selector) {
  final elements = selector.isEmpty
      ? document.querySelectorAll('html')
      : document.querySelectorAll(selector);
  final nodes = <Map<String, dynamic>>[];
  for (final element in elements) {
    if (element is html_dom.Element) {
      nodes.add(_serializeElement(element));
    }
  }
  return nodes;
}

Map<String, dynamic> _serializeElement(html_dom.Element element) {
  return <String, dynamic>{
    'tagName': element.localName,
    'text': element.text,
    'html': element.innerHtml,
    'outerHtml': element.outerHtml,
    'attributes': Map<String, String>.from(element.attributes),
    'children': element.children.map(_serializeElement).toList(growable: false),
  };
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

List<int> _readBytes(dynamic value) {
  if (value is List<int>) {
    return value;
  }
  if (value is List) {
    return value.map((entry) => (entry as num).toInt()).toList(growable: false);
  }
  return const <int>[];
}

Uint8List _applyPkcs7(List<int> bytes, int blockSize) {
  final padding = blockSize - (bytes.length % blockSize);
  return Uint8List.fromList(<int>[
    ...bytes,
    ...List<int>.filled(padding, padding),
  ]);
}

BlockCipher _createAesCipher({
  required Uint8List key,
  required List<int> ivBytes,
  required String mode,
}) {
  final keyParam = KeyParameter(key);
  if (mode == 'ECB') {
    return ECBBlockCipher(AESEngine())..init(true, keyParam);
  }

  final normalizedIv = Uint8List.fromList(
    ivBytes.length >= 16
        ? ivBytes.take(16).toList(growable: false)
        : <int>[...ivBytes, ...List<int>.filled(16 - ivBytes.length, 0)],
  );
  return CBCBlockCipher(AESEngine())
    ..init(true, ParametersWithIV<KeyParameter>(keyParam, normalizedIv));
}

String _toHex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
