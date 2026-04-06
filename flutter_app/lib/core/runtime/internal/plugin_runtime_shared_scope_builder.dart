import 'plugin_runtime_execution_context.dart';
import 'plugin_runtime_package_shims.dart';

String buildPluginRuntimeSharedScope(PluginRuntimeExecutionContext context) {
  return '''
const __musicfree_supportedPackages = ${context.encode(context.supportedPackages)};
const __musicfree_requiredPackages = [];
const __musicfree_missingPackages = [];
const __musicfree_seenPackages = Object.create(null);
const __musicfree_packageCache = Object.create(null);
const __musicfree_pluginStorage = Object.create(null);
let __musicfree_allowNetworkAccess = false;

const __musicfree_recordPackage = function(packageName) {
  if (!packageName) {
    return;
  }
  if (!__musicfree_seenPackages[packageName]) {
    __musicfree_seenPackages[packageName] = true;
    __musicfree_requiredPackages.push(packageName);
  }
};

const __musicfree_makeInspectableValue = function(label) {
  let proxy;
  const target = function() { return proxy; };
  proxy = new Proxy(target, {
    get: function(_, prop) {
      if (prop === 'default') {
        return proxy;
      }
      if (prop === 'then') {
        return undefined;
      }
      if (prop === 'toJSON') {
        return function() { return null; };
      }
      if (prop === 'toString') {
        return function() { return '[MusicFreeStub ' + label + ']'; };
      }
      if (prop === 'valueOf') {
        return function() { return null; };
      }
      if (prop === Symbol.toPrimitive) {
        return function() { return '[MusicFreeStub ' + label + ']'; };
      }
      if (prop === Symbol.iterator) {
        return function* () {};
      }
      return proxy;
    },
    apply: function() { return proxy; },
    construct: function() { return proxy; },
    set: function() { return true; },
    has: function() { return true; },
    ownKeys: function() { return []; },
    getOwnPropertyDescriptor: function() {
      return {
        configurable: true,
        enumerable: false,
        writable: true,
        value: proxy,
      };
    },
  });
  return proxy;
};

const __musicfree_withDefaultExport = function(value) {
  if (value === null || value === undefined) {
    return value;
  }
  if (
    (typeof value === 'object' || typeof value === 'function') &&
    !Object.prototype.hasOwnProperty.call(value, 'default')
  ) {
    value.default = value;
  }
  return value;
};

const __musicfree_getPackage = function(packageName) {
  if (__musicfree_packages[packageName]) {
    return __musicfree_withDefaultExport(__musicfree_packages[packageName]);
  }
  if (!__musicfree_packageCache[packageName]) {
    __musicfree_packageCache[packageName] =
      __musicfree_withDefaultExport(
        __musicfree_makeUnsupportedPackage(packageName),
      );
  }
  return __musicfree_packageCache[packageName];
};

${buildPluginRuntimePackageShimScript()}

const __musicfree_module = { exports: {} };
const module = __musicfree_module;
const exports = module.exports;
const env = {
  appVersion: ${context.encode(context.appVersion)},
  os: ${context.encode(context.os)},
  lang: ${context.encode(context.language)},
  getUserVariables: function() { return ${context.encode(context.userVariables)}; },
  get userVariables() { return this.getUserVariables(); },
};
const process = {
  platform: ${context.encode(context.os)},
  version: ${context.encode(context.appVersion)},
  env: env,
};
const __musicfree_require = function(packageName) {
  const normalizedName = String(packageName ?? '');
  __musicfree_recordPackage(normalizedName);
  if (
    normalizedName &&
    __musicfree_supportedPackages.indexOf(normalizedName) === -1 &&
    __musicfree_missingPackages.indexOf(normalizedName) === -1
  ) {
    __musicfree_missingPackages.push(normalizedName);
  }
  return __musicfree_getPackage(normalizedName || 'unknown');
};
const require = __musicfree_require;
const __musicfree_console = {
  log: function() {
    return sendMessage(
      'MusicFreeConsole',
      JSON.stringify(['log'].concat(Array.prototype.slice.call(arguments))),
    );
  },
  warn: function() {
    return sendMessage(
      'MusicFreeConsole',
      JSON.stringify(['warn'].concat(Array.prototype.slice.call(arguments))),
    );
  },
  info: function() {
    return sendMessage(
      'MusicFreeConsole',
      JSON.stringify(['info'].concat(Array.prototype.slice.call(arguments))),
    );
  },
  error: function() {
    return sendMessage(
      'MusicFreeConsole',
      JSON.stringify(['error'].concat(Array.prototype.slice.call(arguments))),
    );
  },
};
const pluginFactory = Function(
  '"use strict";\\nreturn function(require, __musicfree_require, module, exports, console, env, URL, process) {\\n' + ${context.encode(context.script)} + '\\n}'
)();
pluginFactory(
  require,
  __musicfree_require,
  module,
  exports,
  __musicfree_console,
  env,
  __musicfree_URL,
  process,
);
const plugin =
  module.exports && module.exports.default ? module.exports.default : module.exports;
''';
}
