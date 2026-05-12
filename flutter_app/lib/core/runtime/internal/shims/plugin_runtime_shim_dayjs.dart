/// `dayjs` shim. Format tokens plus `diff / startOf / endOf / isBefore /
/// isAfter / isSame` plus a couple of locale tables.
String buildShimDayjs() {
  return r'''
const __musicfree_dayjsLocales = {
  'en': {
    months: ['January','February','March','April','May','June','July','August','September','October','November','December'],
    monthsShort: ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'],
    weekdays: ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'],
    weekdaysShort: ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'],
    meridiem: function(hour) { return hour < 12 ? 'AM' : 'PM'; },
  },
  'zh-cn': {
    months: ['\u4e00\u6708','\u4e8c\u6708','\u4e09\u6708','\u56db\u6708','\u4e94\u6708','\u516d\u6708','\u4e03\u6708','\u516b\u6708','\u4e5d\u6708','\u5341\u6708','\u5341\u4e00\u6708','\u5341\u4e8c\u6708'],
    monthsShort: ['1\u6708','2\u6708','3\u6708','4\u6708','5\u6708','6\u6708','7\u6708','8\u6708','9\u6708','10\u6708','11\u6708','12\u6708'],
    weekdays: ['\u661f\u671f\u65e5','\u661f\u671f\u4e00','\u661f\u671f\u4e8c','\u661f\u671f\u4e09','\u661f\u671f\u56db','\u661f\u671f\u4e94','\u661f\u671f\u516d'],
    weekdaysShort: ['\u5468\u65e5','\u5468\u4e00','\u5468\u4e8c','\u5468\u4e09','\u5468\u56db','\u5468\u4e94','\u5468\u516d'],
    meridiem: function(hour) { return hour < 12 ? '\u4e0a\u5348' : '\u4e0b\u5348'; },
  },
};

let __musicfree_dayjsActiveLocale = 'en';

const __musicfree_dayjsPad = function(num, length) {
  return String(num).padStart(length || 2, '0');
};

const __musicfree_dayjsDiff = function(aMs, bMs, unit) {
  const diff = aMs - bMs;
  switch ((unit || 'millisecond').toLowerCase()) {
    case 'ms': case 'millisecond': case 'milliseconds': return diff;
    case 's': case 'second': case 'seconds': return Math.trunc(diff / 1000);
    case 'm': case 'minute': case 'minutes': return Math.trunc(diff / 60000);
    case 'h': case 'hour': case 'hours': return Math.trunc(diff / 3600000);
    case 'd': case 'day': case 'days': return Math.trunc(diff / 86400000);
    case 'w': case 'week': case 'weeks': return Math.trunc(diff / (86400000 * 7));
    default: return diff;
  }
};

const __musicfree_dayjsWrap = function(date) {
  const api = {
    toDate: function() { return new Date(date.getTime()); },
    valueOf: function() { return date.getTime(); },
    unix: function() { return Math.floor(date.getTime() / 1000); },
    isValid: function() { return !Number.isNaN(date.getTime()); },
    year: function() { return date.getFullYear(); },
    month: function() { return date.getMonth(); },
    date: function() { return date.getDate(); },
    day: function() { return date.getDay(); },
    hour: function() { return date.getHours(); },
    minute: function() { return date.getMinutes(); },
    second: function() { return date.getSeconds(); },
    millisecond: function() { return date.getMilliseconds(); },
    add: function(amount, unit) {
      const next = new Date(date.getTime());
      const n = Number(amount) || 0;
      const u = String(unit || 'millisecond').toLowerCase();
      if (u === 'year' || u === 'years' || u === 'y') next.setFullYear(next.getFullYear() + n);
      else if (u === 'month' || u === 'months' || u === 'm') next.setMonth(next.getMonth() + n);
      else if (u === 'day' || u === 'days' || u === 'd') next.setDate(next.getDate() + n);
      else if (u === 'week' || u === 'weeks' || u === 'w') next.setDate(next.getDate() + n * 7);
      else if (u === 'hour' || u === 'hours' || u === 'h') next.setHours(next.getHours() + n);
      else if (u === 'minute' || u === 'minutes') next.setMinutes(next.getMinutes() + n);
      else if (u === 'second' || u === 'seconds' || u === 's') next.setSeconds(next.getSeconds() + n);
      else next.setMilliseconds(next.getMilliseconds() + n);
      return __musicfree_dayjsWrap(next);
    },
    subtract: function(amount, unit) { return api.add(-amount, unit); },
    startOf: function(unit) {
      const next = new Date(date.getTime());
      const u = String(unit || '').toLowerCase();
      if (u === 'year') { next.setMonth(0, 1); next.setHours(0, 0, 0, 0); }
      else if (u === 'month') { next.setDate(1); next.setHours(0, 0, 0, 0); }
      else if (u === 'day') { next.setHours(0, 0, 0, 0); }
      else if (u === 'hour') { next.setMinutes(0, 0, 0); }
      else if (u === 'minute') { next.setSeconds(0, 0); }
      else if (u === 'second') { next.setMilliseconds(0); }
      return __musicfree_dayjsWrap(next);
    },
    endOf: function(unit) {
      const next = new Date(date.getTime());
      const u = String(unit || '').toLowerCase();
      if (u === 'year') { next.setMonth(11, 31); next.setHours(23, 59, 59, 999); }
      else if (u === 'month') { next.setMonth(next.getMonth() + 1, 0); next.setHours(23, 59, 59, 999); }
      else if (u === 'day') { next.setHours(23, 59, 59, 999); }
      else if (u === 'hour') { next.setMinutes(59, 59, 999); }
      else if (u === 'minute') { next.setSeconds(59, 999); }
      else if (u === 'second') { next.setMilliseconds(999); }
      return __musicfree_dayjsWrap(next);
    },
    diff: function(other, unit) {
      const otherMs = other && typeof other.valueOf === 'function'
        ? other.valueOf() : new Date(other).getTime();
      return __musicfree_dayjsDiff(date.getTime(), otherMs, unit);
    },
    isBefore: function(other) {
      const t = other && typeof other.valueOf === 'function' ? other.valueOf() : new Date(other).getTime();
      return date.getTime() < t;
    },
    isAfter: function(other) {
      const t = other && typeof other.valueOf === 'function' ? other.valueOf() : new Date(other).getTime();
      return date.getTime() > t;
    },
    isSame: function(other, unit) {
      const left = api.startOf(unit).valueOf();
      const rightWrap = __musicfree_dayjsWrap(new Date(other));
      const right = rightWrap.startOf(unit).valueOf();
      return left === right;
    },
    locale: function(tag) {
      if (tag) __musicfree_dayjsActiveLocale = String(tag).toLowerCase();
      return api;
    },
    utc: function() { return api; },
    local: function() { return api; },
    format: function(pattern) {
      const locale = __musicfree_dayjsLocales[__musicfree_dayjsActiveLocale]
        || __musicfree_dayjsLocales.en;
      const year = date.getFullYear();
      const month = date.getMonth();
      const day = date.getDate();
      const weekday = date.getDay();
      const hour24 = date.getHours();
      const hour12 = ((hour24 + 11) % 12) + 1;
      const minute = date.getMinutes();
      const second = date.getSeconds();
      const ms = date.getMilliseconds();
      const offsetMins = -date.getTimezoneOffset();
      const offsetSign = offsetMins >= 0 ? '+' : '-';
      const offsetAbs = Math.abs(offsetMins);
      const zz = offsetSign + __musicfree_dayjsPad(Math.floor(offsetAbs / 60)) + __musicfree_dayjsPad(offsetAbs % 60);
      const z = offsetSign + __musicfree_dayjsPad(Math.floor(offsetAbs / 60)) + ':' + __musicfree_dayjsPad(offsetAbs % 60);
      const tokens = {
        YYYY: String(year), YY: String(year).slice(-2),
        MMMM: locale.months[month], MMM: locale.monthsShort[month],
        MM: __musicfree_dayjsPad(month + 1), M: String(month + 1),
        DD: __musicfree_dayjsPad(day), D: String(day),
        Do: String(day) + (['th','st','nd','rd'][((day % 100) - 20) % 10] || ['th','st','nd','rd'][day] || 'th'),
        dddd: locale.weekdays[weekday], ddd: locale.weekdaysShort[weekday],
        HH: __musicfree_dayjsPad(hour24), H: String(hour24),
        hh: __musicfree_dayjsPad(hour12), h: String(hour12),
        mm: __musicfree_dayjsPad(minute), m: String(minute),
        ss: __musicfree_dayjsPad(second), s: String(second),
        SSS: __musicfree_dayjsPad(ms, 3),
        A: locale.meridiem(hour24).toUpperCase(),
        a: locale.meridiem(hour24).toLowerCase(),
        ZZ: zz, Z: z,
      };
      let output = pattern || 'YYYY-MM-DDTHH:mm:ssZ';
      Object.keys(tokens)
        .sort(function(a, b) { return b.length - a.length; })
        .forEach(function(token) {
          output = output.replaceAll(token, tokens[token]);
        });
      return output;
    },
  };
  return api;
};

const __musicfree_makeDayjs = function(input) {
  const value = input === undefined || input === null ? new Date() : new Date(input);
  return __musicfree_dayjsWrap(value);
};
__musicfree_makeDayjs.extend = function() {};
__musicfree_makeDayjs.locale = function(tag) {
  if (tag) __musicfree_dayjsActiveLocale = String(tag).toLowerCase();
};
__musicfree_makeDayjs.unix = function(value) {
  return __musicfree_makeDayjs(Number(value) * 1000);
};
__musicfree_makeDayjs.utc = function(value) { return __musicfree_makeDayjs(value); };
''';
}
