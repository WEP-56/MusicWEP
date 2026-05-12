/// Cheerio shim: parses once via the bridge, then runs every selector /
/// traversal in-JS against the resulting node tree.
///
/// The bridge returns the full document tree (see
/// `plugin_runtime_cheerio_bridge.dart`). Each node has `tag`, `attrs`,
/// `children`, `text`, `innerHtml`, `outerHtml`.
///
/// Supported selectors:
/// - Tag: `div`, `*`
/// - Id: `#id`
/// - Class: `.class`
/// - Attribute: `[name]`, `[name="value"]`, `[name^="v"]`, `[name$="v"]`,
///   `[name*="v"]`, `[name~="v"]`
/// - Pseudo: `:first-child`, `:last-child`, `:nth-child(n)`,
///   `:nth-of-type(n)`, `:not(sel)`
/// - Descendant (space), child (`>`), union (`,`)
///
/// Unsupported selectors throw, rather than silently returning empty sets.
String buildShimCheerio() {
  return r'''
const __musicfree_cheerioLoadTree = function(html) {
  const key = { html: String(html || '') };
  const result = __musicfree_callBridge('MusicFreeCheerio', {
    action: 'parse',
    html: key.html,
  });
  if (!result || !result.root) {
    throw new Error('cheerio: bridge returned no root node for the provided html.');
  }
  __musicfree_cheerioLinkParents(result.root, null);
  return result.root;
};

const __musicfree_cheerioLinkParents = function(node, parent) {
  if (!node) return;
  Object.defineProperty(node, '__parent', {
    value: parent,
    writable: true,
    configurable: true,
    enumerable: false,
  });
  if (Array.isArray(node.children)) {
    node.children.forEach(function(child) {
      __musicfree_cheerioLinkParents(child, node);
    });
  }
};

const __musicfree_cheerioMatch = function(node, selector) {
  return __musicfree_cheerioRunSelectorGroup(selector, [node]).indexOf(node) !== -1;
};

// ---- Selector tokenizer -----------------------------------------------------

const __musicfree_cheerioTokenize = function(selector) {
  const groups = [];
  let depth = 0;
  let buffer = '';
  for (let i = 0; i < selector.length; i += 1) {
    const ch = selector[i];
    if (ch === '(' || ch === '[') depth += 1;
    else if (ch === ')' || ch === ']') depth -= 1;
    if (ch === ',' && depth === 0) {
      groups.push(buffer.trim());
      buffer = '';
    } else {
      buffer += ch;
    }
  }
  if (buffer.trim().length) groups.push(buffer.trim());
  return groups.map(__musicfree_cheerioTokenizeGroup);
};

const __musicfree_cheerioTokenizeGroup = function(group) {
  const combinators = [];
  let currentCombinator = ' ';
  let token = '';
  let depth = 0;
  const flush = function() {
    if (token.length) {
      combinators.push({ combinator: currentCombinator, simple: token });
      token = '';
    }
  };
  for (let i = 0; i < group.length; i += 1) {
    const ch = group[i];
    if (ch === '(' || ch === '[') depth += 1;
    else if (ch === ')' || ch === ']') depth -= 1;
    if (depth === 0 && (ch === '>' || ch === '+' || ch === '~')) {
      flush();
      currentCombinator = ch;
    } else if (depth === 0 && /\s/.test(ch)) {
      if (token.length) flush();
      if (currentCombinator !== '>' && currentCombinator !== '+' && currentCombinator !== '~') {
        currentCombinator = ' ';
      }
    } else {
      if (!token.length) {
        // starting a new simple selector, commit the current combinator
      }
      token += ch;
      if (i === group.length - 1) flush();
    }
  }
  flush();
  if (!combinators.length) {
    throw new Error('cheerio: empty selector group "' + group + '".');
  }
  combinators[0].combinator = null;
  return combinators;
};

// ---- Simple selector matcher -----------------------------------------------

const __musicfree_cheerioParseSimple = function(simple) {
  const tokens = [];
  let i = 0;
  while (i < simple.length) {
    const ch = simple[i];
    if (ch === '#') {
      let value = '';
      i += 1;
      while (i < simple.length && !/[#.\[:]/.test(simple[i])) {
        value += simple[i];
        i += 1;
      }
      tokens.push({ kind: 'id', value: value });
    } else if (ch === '.') {
      let value = '';
      i += 1;
      while (i < simple.length && !/[#.\[:]/.test(simple[i])) {
        value += simple[i];
        i += 1;
      }
      tokens.push({ kind: 'class', value: value });
    } else if (ch === '[') {
      const end = simple.indexOf(']', i);
      if (end === -1) {
        throw new Error('cheerio: unterminated attribute selector in "' + simple + '".');
      }
      const body = simple.substring(i + 1, end);
      tokens.push(__musicfree_cheerioParseAttribute(body));
      i = end + 1;
    } else if (ch === ':') {
      let value = '';
      let arg = null;
      i += 1;
      while (i < simple.length && /[a-zA-Z0-9-]/.test(simple[i])) {
        value += simple[i];
        i += 1;
      }
      if (simple[i] === '(') {
        const close = __musicfree_cheerioMatchClosingParen(simple, i);
        if (close === -1) {
          throw new Error('cheerio: unterminated pseudo "' + value + '".');
        }
        arg = simple.substring(i + 1, close);
        i = close + 1;
      }
      tokens.push({ kind: 'pseudo', value: value.toLowerCase(), arg: arg });
    } else {
      let value = '';
      while (i < simple.length && !/[#.\[:]/.test(simple[i])) {
        value += simple[i];
        i += 1;
      }
      tokens.push({ kind: 'tag', value: value.toLowerCase() });
    }
  }
  return tokens;
};

const __musicfree_cheerioMatchClosingParen = function(text, startIndex) {
  let depth = 0;
  for (let i = startIndex; i < text.length; i += 1) {
    if (text[i] === '(') depth += 1;
    else if (text[i] === ')') {
      depth -= 1;
      if (depth === 0) return i;
    }
  }
  return -1;
};

const __musicfree_cheerioParseAttribute = function(body) {
  const match = body.match(/^([^\^\$\*~\|=]+?)(\^=|\$=|\*=|~=|\|=|=)?(.*)$/);
  if (!match) {
    throw new Error('cheerio: invalid attribute selector "[' + body + ']".');
  }
  const name = match[1].trim();
  const op = (match[2] || '').trim();
  let raw = (match[3] || '').trim();
  if ((raw.startsWith('"') && raw.endsWith('"')) ||
      (raw.startsWith("'") && raw.endsWith("'"))) {
    raw = raw.substring(1, raw.length - 1);
  }
  return { kind: 'attr', name: name, op: op, value: raw };
};

const __musicfree_cheerioMatchSimple = function(node, tokens) {
  for (let i = 0; i < tokens.length; i += 1) {
    const token = tokens[i];
    if (token.kind === 'tag') {
      if (token.value === '*' || token.value === '') continue;
      if ((node.tag || '').toLowerCase() !== token.value) return false;
    } else if (token.kind === 'id') {
      if ((node.attrs || {}).id !== token.value) return false;
    } else if (token.kind === 'class') {
      const raw = (node.attrs || {}).class || '';
      const classes = raw.split(/\s+/).filter(Boolean);
      if (classes.indexOf(token.value) === -1) return false;
    } else if (token.kind === 'attr') {
      if (!__musicfree_cheerioMatchAttr(node, token)) return false;
    } else if (token.kind === 'pseudo') {
      if (!__musicfree_cheerioMatchPseudo(node, token)) return false;
    }
  }
  return true;
};

const __musicfree_cheerioMatchAttr = function(node, token) {
  const attrs = node.attrs || {};
  const key = Object.keys(attrs).find(function(k) { return k === token.name; });
  if (!key) return false;
  const value = String(attrs[key] == null ? '' : attrs[key]);
  if (!token.op) return true;
  switch (token.op) {
    case '=': return value === token.value;
    case '^=': return value.indexOf(token.value) === 0;
    case '$=': return value.lastIndexOf(token.value) === value.length - token.value.length;
    case '*=': return value.indexOf(token.value) !== -1;
    case '~=': return value.split(/\s+/).indexOf(token.value) !== -1;
    case '|=': return value === token.value || value.indexOf(token.value + '-') === 0;
  }
  return false;
};

const __musicfree_cheerioMatchPseudo = function(node, token) {
  const parent = node.__parent;
  const siblings = parent && Array.isArray(parent.children)
    ? parent.children.filter(function(n) { return n && n.tag; })
    : [];
  const indexInSiblings = siblings.indexOf(node);
  switch (token.value) {
    case 'first-child': return indexInSiblings === 0;
    case 'last-child': return indexInSiblings === siblings.length - 1 && indexInSiblings !== -1;
    case 'only-child': return siblings.length === 1 && indexInSiblings === 0;
    case 'nth-child':
      return __musicfree_cheerioMatchNth(indexInSiblings + 1, token.arg);
    case 'nth-of-type': {
      const sameTag = siblings.filter(function(n) { return n.tag === node.tag; });
      return __musicfree_cheerioMatchNth(sameTag.indexOf(node) + 1, token.arg);
    }
    case 'not':
      if (!token.arg) return false;
      return !__musicfree_cheerioRunSelectorGroup(token.arg, [node]).length;
    case 'empty':
      return !(node.children || []).some(function(c) { return c && (c.tag || (c.text || '').length); });
  }
  throw new Error('cheerio: unsupported pseudo-class ":' + token.value + '".');
};

const __musicfree_cheerioMatchNth = function(oneBasedIndex, arg) {
  if (!arg) return false;
  const normalized = arg.trim().toLowerCase();
  if (normalized === 'odd') return oneBasedIndex % 2 === 1;
  if (normalized === 'even') return oneBasedIndex % 2 === 0;
  const nth = Number(normalized);
  if (!Number.isNaN(nth)) return oneBasedIndex === nth;
  const match = normalized.match(/^([+-]?\d*)n([+-]\d+)?$/);
  if (!match) {
    throw new Error('cheerio: unsupported :nth-child argument "' + arg + '".');
  }
  const aPart = match[1];
  let a;
  if (aPart === '' || aPart === '+') a = 1;
  else if (aPart === '-') a = -1;
  else a = Number(aPart);
  const b = match[2] ? Number(match[2]) : 0;
  if (a === 0) return oneBasedIndex === b;
  const k = (oneBasedIndex - b) / a;
  return k >= 0 && Math.floor(k) === k;
};

// ---- Walkers ---------------------------------------------------------------

const __musicfree_cheerioDescendants = function(node) {
  const out = [];
  const stack = (node.children || []).slice();
  while (stack.length) {
    const next = stack.shift();
    if (!next) continue;
    if (next.tag) out.push(next);
    if (Array.isArray(next.children)) {
      for (let i = next.children.length - 1; i >= 0; i -= 1) {
        stack.unshift(next.children[i]);
      }
    }
  }
  return out;
};

const __musicfree_cheerioChildren = function(node) {
  return (node.children || []).filter(function(c) { return c && c.tag; });
};

const __musicfree_cheerioRunSelectorGroup = function(selector, scope) {
  const groups = __musicfree_cheerioTokenize(String(selector || ''));
  const out = [];
  const seen = [];
  groups.forEach(function(sequence) {
    __musicfree_cheerioRunSequence(sequence, scope).forEach(function(node) {
      if (seen.indexOf(node) === -1) {
        seen.push(node);
        out.push(node);
      }
    });
  });
  return out;
};

const __musicfree_cheerioRunSequence = function(sequence, scope) {
  let current = scope.slice();
  for (let i = 0; i < sequence.length; i += 1) {
    const step = sequence[i];
    const tokens = __musicfree_cheerioParseSimple(step.simple);
    const candidates = [];
    if (step.combinator === null) {
      // first step — descend from scope into descendants
      scope.forEach(function(root) {
        if (__musicfree_cheerioMatchSimple(root, tokens)) candidates.push(root);
        __musicfree_cheerioDescendants(root).forEach(function(n) {
          if (__musicfree_cheerioMatchSimple(n, tokens)) candidates.push(n);
        });
      });
    } else if (step.combinator === ' ') {
      current.forEach(function(node) {
        __musicfree_cheerioDescendants(node).forEach(function(n) {
          if (__musicfree_cheerioMatchSimple(n, tokens)) candidates.push(n);
        });
      });
    } else if (step.combinator === '>') {
      current.forEach(function(node) {
        __musicfree_cheerioChildren(node).forEach(function(n) {
          if (__musicfree_cheerioMatchSimple(n, tokens)) candidates.push(n);
        });
      });
    } else if (step.combinator === '+') {
      current.forEach(function(node) {
        const siblings = node.__parent ? __musicfree_cheerioChildren(node.__parent) : [];
        const idx = siblings.indexOf(node);
        const next = siblings[idx + 1];
        if (next && __musicfree_cheerioMatchSimple(next, tokens)) candidates.push(next);
      });
    } else if (step.combinator === '~') {
      current.forEach(function(node) {
        const siblings = node.__parent ? __musicfree_cheerioChildren(node.__parent) : [];
        const idx = siblings.indexOf(node);
        siblings.slice(idx + 1).forEach(function(n) {
          if (__musicfree_cheerioMatchSimple(n, tokens)) candidates.push(n);
        });
      });
    }
    const unique = [];
    const seenUniq = [];
    candidates.forEach(function(n) {
      if (seenUniq.indexOf(n) === -1) { seenUniq.push(n); unique.push(n); }
    });
    current = unique;
    if (!current.length) break;
  }
  return current;
};

// ---- Collection ------------------------------------------------------------

const __musicfree_cheerioText = function(node) {
  if (!node) return '';
  if (!node.tag) return node.text || '';
  let result = node.text != null ? node.text : '';
  if (!result.length && Array.isArray(node.children)) {
    result = node.children.map(__musicfree_cheerioText).join('');
  }
  return result;
};

const __musicfree_cheerioMakeCollection = function(nodes) {
  const collection = {
    length: nodes.length,
    _nodes: nodes,
    toArray: function() { return nodes.slice(); },
    get: function(index) {
      if (index === undefined) return nodes.slice();
      return nodes[index];
    },
    eq: function(index) {
      const pick = index >= 0 && index < nodes.length ? [nodes[index]] : [];
      return __musicfree_cheerioMakeCollection(pick);
    },
    first: function() {
      return __musicfree_cheerioMakeCollection(nodes.length ? [nodes[0]] : []);
    },
    last: function() {
      return __musicfree_cheerioMakeCollection(nodes.length ? [nodes[nodes.length - 1]] : []);
    },
    slice: function(start, end) {
      return __musicfree_cheerioMakeCollection(nodes.slice(start, end));
    },
    text: function() {
      return nodes.map(__musicfree_cheerioText).join('');
    },
    html: function() {
      const first = nodes[0];
      return first ? (first.innerHtml != null ? first.innerHtml : first.html || '') : '';
    },
    outerHtml: function() {
      const first = nodes[0];
      return first ? (first.outerHtml || '') : '';
    },
    attr: function(name, value) {
      if (value !== undefined) {
        nodes.forEach(function(node) {
          if (!node.attrs) node.attrs = {};
          node.attrs[name] = String(value);
        });
        return this;
      }
      const first = nodes[0];
      if (!first || !first.attrs) return undefined;
      return first.attrs[name];
    },
    data: function(name) {
      const first = nodes[0];
      if (!first || !first.attrs) return undefined;
      return first.attrs['data-' + name];
    },
    hasClass: function(name) {
      return nodes.some(function(node) {
        const raw = (node.attrs || {}).class || '';
        return raw.split(/\s+/).indexOf(name) !== -1;
      });
    },
    addClass: function(name) {
      nodes.forEach(function(node) {
        if (!node.attrs) node.attrs = {};
        const classes = (node.attrs.class || '').split(/\s+/).filter(Boolean);
        if (classes.indexOf(name) === -1) classes.push(name);
        node.attrs.class = classes.join(' ');
      });
      return this;
    },
    removeClass: function(name) {
      nodes.forEach(function(node) {
        if (!node.attrs) return;
        const classes = (node.attrs.class || '').split(/\s+/).filter(Boolean);
        node.attrs.class = classes.filter(function(c) { return c !== name; }).join(' ');
      });
      return this;
    },
    toggleClass: function(name) {
      nodes.forEach(function(node) {
        if (!node.attrs) node.attrs = {};
        const classes = (node.attrs.class || '').split(/\s+/).filter(Boolean);
        const index = classes.indexOf(name);
        if (index === -1) classes.push(name);
        else classes.splice(index, 1);
        node.attrs.class = classes.join(' ');
      });
      return this;
    },
    find: function(selector) {
      const results = __musicfree_cheerioRunSelectorGroup(selector, nodes);
      return __musicfree_cheerioMakeCollection(results);
    },
    children: function(selector) {
      const kids = [];
      nodes.forEach(function(node) {
        __musicfree_cheerioChildren(node).forEach(function(child) { kids.push(child); });
      });
      const coll = __musicfree_cheerioMakeCollection(kids);
      return selector ? coll.filter(selector) : coll;
    },
    parent: function() {
      const parents = [];
      const seenParents = [];
      nodes.forEach(function(node) {
        if (node.__parent && node.__parent.tag && seenParents.indexOf(node.__parent) === -1) {
          seenParents.push(node.__parent);
          parents.push(node.__parent);
        }
      });
      return __musicfree_cheerioMakeCollection(parents);
    },
    parents: function(selector) {
      const result = [];
      const seenParents = [];
      nodes.forEach(function(node) {
        let cur = node.__parent;
        while (cur && cur.tag) {
          if (seenParents.indexOf(cur) === -1) { seenParents.push(cur); result.push(cur); }
          cur = cur.__parent;
        }
      });
      const coll = __musicfree_cheerioMakeCollection(result);
      return selector ? coll.filter(selector) : coll;
    },
    closest: function(selector) {
      const result = [];
      nodes.forEach(function(node) {
        let cur = node;
        while (cur && cur.tag) {
          if (__musicfree_cheerioMatch(cur, selector)) { result.push(cur); break; }
          cur = cur.__parent;
        }
      });
      return __musicfree_cheerioMakeCollection(result);
    },
    siblings: function(selector) {
      const result = [];
      nodes.forEach(function(node) {
        if (!node.__parent) return;
        __musicfree_cheerioChildren(node.__parent).forEach(function(sib) {
          if (sib !== node) result.push(sib);
        });
      });
      const coll = __musicfree_cheerioMakeCollection(result);
      return selector ? coll.filter(selector) : coll;
    },
    next: function() {
      const result = [];
      nodes.forEach(function(node) {
        if (!node.__parent) return;
        const kids = __musicfree_cheerioChildren(node.__parent);
        const idx = kids.indexOf(node);
        if (idx !== -1 && kids[idx + 1]) result.push(kids[idx + 1]);
      });
      return __musicfree_cheerioMakeCollection(result);
    },
    nextAll: function() {
      const result = [];
      nodes.forEach(function(node) {
        if (!node.__parent) return;
        const kids = __musicfree_cheerioChildren(node.__parent);
        const idx = kids.indexOf(node);
        if (idx !== -1) kids.slice(idx + 1).forEach(function(n) { result.push(n); });
      });
      return __musicfree_cheerioMakeCollection(result);
    },
    prev: function() {
      const result = [];
      nodes.forEach(function(node) {
        if (!node.__parent) return;
        const kids = __musicfree_cheerioChildren(node.__parent);
        const idx = kids.indexOf(node);
        if (idx > 0) result.push(kids[idx - 1]);
      });
      return __musicfree_cheerioMakeCollection(result);
    },
    prevAll: function() {
      const result = [];
      nodes.forEach(function(node) {
        if (!node.__parent) return;
        const kids = __musicfree_cheerioChildren(node.__parent);
        const idx = kids.indexOf(node);
        if (idx > 0) kids.slice(0, idx).forEach(function(n) { result.push(n); });
      });
      return __musicfree_cheerioMakeCollection(result);
    },
    has: function(selector) {
      const filtered = nodes.filter(function(node) {
        return __musicfree_cheerioRunSelectorGroup(selector, [node]).length > 0;
      });
      return __musicfree_cheerioMakeCollection(filtered);
    },
    not: function(selector) {
      const rejected = __musicfree_cheerioRunSelectorGroup(selector, nodes);
      const filtered = nodes.filter(function(node) { return rejected.indexOf(node) === -1; });
      return __musicfree_cheerioMakeCollection(filtered);
    },
    filter: function(selector) {
      if (typeof selector === 'function') {
        const filtered = nodes.filter(function(node, index) {
          return !!selector.call(node, index, node);
        });
        return __musicfree_cheerioMakeCollection(filtered);
      }
      const matched = __musicfree_cheerioRunSelectorGroup(selector, nodes);
      return __musicfree_cheerioMakeCollection(matched);
    },
    each: function(callback) {
      nodes.forEach(function(node, index) { callback.call(node, index, node); });
      return this;
    },
    map: function(callback) {
      const mapped = nodes.map(function(node, index) {
        return callback.call(node, index, node);
      });
      return {
        toArray: function() { return mapped.slice(); },
        get: function() { return mapped.slice(); },
      };
    },
  };
  collection[Symbol.iterator] = function* () {
    for (let i = 0; i < nodes.length; i += 1) yield nodes[i];
  };
  nodes.forEach(function(node, index) { collection[index] = node; });
  return collection;
};

const __musicfree_cheerio = {
  load: function(html) {
    const root = __musicfree_cheerioLoadTree(html);
    const scope = [root];
    const loader = function(selector, context) {
      if (typeof selector !== 'string') {
        if (selector && selector._nodes) {
          return __musicfree_cheerioMakeCollection(selector._nodes.slice());
        }
        if (selector && typeof selector === 'object') {
          return __musicfree_cheerioMakeCollection([selector]);
        }
        return __musicfree_cheerioMakeCollection([]);
      }
      const searchScope = context && context._nodes
        ? context._nodes
        : scope;
      const matches = __musicfree_cheerioRunSelectorGroup(selector, searchScope);
      return __musicfree_cheerioMakeCollection(matches);
    };
    loader.html = function() { return root.outerHtml || ''; };
    loader.text = function() { return __musicfree_cheerioText(root); };
    loader.root = function() {
      return __musicfree_cheerioMakeCollection([root]);
    };
    return loader;
  },
};
''';
}
