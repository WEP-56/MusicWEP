/// `axios` shim. Supports interceptors, CancelToken / AbortController,
/// transformRequest / transformResponse arrays, paramsSerializer, basic auth,
/// validateStatus, withCredentials, and an axios-shaped error object.
String buildShimAxios() {
  final buffer = StringBuffer()
    ..write(_headerHelpersJs)
    ..write(_interceptorHelpersJs)
    ..write(_axiosFactoryJs);
  return buffer.toString();
}

const _headerHelpersJs = r'''
const __musicfree_applyAxiosDefaultHeaders = function(method, headers, data) {
  const next = Object.assign({}, headers || {});
  if (!__musicfree_findHeaderKey(next, 'accept')) {
    next.Accept = 'application/json, text/plain, */*';
  }
  if (method !== 'GET' && method !== 'HEAD' &&
      data !== undefined && data !== null &&
      !__musicfree_findHeaderKey(next, 'content-type')) {
    if (typeof data === 'string') {
      next['Content-Type'] = 'application/x-www-form-urlencoded';
    } else if (data && typeof data === 'object' &&
        typeof data.append === 'function' && typeof data.get === 'function') {
      next['Content-Type'] = 'application/x-www-form-urlencoded';
    } else if (typeof data === 'object') {
      next['Content-Type'] = 'application/json';
    }
  }
  return next;
};

const __musicfree_normalizeBody = function(data, headers) {
  if (data === undefined || data === null) return undefined;
  if (typeof data === 'string') return data;
  const ctKey = Object.keys(headers || {}).find(function(k) {
    return k.toLowerCase() === 'content-type';
  });
  const ct = ctKey ? headers[ctKey] : '';
  if (typeof ct === 'string' && ct.indexOf('application/x-www-form-urlencoded') !== -1) {
    return __musicfree_toQueryString(data);
  }
  if (typeof ct === 'string' && ct.indexOf('application/json') !== -1) {
    return JSON.stringify(data);
  }
  if (typeof data === 'object') return JSON.stringify(data);
  return String(data);
};

const __musicfree_applyBasicAuth = function(headers, auth) {
  if (!auth || !auth.username) return headers;
  const token = btoa(String(auth.username) + ':' + String(auth.password || ''));
  const next = Object.assign({}, headers);
  if (!__musicfree_findHeaderKey(next, 'authorization')) {
    next.Authorization = 'Basic ' + token;
  }
  return next;
};
''';

const _interceptorHelpersJs = r'''
const __musicfree_makeInterceptorChain = function() {
  const handlers = [];
  return {
    use: function(onFulfilled, onRejected) {
      handlers.push({ onFulfilled: onFulfilled, onRejected: onRejected });
      return handlers.length - 1;
    },
    eject: function(id) {
      if (handlers[id]) handlers[id] = null;
    },
    forEach: function(cb) {
      handlers.forEach(function(h) { if (h) cb(h); });
    },
  };
};

const __musicfree_isCancel = function(error) {
  return !!(error && error.__musicfreeCanceled);
};

const __musicfree_makeCancelToken = function() {
  let cancel;
  const promise = new Promise(function(resolve) {
    cancel = function(message) {
      resolve({ __musicfreeCanceled: true, message: message || 'canceled' });
    };
  });
  return { token: { promise: promise, reason: null }, cancel: cancel };
};
''';

const _axiosFactoryJs = r'''
const __musicfree_makeAxios = function(defaultConfig) {
  const requestInterceptors = __musicfree_makeInterceptorChain();
  const responseInterceptors = __musicfree_makeInterceptorChain();

  const runRequest = function(mergedConfig) {
    if (!__musicfree_allowNetworkAccess) {
      return __musicfree_rejectBlockedSideEffect('axios');
    }
    const method = String(mergedConfig.method || 'GET').toUpperCase();
    let headers = __musicfree_applyAxiosDefaultHeaders(
      method,
      __musicfree_mergeHeaders(defaultConfig && defaultConfig.headers, mergedConfig.headers),
      mergedConfig.data,
    );
    headers = __musicfree_applyBasicAuth(headers, mergedConfig.auth);

    let requestData = mergedConfig.data;
    const transformRequest = [].concat(mergedConfig.transformRequest || []);
    transformRequest.forEach(function(fn) {
      if (typeof fn === 'function') requestData = fn(requestData, headers);
    });

    let requestUrl = String(mergedConfig.url || '');
    const serializer = mergedConfig.paramsSerializer;
    let queryString = '';
    if (mergedConfig.params) {
      if (typeof serializer === 'function') queryString = serializer(mergedConfig.params);
      else if (serializer && typeof serializer.serialize === 'function') {
        queryString = serializer.serialize(mergedConfig.params);
      } else queryString = __musicfree_toQueryString(mergedConfig.params);
    }
    if (queryString) {
      requestUrl += (requestUrl.indexOf('?') === -1 ? '?' : '&') + queryString;
    }

    const cancelSignal = mergedConfig.cancelToken && mergedConfig.cancelToken.promise;
    const abortSignal = mergedConfig.signal;
    const racedCancel = cancelSignal
      ? cancelSignal.then(function(reason) { throw reason; })
      : null;

    const bridgeCall = __musicfree_callBridgeAsync('MusicFreeHttp', {
      action: 'request',
      url: requestUrl,
      method: method,
      headers: headers,
      body: __musicfree_normalizeBody(requestData, headers),
      responseType: mergedConfig.responseType,
      timeout: mergedConfig.timeout,
      withCredentials: !!mergedConfig.withCredentials,
    });

    const raced = racedCancel
      ? Promise.race([bridgeCall, racedCancel])
      : bridgeCall;

    return raced.then(function(response) {
      if (response && response.error) {
        const error = new Error(response.error);
        error.isAxiosError = true;
        error.stack = response.stackTrace || null;
        error.code = response.code;
        error.config = mergedConfig;
        throw error;
      }
      const responseHeaders = (response && response.headers) || {};
      let responseData = response ? response.data : null;
      const transformResponse = [].concat(mergedConfig.transformResponse || []);
      transformResponse.forEach(function(fn) {
        if (typeof fn === 'function') responseData = fn(responseData, responseHeaders);
      });
      const validateStatus = mergedConfig.validateStatus || function(s) {
        return s >= 200 && s < 300;
      };
      const result = {
        data: responseData,
        status: response ? response.status : 0,
        statusText: response ? response.statusText : '',
        headers: responseHeaders,
        config: mergedConfig,
        request: null,
      };
      if (!validateStatus(result.status)) {
        const statusError = new Error('Request failed with status code ' + result.status);
        statusError.isAxiosError = true;
        statusError.response = result;
        statusError.config = mergedConfig;
        statusError.code = 'ERR_BAD_RESPONSE';
        throw statusError;
      }
      return result;
    });
  };

  const runWithInterceptors = function(config) {
    const chain = [];
    requestInterceptors.forEach(function(h) {
      chain.push(h.onFulfilled, h.onRejected);
    });
    chain.push(function(finalConfig) { return runRequest(finalConfig); }, undefined);
    responseInterceptors.forEach(function(h) {
      chain.push(h.onFulfilled, h.onRejected);
    });
    let promise = Promise.resolve(config);
    while (chain.length) {
      const onFulfilled = chain.shift();
      const onRejected = chain.shift();
      promise = promise.then(onFulfilled, onRejected);
    }
    return promise;
  };

  const axios = function(configOrUrl, maybeConfig) {
    const initialConfig = typeof configOrUrl === 'string'
      ? Object.assign({}, maybeConfig || {}, { url: configOrUrl })
      : Object.assign({}, configOrUrl || {});
    const mergedConfig = Object.assign({}, defaultConfig || {}, initialConfig);
    return runWithInterceptors(mergedConfig);
  };

  axios.defaults = Object.assign({}, defaultConfig || {});
  axios.interceptors = {
    request: requestInterceptors,
    response: responseInterceptors,
  };
  axios.get = function(url, config) { return axios(Object.assign({}, config || {}, { url: url, method: 'GET' })); };
  axios.delete = function(url, config) { return axios(Object.assign({}, config || {}, { url: url, method: 'DELETE' })); };
  axios.head = function(url, config) { return axios(Object.assign({}, config || {}, { url: url, method: 'HEAD' })); };
  axios.options = function(url, config) { return axios(Object.assign({}, config || {}, { url: url, method: 'OPTIONS' })); };
  axios.request = function(config) { return axios(Object.assign({}, config || {})); };
  axios.post = function(url, data, config) { return axios(Object.assign({}, config || {}, { url: url, data: data, method: 'POST' })); };
  axios.put = function(url, data, config) { return axios(Object.assign({}, config || {}, { url: url, data: data, method: 'PUT' })); };
  axios.patch = function(url, data, config) { return axios(Object.assign({}, config || {}, { url: url, data: data, method: 'PATCH' })); };
  axios.all = function(promises) { return Promise.all(promises); };
  axios.spread = function(fn) {
    return function(results) { return fn.apply(null, results); };
  };
  axios.isAxiosError = function(error) { return !!(error && error.isAxiosError); };
  axios.isCancel = __musicfree_isCancel;
  axios.CancelToken = function(executor) {
    const { token, cancel } = __musicfree_makeCancelToken();
    executor(cancel);
    return token;
  };
  axios.CancelToken.source = function() {
    const { token, cancel } = __musicfree_makeCancelToken();
    return { token: token, cancel: cancel };
  };
  axios.create = function(config) {
    return __musicfree_makeAxios(Object.assign({}, defaultConfig || {}, config || {}));
  };
  return axios;
};

// btoa fallback for QuickJS (which only exposes it under window / self).
if (typeof btoa === 'undefined') {
  globalThis.btoa = function(str) {
    const r = __musicfree_callBridge('MusicFreeCrypto', {
      action: 'base64Stringify',
      bytes: Array.from(String(str)).map(function(ch) { return ch.charCodeAt(0); }),
    });
    return r.value || '';
  };
}
''';
