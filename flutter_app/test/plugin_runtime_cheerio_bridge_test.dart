import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/runtime/internal/plugin_runtime_cheerio_bridge.dart';

void main() {
  group('PluginRuntimeCheerioBridge parse action', () {
    test('returns a root node with tag, attrs, children, text, innerHtml', () {
      final result = jsonDecode(
        handleCheerioBridge(<String, dynamic>{
          'action': 'parse',
          'html': '<div class="root"><p id="p1">Hello</p></div>',
        }),
      ) as Map<String, dynamic>;

      expect(result['root'], isNotNull);
      final root = result['root'] as Map<String, dynamic>;
      // The html parser wraps in <html><head/><body>…</body></html>.
      expect(root['tag'], 'html');
      expect(root['children'], isA<List>());
    });

    test('serialises element attributes correctly', () {
      final result = jsonDecode(
        handleCheerioBridge(<String, dynamic>{
          'action': 'parse',
          'html': '<a href="https://example.com" class="link">text</a>',
        }),
      ) as Map<String, dynamic>;

      // Walk to the <a> element.
      final root = result['root'] as Map<String, dynamic>;
      final a = _findFirst(root, 'a');
      expect(a, isNotNull);
      expect((a!['attrs'] as Map)['href'], 'https://example.com');
      expect((a['attrs'] as Map)['class'], 'link');
    });

    test('serialises text content in the text field', () {
      final result = jsonDecode(
        handleCheerioBridge(<String, dynamic>{
          'action': 'parse',
          'html': '<p>Hello World</p>',
        }),
      ) as Map<String, dynamic>;

      final root = result['root'] as Map<String, dynamic>;
      final p = _findFirst(root, 'p');
      expect(p, isNotNull);
      expect(p!['text'], contains('Hello World'));
    });

    test('includes innerHtml and outerHtml for elements', () {
      final result = jsonDecode(
        handleCheerioBridge(<String, dynamic>{
          'action': 'parse',
          'html': '<div><span>inner</span></div>',
        }),
      ) as Map<String, dynamic>;

      final root = result['root'] as Map<String, dynamic>;
      final div = _findFirst(root, 'div');
      expect(div, isNotNull);
      expect(div!['innerHtml'], contains('span'));
      expect(div['outerHtml'], contains('<div>'));
    });

    test('legacy selector path still works without action key', () {
      final result = jsonDecode(
        handleCheerioBridge(<String, dynamic>{
          'html': '<ul><li class="a">A</li><li class="b">B</li></ul>',
          'selector': 'li',
        }),
      ) as Map<String, dynamic>;

      final nodes = result['nodes'] as List<dynamic>;
      expect(nodes, hasLength(2));
      expect((nodes.first as Map)['text'], 'A');
    });
  });
}

/// Depth-first search for the first element with [tag].
Map<String, dynamic>? _findFirst(Map<String, dynamic> node, String tag) {
  if (node['tag'] == tag) return node;
  final children = node['children'] as List<dynamic>? ?? const <dynamic>[];
  for (final child in children) {
    if (child is Map<String, dynamic>) {
      final found = _findFirst(child, tag);
      if (found != null) return found;
    }
  }
  return null;
}
