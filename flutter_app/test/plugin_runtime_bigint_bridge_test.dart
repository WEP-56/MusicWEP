import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/runtime/internal/plugin_runtime_bigint_bridge.dart';

void main() {
  group('plugin runtime bigint bridge', () {
    test('creates values with radix and supports modPow', () async {
      final bridge = PluginRuntimeBigIntBridge();

      final created =
          jsonDecode(
                bridge.handle(<String, dynamic>{
                  'action': 'create',
                  'value': 'ff',
                  'radix': 16,
                }),
              )
              as Map<String, dynamic>;

      expect(created['value'], '255');

      final powered =
          jsonDecode(
                bridge.handle(<String, dynamic>{
                  'action': 'modPow',
                  'base': '255',
                  'exponent': '3',
                  'modulus': '13',
                }),
              )
              as Map<String, dynamic>;

      expect(powered['value'], '5');
    });
  });
}
