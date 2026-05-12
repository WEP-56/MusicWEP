/// `he` shim — delegates to the `MusicFreeHtmlEntities` bridge.
String buildShimHe() {
  return r'''
const __musicfree_he = {
  decode: function(value) {
    if (value === null || value === undefined) return '';
    const text = String(value);
    if (text.indexOf('&') === -1) return text;
    const r = __musicfree_callBridge('MusicFreeHtmlEntities', {
      action: 'decode', value: text,
    });
    return (r && r.value != null) ? r.value : text;
  },
  encode: function(value) {
    if (value === null || value === undefined) return '';
    const text = String(value);
    if (text.length === 0) return text;
    const r = __musicfree_callBridge('MusicFreeHtmlEntities', {
      action: 'encode', value: text,
    });
    return (r && r.value != null) ? r.value : text;
  },
  escape: function(value) { return this.encode(value); },
  unescape: function(value) { return this.decode(value); },
};
''';
}
