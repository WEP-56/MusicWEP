import 'dart:convert';

import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

/// Cheerio bridge. The JS shim calls us once with `{action: 'parse', html}`
/// and we return the entire document tree — every subsequent selector,
/// traversal and `.each()` runs in JS against the returned JSON tree.
///
/// Node shape:
/// ```json
/// {
///   "tag": "div" | null,          // null for text / comment nodes
///   "text": "concatenated text",  // only for text nodes; the JS side walks
///                                  // children for element text()
///   "attrs": {"class": "x y"},
///   "children": [...],
///   "innerHtml": "inner markup",
///   "outerHtml": "<div>...</div>",
///   "raw": "text content"          // for text nodes
/// }
/// ```
String handleCheerioBridge(dynamic args) {
  final payload = _readObject(args);
  // Use an empty string as the default so the switch falls through to the
  // legacy selector path when no `action` key is present. The new shim
  // explicitly sends `action: 'parse'`.
  final action = payload['action']?.toString() ?? '';

  switch (action) {
    case 'parse':
      return _handleParse(payload);
    // Default (empty string) and legacy `select` both use the old path.
    default:
      return _handleLegacySelect(payload);
  }
}

String _handleParse(Map<String, dynamic> payload) {
  final html = payload['html']?.toString() ?? '';
  final document = html_parser.parse(html);
  return jsonEncode(<String, dynamic>{
    'root': _serializeNode(document.documentElement ?? document),
  });
}

String _handleLegacySelect(Map<String, dynamic> payload) {
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

List<Map<String, dynamic>> _selectNodes(dynamic document, String selector) {
  final elements = selector.isEmpty
      ? document.querySelectorAll('html')
      : document.querySelectorAll(selector);
  final nodes = <Map<String, dynamic>>[];
  for (final element in elements) {
    if (element is html_dom.Element) {
      nodes.add(_serializeLegacyElement(element));
    }
  }
  return nodes;
}

Map<String, dynamic> _serializeLegacyElement(html_dom.Element element) {
  return <String, dynamic>{
    'tag': element.localName,
    'tagName': element.localName,
    'text': element.text,
    'html': element.innerHtml,
    'innerHtml': element.innerHtml,
    'outerHtml': element.outerHtml,
    'attrs': Map<String, String>.from(element.attributes),
    'attributes': Map<String, String>.from(element.attributes),
    'children': element.children
        .map(_serializeLegacyElement)
        .toList(growable: false),
  };
}

Map<String, dynamic> _serializeNode(html_dom.Node node) {
  if (node is html_dom.Element) {
    return <String, dynamic>{
      'tag': node.localName,
      'attrs': Map<String, String>.from(
        node.attributes.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
      ),
      'text': _elementText(node),
      'innerHtml': node.innerHtml,
      'outerHtml': node.outerHtml,
      'children': _childrenFor(node),
    };
  }
  if (node is html_dom.Text) {
    final text = node.text;
    return <String, dynamic>{
      'tag': null,
      'text': text,
      'raw': text,
      'attrs': <String, String>{},
      'children': const <Map<String, dynamic>>[],
      'innerHtml': '',
      'outerHtml': text,
    };
  }
  return <String, dynamic>{
    'tag': null,
    'text': '',
    'attrs': <String, String>{},
    'children': const <Map<String, dynamic>>[],
    'innerHtml': '',
    'outerHtml': '',
  };
}

/// Returns the concatenated text content of [element], mimicking
/// `element.text` but serialised alongside the tree so the JS shim never
/// has to re-read it.
String _elementText(html_dom.Element element) {
  final buffer = StringBuffer();
  for (final child in element.nodes) {
    if (child is html_dom.Text) {
      buffer.write(child.text);
    } else if (child is html_dom.Element) {
      buffer.write(_elementText(child));
    }
  }
  return buffer.toString();
}

List<Map<String, dynamic>> _childrenFor(html_dom.Element element) {
  final children = <Map<String, dynamic>>[];
  for (final child in element.nodes) {
    if (child is html_dom.Element || child is html_dom.Text) {
      children.add(_serializeNode(child));
    }
  }
  return children;
}

Map<String, dynamic> _readObject(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  return <String, dynamic>{};
}
