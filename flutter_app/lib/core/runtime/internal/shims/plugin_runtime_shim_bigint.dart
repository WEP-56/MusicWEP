/// `big-integer` shim. Implemented in native JS BigInt with fallbacks to the
/// Dart-side bridge only for `modPow` — BigInt pow + mod is fast enough in
/// native and avoids Promise round-trips.
String buildShimBigInt() {
  return r'''
const __musicfree_bigIntFrom = function(value, radix) {
  if (value === null || value === undefined) return 0n;
  if (typeof value === 'bigint') return value;
  if (typeof value === 'number') return BigInt(value);
  if (value && value.__musicfreeBigIntValue !== undefined) {
    return value.__musicfreeBigIntValue;
  }
  const asString = String(value).trim();
  if (radix && radix !== 10) {
    const sign = asString.startsWith('-') ? -1n : 1n;
    const magnitudeString = sign === -1n ? asString.slice(1) : asString;
    let result = 0n;
    const base = BigInt(radix);
    for (let i = 0; i < magnitudeString.length; i += 1) {
      const digit = parseInt(magnitudeString[i], radix);
      if (Number.isNaN(digit)) {
        throw new Error('big-integer: invalid digit "' + magnitudeString[i] + '" in radix ' + radix);
      }
      result = result * base + BigInt(digit);
    }
    return sign * result;
  }
  return BigInt(asString || '0');
};

const __musicfree_bigIntWrap = function(value) {
  const current = __musicfree_bigIntFrom(value);
  const self = {
    __musicfreeBigIntValue: current,
    valueOf: function() { return current; },
    toJSNumber: function() { return Number(current); },
    isZero: function() { return current === 0n; },
    isNegative: function() { return current < 0n; },
    isPositive: function() { return current > 0n; },
    isEven: function() { return (current & 1n) === 0n; },
    isOdd: function() { return (current & 1n) === 1n; },
    sign: function() {
      if (current > 0n) return 1;
      if (current < 0n) return -1;
      return 0;
    },
    abs: function() { return __musicfree_bigIntWrap(current < 0n ? -current : current); },
    negate: function() { return __musicfree_bigIntWrap(-current); },
    square: function() { return __musicfree_bigIntWrap(current * current); },
    add: function(other) { return __musicfree_bigIntWrap(current + __musicfree_bigIntFrom(other)); },
    subtract: function(other) { return __musicfree_bigIntWrap(current - __musicfree_bigIntFrom(other)); },
    minus: function(other) { return self.subtract(other); },
    multiply: function(other) { return __musicfree_bigIntWrap(current * __musicfree_bigIntFrom(other)); },
    times: function(other) { return self.multiply(other); },
    divide: function(other) { return __musicfree_bigIntWrap(current / __musicfree_bigIntFrom(other)); },
    over: function(other) { return self.divide(other); },
    mod: function(other) { return __musicfree_bigIntWrap(current % __musicfree_bigIntFrom(other)); },
    remainder: function(other) { return self.mod(other); },
    pow: function(other) { return __musicfree_bigIntWrap(current ** __musicfree_bigIntFrom(other)); },
    modPow: function(exponent, modulus) {
      const e = __musicfree_bigIntFrom(exponent);
      const m = __musicfree_bigIntFrom(modulus);
      if (m === 0n) throw new Error('big-integer: modulus is zero');
      let base = current % m; if (base < 0n) base += m;
      let exp = e; let result = 1n;
      while (exp > 0n) {
        if ((exp & 1n) === 1n) result = (result * base) % m;
        exp >>= 1n;
        base = (base * base) % m;
      }
      return __musicfree_bigIntWrap(result);
    },
    modInv: function(modulus) {
      const m = __musicfree_bigIntFrom(modulus);
      let a = ((current % m) + m) % m;
      let g = m;
      let x = 0n; let y = 1n;
      while (a !== 0n) {
        const q = g / a;
        const t = g - q * a; g = a; a = t;
        const u = x - q * y; x = y; y = u;
      }
      if (g !== 1n) throw new Error('big-integer: value has no modular inverse');
      return __musicfree_bigIntWrap(((x % m) + m) % m);
    },
    gcd: function(other) {
      let a = current < 0n ? -current : current;
      let b = __musicfree_bigIntFrom(other);
      if (b < 0n) b = -b;
      while (b !== 0n) { const t = b; b = a % b; a = t; }
      return __musicfree_bigIntWrap(a);
    },
    and: function(other) { return __musicfree_bigIntWrap(current & __musicfree_bigIntFrom(other)); },
    or: function(other) { return __musicfree_bigIntWrap(current | __musicfree_bigIntFrom(other)); },
    xor: function(other) { return __musicfree_bigIntWrap(current ^ __musicfree_bigIntFrom(other)); },
    not: function() { return __musicfree_bigIntWrap(~current); },
    shiftLeft: function(n) { return __musicfree_bigIntWrap(current << __musicfree_bigIntFrom(n)); },
    shiftRight: function(n) { return __musicfree_bigIntWrap(current >> __musicfree_bigIntFrom(n)); },
    bitLength: function() {
      let bits = 0n; let value = current < 0n ? -current : current;
      while (value > 0n) { bits += 1n; value >>= 1n; }
      return __musicfree_bigIntWrap(bits);
    },
    compare: function(other) {
      const o = __musicfree_bigIntFrom(other);
      if (current === o) return 0;
      return current > o ? 1 : -1;
    },
    compareAbs: function(other) {
      const a = current < 0n ? -current : current;
      let o = __musicfree_bigIntFrom(other);
      if (o < 0n) o = -o;
      if (a === o) return 0;
      return a > o ? 1 : -1;
    },
    eq: function(other) { return self.compare(other) === 0; },
    equals: function(other) { return self.eq(other); },
    neq: function(other) { return self.compare(other) !== 0; },
    notEquals: function(other) { return self.neq(other); },
    lt: function(other) { return self.compare(other) < 0; },
    lesser: function(other) { return self.lt(other); },
    lte: function(other) { return self.compare(other) <= 0; },
    lesserOrEquals: function(other) { return self.lte(other); },
    gt: function(other) { return self.compare(other) > 0; },
    greater: function(other) { return self.gt(other); },
    gte: function(other) { return self.compare(other) >= 0; },
    greaterOrEquals: function(other) { return self.gte(other); },
    isPrime: function() {
      const n = current < 0n ? -current : current;
      if (n < 2n) return false;
      if (n === 2n || n === 3n) return true;
      if ((n & 1n) === 0n) return false;
      const small = [3n, 5n, 7n, 11n, 13n, 17n, 19n, 23n, 29n];
      for (const p of small) { if (n === p) return true; if (n % p === 0n) return false; }
      // Miller-Rabin with a few deterministic witnesses for n < 3,317,044,064,679,887,385,961,981
      const witnesses = [2n, 3n, 5n, 7n, 11n, 13n, 17n, 19n, 23n, 29n, 31n, 37n];
      let d = n - 1n; let r = 0n;
      while ((d & 1n) === 0n) { d >>= 1n; r += 1n; }
      outer: for (const a of witnesses) {
        if (a >= n) continue;
        let x = self.constructor ? __musicfree_bigIntWrap(a).modPow(d, n).valueOf() : a;
        if (x === 1n || x === n - 1n) continue;
        for (let i = 0n; i < r - 1n; i += 1n) {
          x = (x * x) % n;
          if (x === n - 1n) continue outer;
        }
        return false;
      }
      return true;
    },
    toString: function(radix) {
      return current.toString(radix || 10);
    },
  };
  return self;
};

const __musicfree_makeBigInteger = function(value, radix) {
  return __musicfree_bigIntWrap(__musicfree_bigIntFrom(value, radix || 10));
};

__musicfree_makeBigInteger.one = __musicfree_bigIntWrap(1n);
__musicfree_makeBigInteger.zero = __musicfree_bigIntWrap(0n);
__musicfree_makeBigInteger.minusOne = __musicfree_bigIntWrap(-1n);
__musicfree_makeBigInteger.randBetween = function(min, max) {
  const lo = __musicfree_bigIntFrom(min);
  const hi = __musicfree_bigIntFrom(max);
  if (hi < lo) throw new Error('big-integer: randBetween max < min');
  const range = hi - lo + 1n;
  // Weak randomness is fine for our plugin use cases (signature nonces come
  // from crypto-js); this mirrors the JS `big-integer` package behavior.
  let bits = 0n; let tmp = range;
  while (tmp > 0n) { bits += 1n; tmp >>= 1n; }
  let result;
  do {
    result = 0n;
    for (let i = 0n; i < bits; i += 1n) {
      result = (result << 1n) | (Math.random() < 0.5 ? 0n : 1n);
    }
  } while (result >= range);
  return __musicfree_bigIntWrap(lo + result);
};
''';
}
