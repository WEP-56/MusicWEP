import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/runtime/internal/plugin_runtime_http_bridge.dart';
import 'package:flutter_app/core/runtime/internal/plugin_runtime_package_shims.dart';

void main() {
  group('plugin runtime http bridge', () {
    test(
      'sends requests through dart http and decodes json responses',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          expect(request.method, 'POST');
          expect(request.headers.value('x-test-header'), 'bridge');
          final body = await utf8.decoder.bind(request).join();

          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, dynamic>{
              'ok': true,
              'body': body,
              'contentType': request.headers.contentType?.mimeType,
            }),
          );
          await request.response.close();
        });

        final bridge = PluginRuntimeHttpBridge();
        addTearDown(bridge.dispose);

        final payload =
            jsonDecode(
                  await bridge.handle(<String, dynamic>{
                    'action': 'request',
                    'url':
                        'http://${server.address.host}:${server.port}/search',
                    'method': 'POST',
                    'headers': <String, String>{
                      'content-type': 'application/x-www-form-urlencoded',
                      'x-test-header': 'bridge',
                    },
                    'body': 'keywords=abc',
                    'responseType': 'json',
                    'timeout': 5000,
                  }),
                )
                as Map<String, dynamic>;

        expect(payload['status'], 200);
        expect(payload['data']['ok'], true);
        expect(payload['data']['body'], 'keywords=abc');
        expect(
          payload['data']['contentType'],
          'application/x-www-form-urlencoded',
        );
      },
    );

    test('decodes json payloads served as text plain', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        request.response.headers.contentType = ContentType.text;
        request.response.write('{"data":{"lists":[1,2,3]}}');
        await request.response.close();
      });

      final bridge = PluginRuntimeHttpBridge();
      addTearDown(bridge.dispose);

      final payload =
          jsonDecode(
                await bridge.handle(<String, dynamic>{
                  'action': 'request',
                  'url':
                      'http://${server.address.host}:${server.port}/plain-json',
                  'method': 'GET',
                }),
              )
              as Map<String, dynamic>;

      expect(payload['data']['data']['lists'], <dynamic>[1, 2, 3]);
    });

    test('decodes json payloads wrapped by control characters', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        request.response.headers.contentType = ContentType.text;
        request.response.add(<int>[
          0x05,
          0x10,
          ...utf8.encode('{"msg":"blocked","data":null}'),
          0x03,
        ]);
        await request.response.close();
      });

      final bridge = PluginRuntimeHttpBridge();
      addTearDown(bridge.dispose);

      final payload =
          jsonDecode(
                await bridge.handle(<String, dynamic>{
                  'action': 'request',
                  'url':
                      'http://${server.address.host}:${server.port}/framed-json',
                  'method': 'GET',
                }),
              )
              as Map<String, dynamic>;

      expect(payload['data']['msg'], 'blocked');
      expect(payload['data']['data'], isNull);
    });

    test(
      'drops unsupported br encoding before forwarding plugin requests',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        const brotliPayload = <int>[
          27,
          63,
          0,
          224,
          157,
          9,
          182,
          77,
          162,
          237,
          134,
          46,
          120,
          96,
          136,
          252,
          8,
          149,
          222,
          34,
          123,
          46,
          125,
          187,
          77,
          110,
          174,
          78,
          177,
          232,
          180,
          200,
          204,
          25,
          91,
          112,
          200,
          129,
          195,
          215,
          22,
          112,
          152,
          120,
          224,
          80,
          9,
          68,
          205,
          122,
          229,
          118,
          38,
          52,
          217,
          32,
          216,
          97,
          246,
          106,
          50,
          21,
          109,
          206,
          6,
          121,
          154,
          31,
        ];

        server.listen((request) async {
          final acceptEncoding = request.headers.value('accept-encoding') ?? '';
          if (acceptEncoding.contains('br')) {
            request.response.headers.set('content-encoding', 'br');
            request.response.headers.contentType = ContentType.json;
            request.response.add(brotliPayload);
          } else {
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode(<String, dynamic>{
                'msg': 'ok',
                'requestEncoding': acceptEncoding,
              }),
            );
          }
          await request.response.close();
        });

        final bridge = PluginRuntimeHttpBridge();
        addTearDown(bridge.dispose);

        final payload =
            jsonDecode(
                  await bridge.handle(<String, dynamic>{
                    'action': 'request',
                    'url':
                        'http://${server.address.host}:${server.port}/brotli',
                    'method': 'GET',
                    'headers': <String, String>{
                      'accept-encoding': 'gzip, deflate, br',
                    },
                  }),
                )
                as Map<String, dynamic>;

        expect(payload['status'], 200);
        expect(payload['data']['msg'], 'ok');
        expect(payload['data']['requestEncoding'], 'gzip, deflate');
      },
    );

    test('axios shim keeps request alias for parcel-transpiled plugins', () {
      final script = buildPluginRuntimePackageShimScript();

      expect(script, contains('axios.request = function(config)'));
      expect(script, contains('application/x-www-form-urlencoded'));
      expect(script, contains('application/json, text/plain, */*'));
      expect(
        script,
        contains('Blocked plugin side effect during initialization'),
      );
      expect(script, contains("action: 'request'"));
      expect(script, contains('const __musicfree_callBridgeAsync = function'));
      expect(
        script,
        contains("await __musicfree_callBridgeAsync('MusicFreeCookies'"),
      );
      expect(
        script,
        contains("await __musicfree_callBridgeAsync('MusicFreeStorage'"),
      );
      expect(script, contains('AES: {'));
      expect(script, contains('children: function(selector)'));
      expect(script, contains('modPow: function(exponent, modulus)'));
      expect(script, contains("action: 'create'"));
      expect(script, contains("loader.text = rootCollection.text"));
    });
  });
}
