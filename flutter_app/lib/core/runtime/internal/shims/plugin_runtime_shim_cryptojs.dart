/// crypto-js shim. Mirrors the CryptoJS word-array contract and delegates
/// every primitive to `MusicFreeCrypto`.
String buildShimCrypto() {
  final buffer = StringBuffer()
    ..write(_encodersJs)
    ..write(_cipherHelpersJs)
    ..write(_cryptoJsObjectJs);
  return buffer.toString();
}

const _encodersJs = r'''
const __musicfree_readCryptoInput = function(value) {
  if (value && Array.isArray(value.__musicfreeBytes)) {
    return {
      bytes: value.__musicfreeBytes,
      text: value.__musicfreeText == null ? null : String(value.__musicfreeText),
    };
  }
  if (typeof value === 'string') {
    return {
      bytes: Array.from(unescape(encodeURIComponent(value))).map(function(ch) {
        return ch.charCodeAt(0);
      }),
      text: value,
    };
  }
  return {
    bytes: [],
    text: value == null ? '' : String(value),
  };
};

const __musicfree_makeWordArray = function(bytes, text) {
  return {
    __musicfreeBytes: Array.isArray(bytes) ? bytes : [],
    __musicfreeText: text,
    sigBytes: Array.isArray(bytes) ? bytes.length : 0,
    clone: function() {
      return __musicfree_makeWordArray(this.__musicfreeBytes.slice(), this.__musicfreeText);
    },
    toString: function(encoder) {
      if (encoder === __musicfree_CryptoEnc.Base64) {
        return __musicfree_callBridge('MusicFreeCrypto', {
          action: 'base64Stringify',
          bytes: this.__musicfreeBytes,
        }).value;
      }
      if (encoder === __musicfree_CryptoEnc.Utf8) {
        return this.__musicfreeText != null
          ? this.__musicfreeText
          : __musicfree_callBridge('MusicFreeCrypto', {
              action: 'utf8Stringify',
              bytes: this.__musicfreeBytes,
            }).value;
      }
      if (encoder === __musicfree_CryptoEnc.Latin1) {
        return __musicfree_callBridge('MusicFreeCrypto', {
          action: 'latin1Stringify',
          bytes: this.__musicfreeBytes,
        }).value;
      }
      return __musicfree_callBridge('MusicFreeCrypto', {
        action: 'hexStringify',
        bytes: this.__musicfreeBytes,
      }).value;
    },
  };
};

const __musicfree_CryptoEnc = {
  Base64: {
    parse: function(value) {
      const r = __musicfree_callBridge('MusicFreeCrypto', {
        action: 'base64Parse', value: String(value || ''),
      });
      return __musicfree_makeWordArray(r.bytes, r.text);
    },
    stringify: function(wa) {
      return __musicfree_callBridge('MusicFreeCrypto', {
        action: 'base64Stringify', bytes: wa.__musicfreeBytes || [],
      }).value;
    },
  },
  Utf8: {
    parse: function(value) {
      const r = __musicfree_callBridge('MusicFreeCrypto', {
        action: 'utf8Parse', value: String(value || ''),
      });
      return __musicfree_makeWordArray(r.bytes, r.text);
    },
    stringify: function(wa) {
      return __musicfree_callBridge('MusicFreeCrypto', {
        action: 'utf8Stringify', bytes: wa.__musicfreeBytes || [],
      }).value;
    },
  },
  Hex: {
    parse: function(value) {
      const r = __musicfree_callBridge('MusicFreeCrypto', {
        action: 'hexParse', value: String(value || ''),
      });
      return __musicfree_makeWordArray(r.bytes, r.text);
    },
    stringify: function(wa) {
      return __musicfree_callBridge('MusicFreeCrypto', {
        action: 'hexStringify', bytes: wa.__musicfreeBytes || [],
      }).value;
    },
  },
  Latin1: {
    parse: function(value) {
      const r = __musicfree_callBridge('MusicFreeCrypto', {
        action: 'latin1Parse', value: String(value || ''),
      });
      return __musicfree_makeWordArray(r.bytes, r.text);
    },
    stringify: function(wa) {
      return __musicfree_callBridge('MusicFreeCrypto', {
        action: 'latin1Stringify', bytes: wa.__musicfreeBytes || [],
      }).value;
    },
  },
};
''';

const _cipherHelpersJs = r'''
const __musicfree_makeCryptoHash = function(algorithm, value) {
  const n = __musicfree_readCryptoInput(value);
  const r = __musicfree_callBridge('MusicFreeCrypto', {
    action: 'hash', algorithm: algorithm, valueBytes: n.bytes,
  });
  if (r && r.error) throw new Error('crypto-js: ' + r.error);
  return __musicfree_makeWordArray(r.bytes, null);
};

const __musicfree_makeCryptoHmac = function(algorithm, value, key) {
  const nv = __musicfree_readCryptoInput(value);
  const nk = __musicfree_readCryptoInput(key);
  const r = __musicfree_callBridge('MusicFreeCrypto', {
    action: 'hmac', algorithm: algorithm,
    valueBytes: nv.bytes, keyBytes: nk.bytes,
  });
  if (r && r.error) throw new Error('crypto-js: ' + r.error);
  return __musicfree_makeWordArray(r.bytes, null);
};

const __musicfree_readCipherOptions = function(options) {
  const o = options || {};
  return {
    iv: __musicfree_readCryptoInput(o.iv || ''),
    mode: o.mode ? String(o.mode) : 'CBC',
    padding: o.padding ? String(o.padding) : 'pkcs7',
  };
};

const __musicfree_readCiphertext = function(input) {
  if (typeof input === 'string') return { ciphertextBase64: input };
  if (input && input.ciphertext) {
    return { ciphertextBytes: input.ciphertext.__musicfreeBytes || [] };
  }
  if (input && input.__musicfreeBytes) {
    return { ciphertextBytes: input.__musicfreeBytes };
  }
  return { ciphertextBytes: [] };
};

const __musicfree_runCipher = function(action, value, key, options) {
  const nv = __musicfree_readCryptoInput(value);
  const nk = __musicfree_readCryptoInput(key);
  const cfg = __musicfree_readCipherOptions(options);
  const r = __musicfree_callBridge('MusicFreeCrypto', {
    action: action,
    valueText: nv.text, valueBytes: nv.bytes,
    keyBytes: nk.bytes, ivBytes: cfg.iv.bytes,
    mode: cfg.mode, padding: cfg.padding,
  });
  if (r && r.error) throw new Error('crypto-js: ' + r.error);
  const ciphertext = __musicfree_makeWordArray(r.bytes, null);
  return {
    ciphertext: ciphertext,
    toString: function(encoder) {
      if (encoder === __musicfree_CryptoEnc.Hex) return r.hex;
      return r.base64;
    },
  };
};

const __musicfree_runDecipher = function(action, input, key, options) {
  const cfg = __musicfree_readCipherOptions(options);
  const nk = __musicfree_readCryptoInput(key);
  const ct = __musicfree_readCiphertext(input);
  const r = __musicfree_callBridge('MusicFreeCrypto', Object.assign({
    action: action, keyBytes: nk.bytes, ivBytes: cfg.iv.bytes,
    mode: cfg.mode, padding: cfg.padding,
  }, ct));
  if (r && r.error) throw new Error('crypto-js: ' + r.error);
  return __musicfree_makeWordArray(r.bytes, null);
};
''';

const _cryptoJsObjectJs = r'''
const __musicfree_cryptoJs = {
  MD5: function(v) { return __musicfree_makeCryptoHash('md5', v); },
  SHA1: function(v) { return __musicfree_makeCryptoHash('sha1', v); },
  SHA224: function(v) { return __musicfree_makeCryptoHash('sha224', v); },
  SHA256: function(v) { return __musicfree_makeCryptoHash('sha256', v); },
  SHA384: function(v) { return __musicfree_makeCryptoHash('sha384', v); },
  SHA512: function(v) { return __musicfree_makeCryptoHash('sha512', v); },
  SHA3: function(v, options) {
    const size = (options && options.outputLength) || 512;
    return __musicfree_makeCryptoHash(size === 256 ? 'sha3-256' : 'sha3-512', v);
  },
  HmacMD5: function(v, k) { return __musicfree_makeCryptoHmac('md5', v, k); },
  HmacSHA1: function(v, k) { return __musicfree_makeCryptoHmac('sha1', v, k); },
  HmacSHA256: function(v, k) { return __musicfree_makeCryptoHmac('sha256', v, k); },
  HmacSHA384: function(v, k) { return __musicfree_makeCryptoHmac('sha384', v, k); },
  HmacSHA512: function(v, k) { return __musicfree_makeCryptoHmac('sha512', v, k); },
  AES: {
    encrypt: function(v, k, o) { return __musicfree_runCipher('aesEncrypt', v, k, o); },
    decrypt: function(c, k, o) { return __musicfree_runDecipher('aesDecrypt', c, k, o); },
  },
  DES: {
    encrypt: function(v, k, o) { return __musicfree_runCipher('tripleDesEncrypt', v, k, o); },
    decrypt: function(c, k, o) { return __musicfree_runDecipher('tripleDesDecrypt', c, k, o); },
  },
  TripleDES: {
    encrypt: function(v, k, o) { return __musicfree_runCipher('tripleDesEncrypt', v, k, o); },
    decrypt: function(c, k, o) { return __musicfree_runDecipher('tripleDesDecrypt', c, k, o); },
  },
  RC4: {
    encrypt: function(v, k, o) { return __musicfree_runCipher('rc4Encrypt', v, k, o); },
    decrypt: function(c, k, o) {
      const cfg = __musicfree_readCipherOptions(o);
      const nk = __musicfree_readCryptoInput(k);
      const ct = __musicfree_readCiphertext(c);
      const r = __musicfree_callBridge('MusicFreeCrypto', Object.assign({
        action: 'rc4Encrypt', keyBytes: nk.bytes, ivBytes: cfg.iv.bytes,
      }, ct));
      if (r && r.error) throw new Error('crypto-js: ' + r.error);
      return __musicfree_makeWordArray(r.bytes, null);
    },
  },
  RC4Drop: {
    encrypt: function(v, k, o) { return __musicfree_runCipher('rc4DropEncrypt', v, k, o); },
  },
  mode: { CBC: 'CBC', ECB: 'ECB', CFB: 'CFB', OFB: 'OFB', CTR: 'CTR' },
  pad: {
    Pkcs7: 'pkcs7', NoPadding: 'nopadding', ZeroPadding: 'zeropadding',
    Iso10126: 'iso10126', Iso97971: 'iso97971', AnsiX923: 'ansix923',
  },
  enc: __musicfree_CryptoEnc,
  lib: {
    WordArray: {
      create: function(bytes) { return __musicfree_makeWordArray(bytes || [], null); },
      random: function(length) {
        const r = __musicfree_callBridge('MusicFreeCrypto', {
          action: 'randomWords', length: Number(length) || 16,
        });
        if (r && r.error) throw new Error('crypto-js: ' + r.error);
        return __musicfree_makeWordArray(r.bytes, null);
      },
    },
  },
};
''';
