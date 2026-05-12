/// `big-integer` shim. Delegates all arithmetic to the Dart-side
/// `MusicFreeBigInt` bridge (same as the original P0 implementation).
/// We do NOT use native JS BigInt because the embedded QuickJS build does
/// not expose it.
String buildShimBigInt() {
  return r'''
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
        const r = __musicfree_callBridge('MusicFreeBigInt', {
          action: 'binary', operator: 'add',
          left: current, right: readNext(next),
        });
        return wrap(r.value);
      },
      minus: function(next) {
        const r = __musicfree_callBridge('MusicFreeBigInt', {
          action: 'binary', operator: 'minus',
          left: current, right: readNext(next),
        });
        return wrap(r.value);
      },
      subtract: function(next) {
        const r = __musicfree_callBridge('MusicFreeBigInt', {
          action: 'binary', operator: 'subtract',
          left: current, right: readNext(next),
        });
        return wrap(r.value);
      },
      multiply: function(next) {
        const r = __musicfree_callBridge('MusicFreeBigInt', {
          action: 'binary', operator: 'multiply',
          left: current, right: readNext(next),
        });
        return wrap(r.value);
      },
      divide: function(next) {
        const r = __musicfree_callBridge('MusicFreeBigInt', {
          action: 'binary', operator: 'divide',
          left: current, right: readNext(next),
        });
        return wrap(r.value);
      },
      mod: function(next) {
        const r = __musicfree_callBridge('MusicFreeBigInt', {
          action: 'binary', operator: 'mod',
          left: current, right: readNext(next),
        });
        return wrap(r.value);
      },
      modPow: function(exponent, modulus) {
        const r = __musicfree_callBridge('MusicFreeBigInt', {
          action: 'modPow',
          base: current,
          exponent: readNext(exponent),
          modulus: readNext(modulus),
        });
        return wrap(r.value);
      },
      compare: function(next) {
        const r = __musicfree_callBridge('MusicFreeBigInt', {
          action: 'compare',
          left: current, right: readNext(next),
        });
        return r.value;
      },
      toString: function(radix) {
        const r = __musicfree_callBridge('MusicFreeBigInt', {
          action: 'toString', value: current, radix: radix || 10,
        });
        return r.value;
      },
      valueOf: function() { return current; },
    };
  };
  return wrap(parseValue(value, arguments[1]));
};
''';
}
