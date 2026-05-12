/// Common helpers shared by every package shim: URL / URLSearchParams
/// polyfill, synchronous / asynchronous bridge call helpers, the default
/// unsupported-package proxy factory.
///
/// The snippets here run at the top of the shim block so other files can
/// rely on `__musicfree_URL`, `__musicfree_callBridge`, etc.
String buildShimUrlPolyfill() {
  return r'''
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
  const isAbsolute = /^[a-zA-Z][a-zA-Z\d+.-]*:/.test(input);
  let value = String(input || '');
  if (!isAbsolute && base) {
    const baseHref = typeof base === 'string' ? base : (base.href || '');
    if (/^[a-zA-Z][a-zA-Z\d+.-]*:\/\//.test(baseHref)) {
      if (value.startsWith('/')) {
        const baseMatch = baseHref.match(/^([a-zA-Z][a-zA-Z\d+.-]*:\/\/[^/]+)/);
        value = (baseMatch ? baseMatch[1] : baseHref) + value;
      } else {
        const idx = baseHref.lastIndexOf('/');
        value = (idx >= 0 ? baseHref.substring(0, idx + 1) : baseHref + '/') + value;
      }
    } else {
      value = baseHref + value;
    }
  }
  const match = value.match(/^([a-zA-Z][a-zA-Z\d+.-]*:)?(?:\/\/([^/?#]*))?([^?#]*)(\?[^#]*)?(#.*)?$/);
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
''';
}

String buildShimBridgeHelpers() {
  return r'''
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
''';
}

String buildShimUnsupported() {
  return r'''
const __musicfree_makeUnsupportedPackage = function(label) {
  let proxy;
  const target = function() {
    throw new Error('Unsupported package shim invoked: ' + label);
  };
  proxy = new Proxy(target, {
    get: function(_, prop) {
      if (prop === 'default') return proxy;
      if (prop === 'then') return undefined;
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

const __musicfree_toQueryString = function(params) {
  if (!params || typeof params !== 'object') return '';
  const searchParams = new __musicfree_URLSearchParams();
  const appendEntry = function(key, value) {
    if (value === undefined || value === null) return;
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
''';
}
