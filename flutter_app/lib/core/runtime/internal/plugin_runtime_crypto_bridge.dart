import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart' hide Digest, Mac;
import 'package:pointycastle/digests/sha3.dart' as pc_sha3;
import 'package:pointycastle/digests/sha224.dart' as pc_sha224;

/// Channel handler for `MusicFreeCrypto`. Each `action` corresponds to one
/// crypto-js primitive, see `shims/plugin_runtime_shim_crypto.dart` for the
/// JS side.
String handleCryptoBridge(dynamic args) {
  final payload = _readObject(args);
  final action = payload['action']?.toString() ?? '';
  try {
    switch (action) {
      case 'hash':
        return jsonEncode(_handleHash(payload));
      case 'hmac':
        return jsonEncode(_handleHmac(payload));
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
      case 'latin1Parse':
        return jsonEncode(_handleLatin1Parse(payload));
      case 'latin1Stringify':
        return jsonEncode(_handleLatin1Stringify(payload));
      case 'aesEncrypt':
        return jsonEncode(_handleAesEncrypt(payload));
      case 'aesDecrypt':
        return jsonEncode(_handleAesDecrypt(payload));
      case 'tripleDesEncrypt':
        return jsonEncode(_handleTripleDesEncrypt(payload));
      case 'tripleDesDecrypt':
        return jsonEncode(_handleTripleDesDecrypt(payload));
      case 'rc4Encrypt':
        return jsonEncode(_handleRc4(payload, drop: 0));
      case 'rc4DropEncrypt':
        final drop = (payload['drop'] as num?)?.toInt() ?? 768;
        return jsonEncode(_handleRc4(payload, drop: drop));
      case 'randomWords':
        return jsonEncode(_handleRandomWords(payload));
      default:
        return jsonEncode(<String, dynamic>{
          'error': 'Unknown crypto action: $action',
        });
    }
  } catch (error, stackTrace) {
    return jsonEncode(<String, dynamic>{
      'error': error.toString(),
      'stackTrace': stackTrace.toString(),
    });
  }
}

// --- Hashing ----------------------------------------------------------------

Map<String, dynamic> _handleHash(Map<String, dynamic> payload) {
  final algorithm = payload['algorithm']?.toString().toLowerCase() ?? '';
  final bytes = _readValueBytes(payload);
  final keyBytes = _readBytes(payload['keyBytes']);
  final keyString = payload['key']?.toString() ?? '';
  final hmacKey = keyBytes.isNotEmpty ? keyBytes : utf8.encode(keyString);
  final digest = switch (algorithm) {
    'md5' => md5.convert(bytes).bytes,
    'sha1' => sha1.convert(bytes).bytes,
    'sha224' => pc_sha224.SHA224Digest().process(Uint8List.fromList(bytes)).toList(),
    'sha256' => sha256.convert(bytes).bytes,
    'sha384' => sha384.convert(bytes).bytes,
    'sha512' => sha512.convert(bytes).bytes,
    'sha3-256' => pc_sha3.SHA3Digest(256).process(Uint8List.fromList(bytes)).toList(),
    'sha3-512' => pc_sha3.SHA3Digest(512).process(Uint8List.fromList(bytes)).toList(),
    // Legacy compat: some callers (and older tests) pass an hmac in the
    // `algorithm` field.
    'hmacsha1' => Hmac(sha1, hmacKey).convert(bytes).bytes,
    'hmacsha256' => Hmac(sha256, hmacKey).convert(bytes).bytes,
    'hmacsha512' => Hmac(sha512, hmacKey).convert(bytes).bytes,
    'hmacmd5' => Hmac(md5, hmacKey).convert(bytes).bytes,
    _ => throw ArgumentError('Unsupported hash algorithm: $algorithm'),
  };
  return _wordArray(digest);
}

Map<String, dynamic> _handleHmac(Map<String, dynamic> payload) {
  final algorithm = payload['algorithm']?.toString().toLowerCase() ?? '';
  final messageBytes = _readValueBytes(payload);
  final keyBytes = _readBytes(payload['keyBytes']);
  final hash = switch (algorithm) {
    'md5' => md5,
    'sha1' => sha1,
    'sha256' => sha256,
    'sha384' => sha384,
    'sha512' => sha512,
    _ => throw ArgumentError('Unsupported hmac algorithm: $algorithm'),
  };
  final digest = Hmac(hash, keyBytes).convert(messageBytes).bytes;
  return _wordArray(digest);
}

// --- Encoders ---------------------------------------------------------------

Map<String, dynamic> _handleBase64Parse(Map<String, dynamic> payload) {
  final value = payload['value']?.toString() ?? '';
  final bytes = base64.decode(value);
  return <String, dynamic>{
    'bytes': bytes,
    'text': utf8.decode(bytes, allowMalformed: true),
  };
}

Map<String, dynamic> _handleBase64Stringify(Map<String, dynamic> payload) {
  return <String, dynamic>{'value': base64Encode(_readBytes(payload['bytes']))};
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
  return <String, dynamic>{'value': _toHex(_readBytes(payload['bytes']))};
}

Map<String, dynamic> _handleHexParse(Map<String, dynamic> payload) {
  final value = payload['value']?.toString() ?? '';
  final normalized = value.length.isOdd ? '0$value' : value;
  final bytes = <int>[];
  for (var index = 0; index < normalized.length; index += 2) {
    final byte = int.parse(normalized.substring(index, index + 2), radix: 16);
    bytes.add(byte);
  }
  return <String, dynamic>{
    'bytes': bytes,
    'text': utf8.decode(bytes, allowMalformed: true),
  };
}

Map<String, dynamic> _handleLatin1Parse(Map<String, dynamic> payload) {
  final value = payload['value']?.toString() ?? '';
  final bytes = latin1.encode(value);
  return <String, dynamic>{'bytes': bytes, 'text': value};
}

Map<String, dynamic> _handleLatin1Stringify(Map<String, dynamic> payload) {
  final bytes = _readBytes(payload['bytes']);
  return <String, dynamic>{'value': latin1.decode(bytes, allowInvalid: true)};
}

// --- Symmetric ciphers ------------------------------------------------------

Map<String, dynamic> _handleAesEncrypt(Map<String, dynamic> payload) {
  final plaintext = _readPlaintextBytes(payload);
  final key = Uint8List.fromList(_readBytes(payload['keyBytes']));
  final iv = _readBytes(payload['ivBytes']);
  final mode = payload['mode']?.toString().toUpperCase() ?? 'CBC';
  final padding = payload['padding']?.toString() ?? 'pkcs7';
  final cipher = _createBlockCipher(
    cipher: AESEngine(),
    key: key,
    iv: iv,
    mode: mode,
    forEncryption: true,
  );
  final padded = _applyPadding(plaintext, padding, cipher.blockSize);
  final output = _processBlocks(cipher, padded);
  return _cipherResult(output);
}

Map<String, dynamic> _handleAesDecrypt(Map<String, dynamic> payload) {
  final ciphertext = _readCiphertextBytes(payload);
  final key = Uint8List.fromList(_readBytes(payload['keyBytes']));
  final iv = _readBytes(payload['ivBytes']);
  final mode = payload['mode']?.toString().toUpperCase() ?? 'CBC';
  final padding = payload['padding']?.toString() ?? 'pkcs7';
  final cipher = _createBlockCipher(
    cipher: AESEngine(),
    key: key,
    iv: iv,
    mode: mode,
    forEncryption: false,
  );
  final decrypted = _processBlocks(cipher, ciphertext);
  final stripped = _removePadding(decrypted, padding, cipher.blockSize);
  return _cipherResult(stripped);
}

Map<String, dynamic> _handleTripleDesEncrypt(Map<String, dynamic> payload) {
  final plaintext = _readPlaintextBytes(payload);
  final key = Uint8List.fromList(_readBytes(payload['keyBytes']));
  final iv = _readBytes(payload['ivBytes']);
  final mode = payload['mode']?.toString().toUpperCase() ?? 'CBC';
  final padding = payload['padding']?.toString() ?? 'pkcs7';
  final cipher = _createBlockCipher(
    cipher: DESedeEngine(),
    key: key,
    iv: iv,
    mode: mode,
    forEncryption: true,
  );
  final padded = _applyPadding(plaintext, padding, cipher.blockSize);
  final output = _processBlocks(cipher, padded);
  return _cipherResult(output);
}

Map<String, dynamic> _handleTripleDesDecrypt(Map<String, dynamic> payload) {
  final ciphertext = _readCiphertextBytes(payload);
  final key = Uint8List.fromList(_readBytes(payload['keyBytes']));
  final iv = _readBytes(payload['ivBytes']);
  final mode = payload['mode']?.toString().toUpperCase() ?? 'CBC';
  final padding = payload['padding']?.toString() ?? 'pkcs7';
  final cipher = _createBlockCipher(
    cipher: DESedeEngine(),
    key: key,
    iv: iv,
    mode: mode,
    forEncryption: false,
  );
  final decrypted = _processBlocks(cipher, ciphertext);
  final stripped = _removePadding(decrypted, padding, cipher.blockSize);
  return _cipherResult(stripped);
}

Map<String, dynamic> _handleRc4(
  Map<String, dynamic> payload, {
  required int drop,
}) {
  final input = Uint8List.fromList(_readPlaintextBytes(payload));
  final key = Uint8List.fromList(_readBytes(payload['keyBytes']));
  final engine = RC4Engine()
    ..init(true, KeyParameter(key));
  if (drop > 0) {
    final sink = Uint8List(drop);
    engine.processBytes(Uint8List(drop), 0, drop, sink, 0);
  }
  final output = Uint8List(input.length);
  engine.processBytes(input, 0, input.length, output, 0);
  return _cipherResult(output);
}

Map<String, dynamic> _handleRandomWords(Map<String, dynamic> payload) {
  final length = (payload['length'] as num?)?.toInt() ?? 16;
  final bytes = Uint8List(length);
  final secure = SecureRandom('Fortuna')
    ..seed(KeyParameter(_fortunaSeed()));
  for (var i = 0; i < length; i += 1) {
    bytes[i] = secure.nextUint8();
  }
  return _cipherResult(bytes);
}

// --- Helpers ----------------------------------------------------------------

Uint8List _fortunaSeed() {
  // 32 random bytes sourced from Dart's secure random. We use the raw
  // `DateTime` timestamp as fallback if `SecureRandom('default')` is not
  // available in the embedding.
  final seed = Uint8List(32);
  try {
    final seeded = SecureRandom('AES/CTR/PRNG')
      ..seed(KeyParameter(Uint8List(32)));
    for (var i = 0; i < seed.length; i += 1) {
      seed[i] = seeded.nextUint8();
    }
  } catch (_) {
    final now = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < seed.length; i += 1) {
      seed[i] = (now >> (8 * (i % 8))) & 0xFF;
    }
  }
  return seed;
}

List<int> _readPlaintextBytes(Map<String, dynamic> payload) {
  if (payload['valueBytes'] is List) {
    return _readBytes(payload['valueBytes']);
  }
  final value = payload['valueText']?.toString() ?? '';
  return utf8.encode(value);
}

Uint8List _readCiphertextBytes(Map<String, dynamic> payload) {
  if (payload['ciphertextBytes'] is List) {
    return Uint8List.fromList(_readBytes(payload['ciphertextBytes']));
  }
  final base64Value = payload['ciphertextBase64']?.toString();
  if (base64Value != null && base64Value.isNotEmpty) {
    return base64.decode(base64Value);
  }
  final hexValue = payload['ciphertextHex']?.toString();
  if (hexValue != null && hexValue.isNotEmpty) {
    return Uint8List.fromList(_hexToBytes(hexValue));
  }
  throw ArgumentError(
    'crypto bridge: expected one of ciphertextBytes / ciphertextBase64 / ciphertextHex.',
  );
}

List<int> _hexToBytes(String value) {
  final normalized = value.length.isOdd ? '0$value' : value;
  final bytes = <int>[];
  for (var i = 0; i < normalized.length; i += 2) {
    bytes.add(int.parse(normalized.substring(i, i + 2), radix: 16));
  }
  return bytes;
}

List<int> _readValueBytes(Map<String, dynamic> payload) {
  if (payload['valueBytes'] is List) {
    return _readBytes(payload['valueBytes']);
  }
  return utf8.encode(payload['value']?.toString() ?? '');
}

Uint8List _applyPadding(List<int> bytes, String mode, int blockSize) {
  switch (mode.toLowerCase()) {
    case 'nopadding':
    case 'zeropadding':
      final padLength = bytes.length % blockSize == 0
          ? 0
          : blockSize - bytes.length % blockSize;
      return Uint8List.fromList(<int>[
        ...bytes,
        ...List<int>.filled(padLength, 0),
      ]);
    case 'pkcs7':
    case 'pkcs5':
      final padding = blockSize - (bytes.length % blockSize);
      return Uint8List.fromList(<int>[
        ...bytes,
        ...List<int>.filled(padding, padding),
      ]);
    case 'iso10126':
      final padding = blockSize - (bytes.length % blockSize);
      final random = SecureRandom('Fortuna')
        ..seed(KeyParameter(_fortunaSeed()));
      final tail = List<int>.generate(
        padding - 1,
        (_) => random.nextUint8(),
      );
      return Uint8List.fromList(<int>[...bytes, ...tail, padding]);
    case 'ansix923':
      final padding = blockSize - (bytes.length % blockSize);
      return Uint8List.fromList(<int>[
        ...bytes,
        ...List<int>.filled(padding - 1, 0),
        padding,
      ]);
    case 'iso97971':
      // 1 bit = byte 0x80 followed by zero padding.
      final padding = blockSize - ((bytes.length + 1) % blockSize);
      return Uint8List.fromList(<int>[
        ...bytes,
        0x80,
        ...List<int>.filled(padding, 0),
      ]);
    default:
      throw ArgumentError('Unsupported padding mode: $mode');
  }
}

Uint8List _removePadding(List<int> bytes, String mode, int blockSize) {
  switch (mode.toLowerCase()) {
    case 'nopadding':
    case 'zeropadding':
      return Uint8List.fromList(bytes);
    case 'pkcs7':
    case 'pkcs5':
      if (bytes.isEmpty) return Uint8List(0);
      final last = bytes.last;
      if (last == 0 || last > blockSize || last > bytes.length) {
        return Uint8List.fromList(bytes);
      }
      return Uint8List.fromList(bytes.sublist(0, bytes.length - last));
    case 'iso10126':
    case 'ansix923':
      if (bytes.isEmpty) return Uint8List(0);
      final last = bytes.last;
      if (last == 0 || last > blockSize || last > bytes.length) {
        return Uint8List.fromList(bytes);
      }
      return Uint8List.fromList(bytes.sublist(0, bytes.length - last));
    case 'iso97971':
      final index = bytes.lastIndexOf(0x80);
      if (index < 0) return Uint8List.fromList(bytes);
      return Uint8List.fromList(bytes.sublist(0, index));
    default:
      throw ArgumentError('Unsupported padding mode: $mode');
  }
}

BlockCipher _createBlockCipher({
  required BlockCipher cipher,
  required Uint8List key,
  required List<int> iv,
  required String mode,
  required bool forEncryption,
}) {
  final keyParam = KeyParameter(key);
  BlockCipher wrapped;
  switch (mode) {
    case 'ECB':
      wrapped = ECBBlockCipher(cipher);
      wrapped.init(forEncryption, keyParam);
      return wrapped;
    case 'CBC':
      wrapped = CBCBlockCipher(cipher);
      wrapped.init(
        forEncryption,
        ParametersWithIV<KeyParameter>(keyParam, _padIv(iv, cipher.blockSize)),
      );
      return wrapped;
    case 'CFB':
      wrapped = CFBBlockCipher(cipher, cipher.blockSize);
      wrapped.init(
        forEncryption,
        ParametersWithIV<KeyParameter>(keyParam, _padIv(iv, cipher.blockSize)),
      );
      return wrapped;
    case 'OFB':
      wrapped = OFBBlockCipher(cipher, cipher.blockSize);
      wrapped.init(
        forEncryption,
        ParametersWithIV<KeyParameter>(keyParam, _padIv(iv, cipher.blockSize)),
      );
      return wrapped;
    case 'CTR':
      wrapped = CTRBlockCipher(cipher.blockSize, CTRStreamCipher(cipher));
      wrapped.init(
        forEncryption,
        ParametersWithIV<KeyParameter>(keyParam, _padIv(iv, cipher.blockSize)),
      );
      return wrapped;
    default:
      throw ArgumentError('Unsupported cipher mode: $mode');
  }
}

Uint8List _padIv(List<int> iv, int blockSize) {
  if (iv.length >= blockSize) {
    return Uint8List.fromList(iv.take(blockSize).toList(growable: false));
  }
  return Uint8List.fromList(<int>[
    ...iv,
    ...List<int>.filled(blockSize - iv.length, 0),
  ]);
}

Uint8List _processBlocks(BlockCipher cipher, List<int> input) {
  final source = Uint8List.fromList(input);
  final output = Uint8List(source.length);
  var offset = 0;
  while (offset < source.length) {
    cipher.processBlock(source, offset, output, offset);
    offset += cipher.blockSize;
  }
  return output;
}

Map<String, dynamic> _cipherResult(List<int> bytes) {
  return <String, dynamic>{
    'bytes': bytes,
    'hex': _toHex(bytes),
    'base64': base64Encode(bytes),
  };
}

Map<String, dynamic> _wordArray(List<int> bytes) {
  return <String, dynamic>{
    'bytes': bytes,
    'hex': _toHex(bytes),
    'base64': base64Encode(bytes),
  };
}

List<int> _readBytes(dynamic value) {
  if (value is List<int>) return value;
  if (value is List) {
    return value.map((entry) => (entry as num).toInt()).toList(growable: false);
  }
  return const <int>[];
}

Map<String, dynamic> _readObject(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  return <String, dynamic>{};
}

String _toHex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
