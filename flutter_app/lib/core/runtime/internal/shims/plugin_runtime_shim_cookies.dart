/// `@react-native-cookies/cookies` shim.
String buildShimCookies() {
  return r'''
const __musicfree_cookiesApi = {
  get: async function(url) {
    const r = await __musicfree_callBridgeAsync('MusicFreeCookies', {
      action: 'get', url: String(url || ''),
    });
    return r.value || {};
  },
  getAll: async function() {
    const r = await __musicfree_callBridgeAsync('MusicFreeCookies', {
      action: 'getAll',
    });
    return r.value || {};
  },
  set: async function(url, cookie) {
    const r = await __musicfree_callBridgeAsync('MusicFreeCookies', {
      action: 'set', url: String(url || ''), cookie: cookie || {},
    });
    return !!r.value;
  },
  clearAll: async function() {
    await __musicfree_callBridgeAsync('MusicFreeCookies', { action: 'clearAll' });
  },
  clearByName: async function(url, name) {
    await __musicfree_callBridgeAsync('MusicFreeCookies', {
      action: 'clearByName',
      url: String(url || ''),
      name: String(name || ''),
    });
  },
  clearByDomain: async function(domain) {
    await __musicfree_callBridgeAsync('MusicFreeCookies', {
      action: 'clearByDomain',
      domain: String(domain || ''),
    });
  },
  flush: async function() {
    await __musicfree_callBridgeAsync('MusicFreeCookies', { action: 'flush' });
  },
};
''';
}
