/// `musicfree/storage` shim — talks to the storage channel. This is an
/// internal utility every plugin is free to use.
String buildShimStorage() {
  return r'''
const __musicfree_storageApi = {
  getItem: async function(key) {
    const r = await __musicfree_callBridgeAsync('MusicFreeStorage', {
      action: 'getItem', key: String(key || ''),
    });
    return r.value == null ? null : String(r.value);
  },
  setItem: async function(key, value) {
    await __musicfree_callBridgeAsync('MusicFreeStorage', {
      action: 'setItem',
      key: String(key || ''),
      value: value == null ? null : String(value),
    });
  },
  removeItem: async function(key) {
    await __musicfree_callBridgeAsync('MusicFreeStorage', {
      action: 'removeItem', key: String(key || ''),
    });
  },
};
''';
}
