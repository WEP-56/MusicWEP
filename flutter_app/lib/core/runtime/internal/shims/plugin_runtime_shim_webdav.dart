/// `webdav` shim — delegates every side-effecting method to `MusicFreeWebDav`.
String buildShimWebdav() {
  return r'''
const __musicfree_webdav = {
  AuthType: { Password: 'password' },
  createClient: function(baseUrl, options) {
    const settings = options || {};
    const callWebDav = function(action, extra) {
      if (!__musicfree_allowNetworkAccess) {
        return __musicfree_rejectBlockedSideEffect('webdav.' + action);
      }
      return __musicfree_callBridgeAsync('MusicFreeWebDav', Object.assign({
        action: action,
        baseUrl: String(baseUrl || ''),
        username: settings.username || '',
        password: settings.password || '',
      }, extra || {}));
    };
    return {
      getDirectoryContents: async function(remotePath) {
        const r = await callWebDav('getDirectoryContents', { path: String(remotePath || '/') });
        return (r && r.value) || [];
      },
      getFileContents: async function(remotePath, options) {
        const r = await callWebDav('getFileContents', {
          path: String(remotePath || ''),
          format: (options && options.format) || 'binary',
        });
        if (!r || r.error) throw new Error('webdav: ' + (r && r.error || 'unknown error'));
        return r.value;
      },
      putFileContents: async function(remotePath, data, options) {
        const opts = options || {};
        const r = await callWebDav('putFileContents', {
          path: String(remotePath || ''),
          data: data,
          overwrite: opts.overwrite !== false,
        });
        if (!r || r.error) throw new Error('webdav: ' + (r && r.error || 'unknown error'));
        return r.value;
      },
      createDirectory: async function(remotePath) {
        const r = await callWebDav('createDirectory', { path: String(remotePath || '') });
        if (!r || r.error) throw new Error('webdav: ' + (r && r.error || 'unknown error'));
        return r.value;
      },
      exists: async function(remotePath) {
        const r = await callWebDav('exists', { path: String(remotePath || '') });
        return !!(r && r.value);
      },
      stat: async function(remotePath) {
        const r = await callWebDav('stat', { path: String(remotePath || '') });
        return (r && r.value) || null;
      },
      moveFile: async function(fromPath, toPath) {
        const r = await callWebDav('moveFile', {
          path: String(fromPath || ''),
          destination: String(toPath || ''),
        });
        if (!r || r.error) throw new Error('webdav: ' + (r && r.error || 'unknown error'));
        return r.value;
      },
      copyFile: async function(fromPath, toPath) {
        const r = await callWebDav('copyFile', {
          path: String(fromPath || ''),
          destination: String(toPath || ''),
        });
        if (!r || r.error) throw new Error('webdav: ' + (r && r.error || 'unknown error'));
        return r.value;
      },
      deleteFile: async function(remotePath) {
        const r = await callWebDav('deleteFile', { path: String(remotePath || '') });
        if (!r || r.error) throw new Error('webdav: ' + (r && r.error || 'unknown error'));
        return r.value;
      },
      getFileDownloadLink: async function(remotePath) {
        const r = await callWebDav('getFileDownloadLink', { path: String(remotePath || '') });
        return (r && r.value) || '';
      },
    };
  },
};
''';
}
