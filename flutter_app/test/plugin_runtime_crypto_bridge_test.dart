import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/runtime/internal/plugin_runtime_crypto_bridge.dart';

void main() {
  group('PluginRuntimeCryptoBridge', () {
    // ---- Hashing -----------------------------------------------------------

    test('MD5 produces known hex digest', () {
      final result = jsonDecode(
        handleCryptoBridge(<String, dynamic>{
          'action': 'hash',
          'algorithm': 'md5',
          'valueBytes': utf8.encode('hello'),
        }),
      ) as Map<String, dynamic>;
      expect(result['hex'], '5d41402abc4b2a76b9719d911017c592');
    });

    test('SHA-256 produces known hex digest', () {
      final result = jsonDecode(
        handleCryptoBridge(<String, dynamic>{
          'action': 'hash',
          'algorithm': 'sha256',
          'valueBytes': utf8.encode(''),
        }),
      ) as Map<String, dynamic>;
      expect(
        result['hex'],
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('HmacSHA256 matches RFC 4231 test vector', () {
      // Key = 0x0b * 20, data = "Hi There"
      final key = List<int>.filled(20, 0x0b);
      final data = utf8.encode('Hi There');
      final result = jsonDecode(
        handleCryptoBridge(<String, dynamic>{
          'action': 'hmac',
          'algorithm': 'sha256',
          'valueBytes': data,
          'keyBytes': key,
        }),
      ) as Map<String, dynamic>;
      expect(
        result['hex'],
        'b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7',
      );
    });

    test('legacy hmacsha1 shortcut still works', () {
      final result = jsonDecode(
        handleCryptoBridge(<String, dynamic>{
          'action': 'hash',
          'algorithm': 'hmacsha1',
          'value': 'hello',
          'key': 'world',
        }),
      ) as Map<String, dynamic>;
      expect(result['base64'], isNotEmpty);
    });

    // ---- AES encrypt → decrypt round-trip ----------------------------------

    test('AES-CBC encrypt then decrypt round-trips plaintext', () {
      final key = utf8.encode('0123456789abcdef'); // 16 bytes
      final iv = utf8.encode('0102030405060708'); // 16 bytes
      const plaintext = 'Hello, MusicFree!';

      final encrypted = jsonDecode(
        handleCryptoBridge(<String, dynamic>{
          'action': 'aesEncrypt',
          'valueText': plaintext,
          'valueBytes': utf8.encode(plaintext),
          'keyBytes': key,
          'ivBytes': iv,
          'mode': 'CBC',
          'padding': 'pkcs7',
        }),
      ) as Map<String, dynamic>;
      expect(encrypted['base64'], isNotEmpty);

      final decrypted = jsonDecode(
        handleCryptoBridge(<String, dynamic>{
          'action': 'aesDecrypt',
          'ciphertextBase64': encrypted['base64'],
          'keyBytes': key,
          'ivBytes': iv,
          'mode': 'CBC',
          'padding': 'pkcs7',
        }),
      ) as Map<String, dynamic>;
      expect(
        utf8.decode(
          (decrypted['bytes'] as List<dynamic>)
              .map((e) => (e as num).toInt())
              .toList(),
        ),
        plaintext,
      );
    });

    test('AES-ECB encrypt then decrypt round-trips plaintext', () {
      final key = utf8.encode('0CoJUm6Qyw8W8jud'); // 16 bytes
      const plaintext = 'secret';

      final encrypted = jsonDecode(
        handleCryptoBridge(<String, dynamic>{
          'action': 'aesEncrypt',
          'valueText': plaintext,
          'valueBytes': utf8.encode(plaintext),
          'keyBytes': key,
          'ivBytes': <int>[],
          'mode': 'ECB',
          'padding': 'pkcs7',
        }),
      ) as Map<String, dynamic>;
      expect(encrypted['base64'], isNotEmpty);

      final decrypted = jsonDecode(
        handleCryptoBridge(<String, dynamic>{
          'action': 'aesDecrypt',
          'ciphertextBase64': encrypted['base64'],
          'keyBytes': key,
          'ivBytes': <int>[],
          'mode': 'ECB',
          'padding': 'pkcs7',
        }),
      ) as Map<String, dynamic>;
      expect(
        utf8.decode(
          (decrypted['bytes'] as List<dynamic>)
              .map((e) => (e as num).toInt())
              .toList(),
        ),
        plaintext,
      );
    });

    test('TripleDES-CBC encrypt then decrypt round-trips plaintext', () {
      // 3DES requires 24-byte key.
      final key = utf8.encode('0123456789abcdef01234567');
      final iv = utf8.encode('01234567');
      const plaintext = 'triple-des test';

      final encrypted = jsonDecode(
        handleCryptoBridge(<String, dynamic>{
          'action': 'tripleDesEncrypt',
          'valueText': plaintext,
          'valueBytes': utf8.encode(plaintext),
          'keyBytes': key,
          'ivBytes': iv,
          'mode': 'CBC',
          'padding': 'pkcs7',
        }),
      ) as Map<String, dynamic>;
      expect(encrypted['base64'], isNotEmpty);

      final decrypted = jsonDecode(
        handleCryptoBridge(<String, dynamic>{
          'action': 'tripleDesDecrypt',
          'ciphertextBase64': encrypted['base64'],
          'keyBytes': key,
          'ivBytes': iv,
          'mode': 'CBC',
          'padding': 'pkcs7',
        }),
      ) as Map<String, dynamic>;
      expect(
        utf8.decode(
          (decrypted['bytes'] as List<dynamic>)
              .map((e) => (e as num).toInt())
              .toList(),
        ),
        plaintext,
      );
    });

    // ---- Encoders ----------------------------------------------------------

    test('base64 parse and stringify round-trip', () {
      const original = 'hello world';
      final parsed = jsonDecode(
        handleCryptoBridge(<String, dynamic>{
          'action': 'base64Parse',
          'value': base64Encode(utf8.encode(original)),
        }),
      ) as Map<String, dynamic>;
      expect(parsed['text'], original);

      final stringified = jsonDecode(
        handleCryptoBridge(<String, dynamic>{
          'action': 'base64Stringify',
          'bytes': parsed['bytes'],
        }),
      ) as Map<String, dynamic>;
      expect(stringified['value'], base64Encode(utf8.encode(original)));
    });

    test('hex parse and stringify round-trip', () {
      const hex = 'deadbeef';
      final parsed = jsonDecode(
        handleCryptoBridge(<String, dynamic>{
          'action': 'hexParse',
          'value': hex,
        }),
      ) as Map<String, dynamic>;
      expect(parsed['bytes'], <int>[0xde, 0xad, 0xbe, 0xef]);

      final stringified = jsonDecode(
        handleCryptoBridge(<String, dynamic>{
          'action': 'hexStringify',
          'bytes': parsed['bytes'],
        }),
      ) as Map<String, dynamic>;
      expect(stringified['value'], hex);
    });

    test('latin1 parse and stringify round-trip', () {
      const original = 'caf\u00e9'; // café
      final parsed = jsonDecode(
        handleCryptoBridge(<String, dynamic>{
          'action': 'latin1Parse',
          'value': original,
        }),
      ) as Map<String, dynamic>;
      expect(parsed['bytes'], isNotEmpty);

      final stringified = jsonDecode(
        handleCryptoBridge(<String, dynamic>{
          'action': 'latin1Stringify',
          'bytes': parsed['bytes'],
        }),
      ) as Map<String, dynamic>;
      expect(stringified['value'], original);
    });
  });
}
