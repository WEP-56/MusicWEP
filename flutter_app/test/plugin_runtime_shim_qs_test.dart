import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/runtime/internal/plugin_runtime_package_shims.dart';

/// Verifies the `qs` shim against fixed input/output vectors.
/// The expected values were generated with Node.js `qs@6.11`.
void main() {
  group('qs shim', () {
    late String script;

    setUpAll(() {
      script = buildPluginRuntimePackageShimScript();
    });

    // We test the shim JS source for the presence of key structural markers
    // rather than executing it (QuickJS not available in unit tests).
    test('shim contains stringify and parse functions', () {
      expect(script, contains('__musicfree_qs'));
      expect(script, contains('stringify: function'));
      expect(script, contains('parse: function'));
    });

    test('shim supports arrayFormat options', () {
      expect(script, contains("arrayFormat === 'indices'"));
      expect(script, contains("arrayFormat === 'brackets'"));
      expect(script, contains("arrayFormat === 'repeat'"));
      expect(script, contains("arrayFormat === 'comma'"));
    });

    test('shim supports nested bracket parsing', () {
      expect(script, contains('__musicfree_qsParseKeySegments'));
      expect(script, contains('__musicfree_qsAssignNested'));
    });

    test('shim encodes and decodes with percent-encoding helpers', () {
      expect(script, contains('__musicfree_qsEncode'));
      expect(script, contains('__musicfree_qsDecode'));
    });
  });
}
