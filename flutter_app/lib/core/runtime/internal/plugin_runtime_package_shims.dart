String buildPluginRuntimePackageShimScript() {
  return '''
const __musicfree_URLSearchParamsPolyfill = function(init) {
  this._pairs = [];
  const appendPair = (key, value) => {
    this._pairs.push([String(key), String(value)]);
  };
  if (typeof init === 'string') {
    const source = init.startsWith('?') ? init.substring(1) : init;
    if (source) {
      source.split('&').forEach((part) => {
        if (!part) {
          return;
        }
        const pair = part.split('=');
        const key = decodeURIComponent(pair[0] || '');
        const value = decodeURIComponent(pair.slice(1).join('=') || '');
        appendPair(key, value);
      });
    }
  } else if (Array.isArray(init)) {
    init.forEach((entry) => {
      if (Array.isArray(entry) && entry.length >= 2) {
        appendPair(entry[0], entry[1]);
      }
    });
  } else if (init && typeof init === 'object') {
    Object.keys(init).forEach((key) => {
      const value = init[key];
      if (Array.isArray(value)) {
        value.forEach((item) => appendPair(key, item));
      } else if (value !== undefined && value !== null) {
        appendPair(key, value);
      }
    });
  }
};
__musicfree_URLSearchParamsPolyfill.prototype.append = function(key, value) {
  this._pairs.push([String(key), String(value)]);
};
__musicfree_URLSearchParamsPolyfill.prototype.get = function(key) {
  const found = this._pairs.find((entry) => entry[0] === String(key));
  return found ? found[1] : null;
};
__musicfree_URLSearchParamsPolyfill.prototype.forEach = function(callback) {
  this._pairs.forEach((entry) => callback(entry[1], entry[0]));
};
__musicfree_URLSearchParamsPolyfill.prototype.toString = function() {
  return this._pairs
    .map((entry) => encodeURIComponent(entry[0]) + '=' + encodeURIComponent(entry[1]))
    .join('&');
};

const __musicfree_parseUrl = function(input, base) {
  const isAbsolute = /^[a-zA-Z][a-zA-Z\\d+.-]*:/.test(input);
  let value = String(input || '');
  if (!isAbsolute && base) {
    const baseHref = typeof base === 'string' ? base : (base.href || '');
    if (/^[a-zA-Z][a-zA-Z\\d+.-]*:\\/\\//.test(baseHref)) {
      if (value.startsWith('/')) {
        const baseMatch = baseHref.match(/^([a-zA-Z][a-zA-Z\\d+.-]*:\\/\\/[^/]+)/);
        value = (baseMatch ? baseMatch[1] : baseHref) + value;
      } else {
        const idx = baseHref.lastIndexOf('/');
        value = (idx >= 0 ? baseHref.substring(0, idx + 1) : baseHref + '/') + value;
      }
    } else {
      value = baseHref + value;
    }
  }
  const match = value.match(/^([a-zA-Z][a-zA-Z\\d+.-]*:)?(?:\\/\\/([^/?#]*))?([^?#]*)(\\?[^#]*)?(#.*)?\$/);
  const protocol = match && match[1] ? match[1] : '';
  const host = match && match[2] ? match[2] : '';
  const pathname = match && match[3] ? match[3] : '';
  const search = match && match[4] ? match[4] : '';
  const hash = match && match[5] ? match[5] : '';
  const hostname = host.includes(':') ? host.split(':')[0] : host;
  const port = host.includes(':') ? host.split(':').slice(1).join(':') : '';
  const origin = protocol && host ? protocol + '//' + host : '';
  return {
    href: value,
    protocol: protocol,
    host: host,
    hostname: hostname,
    port: port,
    origin: origin,
    pathname: pathname || '/',
    search: search,
    hash: hash,
  };
};

const __musicfree_URLPolyfill = function(input, base) {
  const parsed = __musicfree_parseUrl(String(input || ''), base);
  this.href = parsed.href;
  this.protocol = parsed.protocol;
  this.host = parsed.host;
  this.hostname = parsed.hostname;
  this.port = parsed.port;
  this.origin = parsed.origin;
  this.pathname = parsed.pathname;
  this.search = parsed.search;
  this.hash = parsed.hash;
  this.searchParams = new __musicfree_URLSearchParams(parsed.search);
};
__musicfree_URLPolyfill.prototype.toString = function() {
  return this.href;
};

const __musicfree_URLSearchParams =
  typeof URLSearchParams !== 'undefined'
    ? URLSearchParams
    : __musicfree_URLSearchParamsPolyfill;
const __musicfree_URL =
  typeof URL !== 'undefined'
    ? URL
    : __musicfree_URLPolyfill;

const __musicfree_callBridge = function(channel, payload) {
  const raw = sendMessage(channel, JSON.stringify(payload || {}));
  if (typeof raw === 'string') {
    try {
      return JSON.parse(raw);
    } catch (_) {
      return raw;
    }
  }
  return raw;
};

const __musicfree_callBridgeAsync = function(channel, payload) {
  return Promise.resolve(
    sendMessage(channel, JSON.stringify(payload || {}))
  ).then(function(raw) {
    if (typeof raw === 'string') {
      try {
        return JSON.parse(raw);
      } catch (_) {
        return raw;
      }
    }
    return raw;
  });
};

const __musicfree_readCryptoInput = function(value) {
  if (value && Array.isArray(value.__musicfreeBytes)) {
    return {
      bytes: value.__musicfreeBytes,
      text: value.__musicfreeText == null ? null : String(value.__musicfreeText),
    };
  }
  if (typeof value === 'string') {
    return {
      bytes: Array.from(unescape(encodeURIComponent(value))).map(function(char) {
        return char.charCodeAt(0);
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
      const result = __musicfree_callBridge('MusicFreeCrypto', {
        action: 'base64Parse',
        value: String(value || ''),
      });
      return __musicfree_makeWordArray(result.bytes, result.text);
    },
  },
  Utf8: {
    parse: function(value) {
      const result = __musicfree_callBridge('MusicFreeCrypto', {
        action: 'utf8Parse',
        value: String(value || ''),
      });
      return __musicfree_makeWordArray(result.bytes, result.text);
    },
  },
  Hex: {},
};

const __musicfree_makeCryptoHash = function(algorithm, value, key) {
  const result = __musicfree_callBridge('MusicFreeCrypto', {
    action: 'hash',
    algorithm: algorithm,
    value: String(value || ''),
    key: key == null ? '' : String(key),
  });
  return __musicfree_makeWordArray(result.bytes, null);
};

const __musicfree_makeCheerioCollection = function(nodes) {
  const normalizeNodes = function(value) {
    if (!value) {
      return [];
    }
    if (Array.isArray(value)) {
      return value.filter(function(entry) {
        return entry && typeof entry === 'object';
      });
    }
    if (Array.isArray(value._nodes)) {
      return value._nodes.slice();
    }
    if (typeof value === 'object') {
      return [value];
    }
    return [];
  };
  const collection = {
    length: nodes.length,
    _nodes: nodes,
    text: function() {
      return nodes.map((node) => node.text || '').join('');
    },
    html: function() {
      const first = nodes[0];
      return first ? first.html || '' : '';
    },
    attr: function(name) {
      const first = nodes[0];
      if (!first || !first.attributes) {
        return undefined;
      }
      return first.attributes[name];
    },
    eq: function(index) {
      const next = index >= 0 && index < nodes.length ? [nodes[index]] : [];
      return __musicfree_makeCheerioCollection(next);
    },
    get: function(index) {
      if (index === undefined) {
        return nodes.slice();
      }
      return nodes[index];
    },
    slice: function(start, end) {
      return __musicfree_makeCheerioCollection(nodes.slice(start, end));
    },
    children: function(selector) {
      const next = [];
      nodes.forEach(function(node) {
        if (Array.isArray(node.children)) {
          next.push.apply(next, node.children);
        }
      });
      const wrapped = __musicfree_makeCheerioCollection(next);
      return selector ? wrapped.find(selector) : wrapped;
    },
    find: function(selector) {
      if (typeof selector !== 'string') {
        return __musicfree_makeCheerioCollection(normalizeNodes(selector));
      }
      const result = __musicfree_callBridge('MusicFreeCheerio', {
        selector: String(selector || ''),
        fragments: nodes.map((node) => node.outerHtml || node.html || ''),
      });
      return __musicfree_makeCheerioCollection(result.nodes || []);
    },
    map: function(callback) {
      const mapped = [];
      nodes.forEach(function(node, index) {
        const value = callback(index, node);
        if (value !== undefined && value !== null) {
          mapped.push(value);
        }
      });
      return {
        toArray: function() {
          return mapped.slice();
        },
        get: function() {
          return mapped.slice();
        },
      };
    },
    each: function(callback) {
      nodes.forEach(function(node, index) {
        callback(index, node);
      });
      return collection;
    },
    first: function() {
      return __musicfree_makeCheerioCollection(nodes.length ? [nodes[0]] : []);
    },
    last: function() {
      return __musicfree_makeCheerioCollection(nodes.length ? [nodes[nodes.length - 1]] : []);
    },
    toArray: function() {
      return nodes.slice();
    },
  };
  collection[Symbol.iterator] = function* () {
    for (let index = 0; index < nodes.length; index += 1) {
      yield nodes[index];
    }
  };
  nodes.forEach(function(node, index) {
    collection[index] = node;
  });
  return collection;
};

const __musicfree_cheerio = {
  load: function(html) {
    const rootResult = __musicfree_callBridge('MusicFreeCheerio', {
      html: String(html || ''),
      selector: '',
    });
    const rootCollection = __musicfree_makeCheerioCollection(rootResult.nodes || []);
    const loader = function(selector) {
      if (typeof selector !== 'string') {
        return __musicfree_makeCheerioCollection(
          Array.isArray(selector && selector._nodes)
            ? selector._nodes
            : (selector && typeof selector === 'object' ? [selector] : [])
        );
      }
      const result = __musicfree_callBridge('MusicFreeCheerio', {
        html: String(html || ''),
        selector: String(selector || ''),
      });
      return __musicfree_makeCheerioCollection(result.nodes || []);
    };
    Object.keys(rootCollection).forEach(function(key) {
      loader[key] = rootCollection[key];
    });
    loader._nodes = rootCollection._nodes;
    loader.text = rootCollection.text;
    loader.html = rootCollection.html;
    loader.find = rootCollection.find;
    loader.eq = rootCollection.eq;
    loader.get = rootCollection.get;
    loader.slice = rootCollection.slice;
    loader.children = rootCollection.children;
    loader.map = rootCollection.map;
    loader.each = rootCollection.each;
    loader.first = rootCollection.first;
    loader.last = rootCollection.last;
    loader.toArray = rootCollection.toArray;
    return loader;
  },
};

const __musicfree_toQueryString = function(params) {
  if (!params || typeof params !== 'object') {
    return '';
  }
  const searchParams = new __musicfree_URLSearchParams();
  const appendEntry = function(key, value) {
    if (value === undefined || value === null) {
      return;
    }
    if (Array.isArray(value)) {
      value.forEach(function(item) { appendEntry(key, item); });
      return;
    }
    if (typeof value === 'object') {
      searchParams.append(key, JSON.stringify(value));
      return;
    }
    searchParams.append(key, String(value));
  };
  Object.keys(params).forEach(function(key) {
    appendEntry(key, params[key]);
  });
  return searchParams.toString();
};

const __musicfree_mergeHeaders = function(baseHeaders, nextHeaders) {
  return Object.assign({}, baseHeaders || {}, nextHeaders || {});
};

const __musicfree_rejectBlockedSideEffect = function(label) {
  return Promise.reject(
    new Error(
      'Blocked plugin side effect during initialization: ' + String(label || 'request')
    )
  );
};

const __musicfree_findHeaderKey = function(headers, name) {
  const normalized = String(name || '').toLowerCase();
  return Object.keys(headers || {}).find(function(key) {
    return String(key || '').toLowerCase() === normalized;
  });
};

const __musicfree_applyAxiosDefaultHeaders = function(method, headers, data) {
  const nextHeaders = Object.assign({}, headers || {});
  if (!__musicfree_findHeaderKey(nextHeaders, 'accept')) {
    nextHeaders.Accept = 'application/json, text/plain, */*';
  }
  if (
    method !== 'GET' &&
    method !== 'HEAD' &&
    data !== undefined &&
    data !== null &&
    !__musicfree_findHeaderKey(nextHeaders, 'content-type')
  ) {
    if (typeof data === 'string') {
      nextHeaders['Content-Type'] = 'application/x-www-form-urlencoded';
    } else if (
      data &&
      typeof data === 'object' &&
      typeof data.append === 'function' &&
      typeof data.get === 'function'
    ) {
      nextHeaders['Content-Type'] = 'application/x-www-form-urlencoded';
    } else if (typeof data === 'object') {
      nextHeaders['Content-Type'] = 'application/json';
    }
  }
  return nextHeaders;
};

const __musicfree_normalizeBody = function(data, headers) {
  if (data === undefined || data === null) {
    return undefined;
  }
  if (typeof data === 'string') {
    return data;
  }
  const contentTypeKey = Object.keys(headers || {}).find(function(key) {
    return key.toLowerCase() === 'content-type';
  });
  const headerValue = contentTypeKey ? headers[contentTypeKey] : '';
  if (
    typeof headerValue === 'string' &&
    headerValue.indexOf('application/x-www-form-urlencoded') !== -1
  ) {
    return __musicfree_toQueryString(data);
  }
  if (
    typeof headerValue === 'string' &&
    headerValue.indexOf('application/json') !== -1
  ) {
    return JSON.stringify(data);
  }
  if (typeof data === 'object') {
    return JSON.stringify(data);
  }
  return String(data);
};

const __musicfree_makeAxios = function(defaultConfig) {
  const axios = function(configOrUrl, maybeConfig) {
    if (!__musicfree_allowNetworkAccess) {
      return __musicfree_rejectBlockedSideEffect('axios');
    }
    const initialConfig = typeof configOrUrl === 'string'
      ? Object.assign({}, maybeConfig || {}, { url: configOrUrl })
      : Object.assign({}, configOrUrl || {});
    const mergedConfig = Object.assign({}, defaultConfig || {}, initialConfig);
    const method = String(mergedConfig.method || 'GET').toUpperCase();
    const headers = __musicfree_applyAxiosDefaultHeaders(
      method,
      __musicfree_mergeHeaders(
      defaultConfig && defaultConfig.headers,
      mergedConfig.headers,
      ),
      mergedConfig.data,
    );
    let requestUrl = String(mergedConfig.url || '');
    const queryString = __musicfree_toQueryString(mergedConfig.params);
    if (queryString) {
      requestUrl += (requestUrl.indexOf('?') === -1 ? '?' : '&') + queryString;
    }
    const requestConfig = {
      method: method,
      headers: headers,
      body: __musicfree_normalizeBody(mergedConfig.data, headers),
    };
    return Promise.resolve(
      __musicfree_callBridgeAsync('MusicFreeHttp', {
        action: 'request',
        url: requestUrl,
        method: requestConfig.method,
        headers: requestConfig.headers,
        body: requestConfig.body,
        responseType: mergedConfig.responseType,
        timeout: mergedConfig.timeout,
      })
    ).then(function(response) {
      if (response && response.error) {
        const bridgeError = new Error(response.error);
        bridgeError.stack = response.stackTrace || null;
        throw bridgeError;
      }
      const responseHeaders = response && response.headers
        ? response.headers
        : {};
      const result = {
        data: response ? response.data : null,
        status: response ? response.status : 0,
        statusText: response ? response.statusText : '',
        headers: responseHeaders,
        config: mergedConfig,
        request: null,
      };
      const validateStatus = mergedConfig.validateStatus ||
        function(status) { return status >= 200 && status < 300; };
      if (!validateStatus(response.status)) {
        const error = new Error('Request failed with status code ' + response.status);
        error.response = result;
        error.config = mergedConfig;
        throw error;
      }
      return result;
    });
  };
  axios.get = function(url, config) {
    return axios(Object.assign({}, config || {}, { url: url, method: 'GET' }));
  };
  axios.delete = function(url, config) {
    return axios(Object.assign({}, config || {}, { url: url, method: 'DELETE' }));
  };
  axios.head = function(url, config) {
    return axios(Object.assign({}, config || {}, { url: url, method: 'HEAD' }));
  };
  axios.request = function(config) {
    return axios(Object.assign({}, config || {}));
  };
  axios.post = function(url, data, config) {
    return axios(Object.assign({}, config || {}, { url: url, data: data, method: 'POST' }));
  };
  axios.put = function(url, data, config) {
    return axios(Object.assign({}, config || {}, { url: url, data: data, method: 'PUT' }));
  };
  axios.patch = function(url, data, config) {
    return axios(Object.assign({}, config || {}, { url: url, data: data, method: 'PATCH' }));
  };
  axios.create = function(config) {
    return __musicfree_makeAxios(Object.assign({}, defaultConfig || {}, config || {}));
  };
  axios.defaults = Object.assign({}, defaultConfig || {});
  axios.isAxiosError = function(error) {
    return !!(error && error.response);
  };
  return axios;
};

const __musicfree_makeUnsupportedPackage = function(label) {
  let proxy;
  const target = function() {
    throw new Error('Unsupported package shim invoked: ' + label);
  };
  proxy = new Proxy(target, {
    get: function(_, prop) {
      if (prop === 'default') {
        return proxy;
      }
      if (prop === 'then') {
        return undefined;
      }
      if (prop === 'toString') {
        return function() { return '[UnsupportedPackage ' + label + ']'; };
      }
      return proxy;
    },
    apply: function() {
      throw new Error('Unsupported package shim invoked: ' + label);
    },
    construct: function() {
      throw new Error('Unsupported package shim invoked: ' + label);
    },
  });
  return proxy;
};

const __musicfree_makeDayjs = function(input) {
  const value = input === undefined || input === null ? new Date() : new Date(input);
  const wrap = function(date) {
    const api = {
      toDate: function() { return new Date(date.getTime()); },
      valueOf: function() { return date.getTime(); },
      unix: function() { return Math.floor(date.getTime() / 1000); },
      add: function(amount, unit) {
        const next = new Date(date.getTime());
        if (unit === 'day' || unit === 'days') {
          next.setDate(next.getDate() + amount);
        } else if (unit === 'hour' || unit === 'hours') {
          next.setHours(next.getHours() + amount);
        } else if (unit === 'minute' || unit === 'minutes') {
          next.setMinutes(next.getMinutes() + amount);
        } else {
          next.setMilliseconds(next.getMilliseconds() + amount);
        }
        return wrap(next);
      },
      subtract: function(amount, unit) { return api.add(-amount, unit); },
      format: function(pattern) {
        const pad = function(number) {
          return String(number).padStart(2, '0');
        };
        const replacements = {
          YYYY: String(date.getFullYear()),
          MM: pad(date.getMonth() + 1),
          DD: pad(date.getDate()),
          HH: pad(date.getHours()),
          mm: pad(date.getMinutes()),
          ss: pad(date.getSeconds()),
        };
        let output = pattern || 'YYYY-MM-DDTHH:mm:ss';
        Object.keys(replacements).forEach(function(token) {
          output = output.replaceAll(token, replacements[token]);
        });
        return output;
      },
      locale: function() { return api; },
    };
    return api;
  };
  return wrap(value);
};
__musicfree_makeDayjs.extend = function() {};
__musicfree_makeDayjs.locale = function() {};
__musicfree_makeDayjs.unix = function(value) {
  return __musicfree_makeDayjs(Number(value) * 1000);
};

const __musicfree_makeBigInteger = function(value) {
  const parseValue = function(input, radix) {
    const raw = input && input.__musicfreeBigIntValue
      ? input.__musicfreeBigIntValue
      : String(input || '0').trim();
    const result = __musicfree_callBridge('MusicFreeBigInt', {
      action: 'create',
      value: raw || '0',
      radix: radix || 10,
    });
    return result && result.value ? String(result.value) : '0';
  };
  const wrap = function(current) {
    const readNext = function(next) {
      return parseValue(next && next.valueOf ? next.valueOf() : next, 10);
    };
    return {
      __musicfreeBigIntValue: current,
      add: function(next) {
        const result = __musicfree_callBridge('MusicFreeBigInt', {
          action: 'binary',
          operator: 'add',
          left: current,
          right: readNext(next),
        });
        return wrap(result.value);
      },
      minus: function(next) {
        const result = __musicfree_callBridge('MusicFreeBigInt', {
          action: 'binary',
          operator: 'minus',
          left: current,
          right: readNext(next),
        });
        return wrap(result.value);
      },
      subtract: function(next) {
        const result = __musicfree_callBridge('MusicFreeBigInt', {
          action: 'binary',
          operator: 'subtract',
          left: current,
          right: readNext(next),
        });
        return wrap(result.value);
      },
      multiply: function(next) {
        const result = __musicfree_callBridge('MusicFreeBigInt', {
          action: 'binary',
          operator: 'multiply',
          left: current,
          right: readNext(next),
        });
        return wrap(result.value);
      },
      divide: function(next) {
        const result = __musicfree_callBridge('MusicFreeBigInt', {
          action: 'binary',
          operator: 'divide',
          left: current,
          right: readNext(next),
        });
        return wrap(result.value);
      },
      mod: function(next) {
        const result = __musicfree_callBridge('MusicFreeBigInt', {
          action: 'binary',
          operator: 'mod',
          left: current,
          right: readNext(next),
        });
        return wrap(result.value);
      },
      modPow: function(exponent, modulus) {
        const result = __musicfree_callBridge('MusicFreeBigInt', {
          action: 'modPow',
          base: current,
          exponent: readNext(exponent),
          modulus: readNext(modulus),
        });
        return wrap(result.value);
      },
      compare: function(next) {
        const result = __musicfree_callBridge('MusicFreeBigInt', {
          action: 'compare',
          left: current,
          right: readNext(next),
        });
        return result.value;
      },
      toString: function(radix) {
        const result = __musicfree_callBridge('MusicFreeBigInt', {
          action: 'toString',
          value: current,
          radix: radix || 10,
        });
        return result.value;
      },
      valueOf: function() { return current; },
    };
  };
  return wrap(parseValue(value, arguments[1]));
};

const __musicfree_packages = {
  axios: __musicfree_makeAxios({}),
  cheerio: __musicfree_cheerio,
  'crypto-js': {
    MD5: function(value) {
      return __musicfree_makeCryptoHash('md5', value);
    },
    SHA1: function(value) {
      return __musicfree_makeCryptoHash('sha1', value);
    },
    SHA256: function(value) {
      return __musicfree_makeCryptoHash('sha256', value);
    },
    HmacSHA1: function(value, key) {
      return __musicfree_makeCryptoHash('hmacsha1', value, key);
    },
    HmacSHA256: function(value, key) {
      return __musicfree_makeCryptoHash('hmacsha256', value, key);
    },
    AES: {
      encrypt: function(value, key, options) {
        const normalizedValue = __musicfree_readCryptoInput(value);
        const normalizedKey = __musicfree_readCryptoInput(key);
        const normalizedIv = __musicfree_readCryptoInput(
          options && options.iv ? options.iv : ''
        );
        const result = __musicfree_callBridge('MusicFreeCrypto', {
          action: 'aesEncrypt',
          valueText: normalizedValue.text,
          valueBytes: normalizedValue.bytes,
          keyBytes: normalizedKey.bytes,
          ivBytes: normalizedIv.bytes,
          mode: options && options.mode ? String(options.mode) : 'CBC',
        });
        const ciphertext = __musicfree_makeWordArray(result.bytes, null);
        return {
          ciphertext: ciphertext,
          toString: function(encoder) {
            if (encoder === __musicfree_CryptoEnc.Hex) {
              return result.hex;
            }
            return result.base64;
          },
        };
      },
    },
    mode: {
      CBC: 'CBC',
      ECB: 'ECB',
    },
    pad: {
      Pkcs7: 'Pkcs7',
    },
    enc: __musicfree_CryptoEnc,
  },
  qs: {
    stringify: function(value) { return __musicfree_toQueryString(value); },
    parse: function(value) {
      const result = {};
      const searchParams = new __musicfree_URLSearchParams(String(value || ''));
      searchParams.forEach(function(entryValue, key) {
        result[key] = entryValue;
      });
      return result;
    },
  },
  he: {
    decode: function(value) { return String(value || ''); },
    encode: function(value) { return String(value || ''); },
  },
  dayjs: __musicfree_makeDayjs,
  'big-integer': __musicfree_makeBigInteger,
  '@react-native-cookies/cookies': {
    get: async function(url) {
      const result = await __musicfree_callBridgeAsync('MusicFreeCookies', {
        action: 'get',
        url: String(url || ''),
      });
      return result.value || {};
    },
    set: async function(url, cookie) {
      const result = await __musicfree_callBridgeAsync('MusicFreeCookies', {
        action: 'set',
        url: String(url || ''),
        cookie: cookie || {},
      });
      return !!result.value;
    },
    flush: async function() {
      await __musicfree_callBridgeAsync('MusicFreeCookies', {
        action: 'flush',
      });
    },
  },
  webdav: {
    AuthType: {
      Password: 'password',
    },
    createClient: function(baseUrl, options) {
      const settings = options || {};
      return {
        getDirectoryContents: async function(remotePath) {
          if (!__musicfree_allowNetworkAccess) {
            return __musicfree_rejectBlockedSideEffect('webdav.getDirectoryContents');
          }
          const result = await __musicfree_callBridgeAsync('MusicFreeWebDav', {
            action: 'getDirectoryContents',
            baseUrl: String(baseUrl || ''),
            path: String(remotePath || '/'),
            username: settings.username || '',
            password: settings.password || '',
          });
          return result.value || [];
        },
        getFileDownloadLink: async function(remotePath) {
          if (!__musicfree_allowNetworkAccess) {
            return __musicfree_rejectBlockedSideEffect('webdav.getFileDownloadLink');
          }
          const result = await __musicfree_callBridgeAsync('MusicFreeWebDav', {
            action: 'getFileDownloadLink',
            baseUrl: String(baseUrl || ''),
            path: String(remotePath || ''),
            username: settings.username || '',
            password: settings.password || '',
          });
          return result.value || '';
        },
      };
    },
  },
  'musicfree/storage': {
    getItem: async function(key) {
      const result = await __musicfree_callBridgeAsync('MusicFreeStorage', {
        action: 'getItem',
        key: String(key || ''),
      });
      return result.value == null ? null : String(result.value);
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
        action: 'removeItem',
        key: String(key || ''),
      });
    },
  },
};
''';
}
