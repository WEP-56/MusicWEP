import 'shims/plugin_runtime_shim_axios.dart';
import 'shims/plugin_runtime_shim_bigint.dart';
import 'shims/plugin_runtime_shim_cheerio.dart';
import 'shims/plugin_runtime_shim_common.dart';
import 'shims/plugin_runtime_shim_cookies.dart';
import 'shims/plugin_runtime_shim_cryptojs.dart';
import 'shims/plugin_runtime_shim_dayjs.dart';
import 'shims/plugin_runtime_shim_he.dart';
import 'shims/plugin_runtime_shim_qs.dart';
import 'shims/plugin_runtime_shim_storage.dart';
import 'shims/plugin_runtime_shim_webdav.dart';

/// Composes every package shim into a single JS block the shared scope
/// builder evaluates inside the plugin's closure.
String buildPluginRuntimePackageShimScript() {
  return <String>[
    buildShimUrlPolyfill(),
    buildShimBridgeHelpers(),
    buildShimUnsupported(),
    buildShimCrypto(),
    buildShimCheerio(),
    buildShimBigInt(),
    buildShimQs(),
    buildShimDayjs(),
    buildShimHe(),
    buildShimAxios(),
    buildShimCookies(),
    buildShimWebdav(),
    buildShimStorage(),
    _packageRegistry,
  ].join('\n');
}

// The final package registry plugins see. Every entry should resolve to one
// of the values defined by the shim blocks above.
const _packageRegistry = r'''
const __musicfree_packages = {
  axios: __musicfree_makeAxios({}),
  cheerio: __musicfree_cheerio,
  'crypto-js': __musicfree_cryptoJs,
  qs: __musicfree_qs,
  he: __musicfree_he,
  dayjs: __musicfree_makeDayjs,
  'big-integer': __musicfree_makeBigInteger,
  '@react-native-cookies/cookies': __musicfree_cookiesApi,
  webdav: __musicfree_webdav,
  'musicfree/storage': __musicfree_storageApi,
};
''';
