import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/runtime/internal/plugin_runtime_host_bridges.dart';

void main() {
  group('plugin runtime bridges', () {
    test('crypto bridge supports hmac sha1 and base64 parsing', () {
      final hashPayload =
          jsonDecode(
                handleCryptoBridge(<String, dynamic>{
                  'action': 'hash',
                  'algorithm': 'hmacsha1',
                  'value': 'hello',
                  'key': 'world',
                }),
              )
              as Map<String, dynamic>;

      expect(hashPayload['base64'], isNotEmpty);

      final base64Payload =
          jsonDecode(
                handleCryptoBridge(<String, dynamic>{
                  'action': 'base64Parse',
                  'value': 'aGVsbG8=',
                }),
              )
              as Map<String, dynamic>;

      expect(base64Payload['text'], 'hello');
    });

    test('crypto bridge supports aes encrypt and hmac sha256', () {
      final aesPayload =
          jsonDecode(
                handleCryptoBridge(<String, dynamic>{
                  'action': 'aesEncrypt',
                  'valueText': 'hello',
                  'valueBytes': <int>[104, 101, 108, 108, 111],
                  'keyBytes': utf8.encode('0123456789abcdef'),
                  'ivBytes': utf8.encode('0102030405060708'),
                }),
              )
              as Map<String, dynamic>;

      expect(aesPayload['base64'], isNotEmpty);
      expect(aesPayload['hex'], isNotEmpty);

      final hmacPayload =
          jsonDecode(
                handleCryptoBridge(<String, dynamic>{
                  'action': 'hash',
                  'algorithm': 'hmacsha256',
                  'value': 'hello',
                  'key': 'world',
                }),
              )
              as Map<String, dynamic>;

      expect(hmacPayload['hex'], isNotEmpty);
    });

    test('crypto bridge supports aes encrypt without iv for ecb mode', () {
      final aesPayload =
          jsonDecode(
                handleCryptoBridge(<String, dynamic>{
                  'action': 'aesEncrypt',
                  'valueText': 'hello',
                  'valueBytes': <int>[104, 101, 108, 108, 111],
                  'keyBytes': utf8.encode('0CoJUm6Qyw8W8jud'),
                  'ivBytes': const <int>[],
                  'mode': 'ECB',
                }),
              )
              as Map<String, dynamic>;

      expect(aesPayload['base64'], isNotEmpty);
    });

    test('cheerio bridge extracts text and attributes from css selectors', () {
      final payload =
          jsonDecode(
                handleCheerioBridge(<String, dynamic>{
                  'html': '''
<html>
  <body>
    <script id="__NEXT_DATA__">{"buildId":"abc123"}</script>
    <a class="target" href="https://example.com">Link</a>
  </body>
</html>
''',
                  'selector': 'script#__NEXT_DATA__, a.target',
                }),
              )
              as Map<String, dynamic>;

      final nodes = payload['nodes'] as List<dynamic>;
      expect(nodes, hasLength(2));
      expect(
        (nodes.first as Map<String, dynamic>)['text'],
        contains('buildId'),
      );
      expect(
        (nodes.last as Map<String, dynamic>)['attributes']['href'],
        'https://example.com',
      );
    });

    test('cheerio bridge preserves tag names and direct child nodes', () {
      final payload =
          jsonDecode(
                handleCheerioBridge(<String, dynamic>{
                  'html': '''
<div class="root">
  <ul>
    <li class="first">A</li>
    <li class="second">B</li>
  </ul>
</div>
''',
                  'selector': 'ul',
                }),
              )
              as Map<String, dynamic>;

      final node =
          (payload['nodes'] as List<dynamic>).single as Map<String, dynamic>;
      final children = node['children'] as List<dynamic>;
      expect(node['tagName'], 'ul');
      expect(children, hasLength(2));
      expect((children.first as Map<String, dynamic>)['tagName'], 'li');
    });
  });
}
