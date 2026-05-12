import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/runtime/internal/plugin_runtime_html_entities_bridge.dart';

void main() {
  const bridge = PluginRuntimeHtmlEntitiesBridge();

  group('PluginRuntimeHtmlEntitiesBridge decode', () {
    test('decodes the seven entities the plan calls out', () {
      expect(bridge.decode('&amp;'), '&');
      expect(bridge.decode('&lt;'), '<');
      expect(bridge.decode('&#x4e2d;'), '\u4e2d');
      expect(bridge.decode('&#20013;'), '\u4e2d');
      expect(bridge.decode('&quot;'), '"');
      expect(bridge.decode('&apos;'), "'");
      expect(bridge.decode('&nbsp;'), '\u00A0');
    });

    test('decodes mixed strings without swallowing surrounding text', () {
      expect(
        bridge.decode('Tom &amp; Jerry &lt;3 &ldquo;Hi&rdquo;'),
        'Tom & Jerry <3 \u201CHi\u201D',
      );
    });

    test('leaves unknown entities verbatim so they surface in logs', () {
      expect(bridge.decode('&notarealentity;'), '&notarealentity;');
      expect(bridge.decode('&#xZZ;'), '&#xZZ;');
    });

    test('handles bare ampersands without hanging or losing characters', () {
      expect(bridge.decode('a & b'), 'a & b');
      expect(bridge.decode('&amp'), '&amp');
    });
  });

  group('PluginRuntimeHtmlEntitiesBridge encode', () {
    test('encodes XML-critical characters', () {
      expect(bridge.encode('<script>'), '&lt;script&gt;');
      expect(bridge.encode('Tom & Jerry'), 'Tom &amp; Jerry');
      expect(bridge.encode('"hi"'), '&quot;hi&quot;');
      expect(bridge.encode("it's"), 'it&#x27;s');
    });

    test('encodes non-ASCII runes as hex numeric references', () {
      expect(bridge.encode('中'), '&#x4E2D;');
    });

    test('round-trips with decode for common strings', () {
      const samples = <String>[
        'plain ascii',
        'Tom & Jerry',
        '<html>',
        'it\'s "ok"',
        '中文 and \u00A0 space',
      ];
      for (final sample in samples) {
        expect(bridge.decode(bridge.encode(sample)), sample);
      }
    });
  });
}
