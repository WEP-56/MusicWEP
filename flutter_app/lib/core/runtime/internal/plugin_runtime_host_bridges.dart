// This file used to contain every host-side bridge handler. To keep each
// responsibility under 300 lines we now re-export from dedicated bridge
// files. Tests and runtime callers keep working because the public handler
// names have not changed.

export 'plugin_runtime_cheerio_bridge.dart' show handleCheerioBridge;
export 'plugin_runtime_crypto_bridge.dart' show handleCryptoBridge;
