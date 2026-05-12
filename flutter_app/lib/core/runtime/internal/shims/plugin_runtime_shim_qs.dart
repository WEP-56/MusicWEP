/// `qs` shim. Supports nested object / array bracket / indices / repeat /
/// comma formats and the three arrayFormat modes the real library exposes.
String buildShimQs() {
  return r'''
const __musicfree_qsEncode = function(value) {
  return encodeURIComponent(value).replace(/%20/g, '+');
};

const __musicfree_qsDecode = function(value) {
  return decodeURIComponent(String(value).replace(/\+/g, '%20'));
};

const __musicfree_qsStringifyPart = function(prefix, obj, options) {
  if (obj === null || obj === undefined) {
    return [];
  }
  const parts = [];
  if (Array.isArray(obj)) {
    if (options.arrayFormat === 'indices') {
      obj.forEach(function(item, index) {
        parts.push.apply(
          parts,
          __musicfree_qsStringifyPart(prefix + '[' + index + ']', item, options),
        );
      });
    } else if (options.arrayFormat === 'brackets') {
      obj.forEach(function(item) {
        parts.push.apply(parts, __musicfree_qsStringifyPart(prefix + '[]', item, options));
      });
    } else if (options.arrayFormat === 'repeat') {
      obj.forEach(function(item) {
        parts.push.apply(parts, __musicfree_qsStringifyPart(prefix, item, options));
      });
    } else if (options.arrayFormat === 'comma') {
      const values = obj
        .map(function(item) { return options.encode ? __musicfree_qsEncode(String(item)) : String(item); })
        .join(',');
      parts.push(prefix + '=' + values);
    }
    return parts;
  }
  if (typeof obj === 'object') {
    Object.keys(obj).forEach(function(key) {
      const nextPrefix = prefix
        ? prefix + '[' + key + ']'
        : key;
      parts.push.apply(parts, __musicfree_qsStringifyPart(nextPrefix, obj[key], options));
    });
    return parts;
  }
  const rawValue = options.encode ? __musicfree_qsEncode(String(obj)) : String(obj);
  const rawKey = options.encode ? __musicfree_qsEncode(prefix) : prefix;
  parts.push(rawKey + '=' + rawValue);
  return parts;
};

const __musicfree_qsAssignNested = function(root, segments, value) {
  let current = root;
  for (let i = 0; i < segments.length; i += 1) {
    const segment = segments[i];
    const isLast = i === segments.length - 1;
    const nextSegment = segments[i + 1];
    if (isLast) {
      if (Array.isArray(current[segment])) {
        current[segment].push(value);
      } else if (current[segment] !== undefined) {
        current[segment] = [current[segment], value];
      } else {
        current[segment] = value;
      }
    } else {
      if (current[segment] === undefined) {
        current[segment] = nextSegment === '' || /^\d+$/.test(nextSegment) ? [] : {};
      }
      current = current[segment];
    }
  }
};

const __musicfree_qsParseKeySegments = function(key) {
  const segments = [];
  const match = key.match(/^[^\[]*/);
  if (!match) return segments;
  segments.push(match[0]);
  const rest = key.substring(match[0].length);
  const bracketRegex = /\[([^\]]*)\]/g;
  let bm;
  while ((bm = bracketRegex.exec(rest)) !== null) {
    segments.push(bm[1]);
  }
  return segments;
};

const __musicfree_qs = {
  stringify: function(obj, options) {
    const o = Object.assign({
      encode: true,
      arrayFormat: 'indices',
      delimiter: '&',
    }, options || {});
    if (obj === null || obj === undefined) return '';
    const parts = [];
    Object.keys(obj).forEach(function(key) {
      parts.push.apply(parts, __musicfree_qsStringifyPart(key, obj[key], o));
    });
    return parts.join(o.delimiter);
  },
  parse: function(value, options) {
    const o = Object.assign({ delimiter: '&', depth: 5 }, options || {});
    const source = String(value == null ? '' : value).replace(/^\?/, '');
    if (!source.length) return {};
    const result = {};
    source.split(o.delimiter).forEach(function(pair) {
      if (!pair.length) return;
      const eq = pair.indexOf('=');
      const rawKey = eq === -1 ? pair : pair.substring(0, eq);
      const rawValue = eq === -1 ? '' : pair.substring(eq + 1);
      const key = __musicfree_qsDecode(rawKey);
      const val = __musicfree_qsDecode(rawValue);
      __musicfree_qsAssignNested(result, __musicfree_qsParseKeySegments(key), val);
    });
    return result;
  },
};
''';
}
