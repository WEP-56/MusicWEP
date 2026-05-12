import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_js/extensions/fetch.dart';

import '../../features/plugins/domain/plugin.dart';
import '../filesystem/app_paths.dart';
import '../storage/json_file_store.dart';
import 'internal/plugin_runtime_bigint_bridge.dart';
import 'internal/plugin_runtime_cookie_store.dart';
import 'internal/plugin_runtime_execution_context.dart';
import 'internal/plugin_runtime_host_bridges.dart';
import 'internal/plugin_runtime_html_entities_bridge.dart';
import 'internal/plugin_runtime_http_bridge.dart';
import 'internal/plugin_runtime_logger.dart';
import 'internal/plugin_runtime_shared_scope_builder.dart';
import 'internal/plugin_runtime_state_bridge.dart';
import 'internal/plugin_runtime_webdav_bridge.dart';
import 'plugin_runtime_result.dart';

/// Packages that the runtime intentionally provides via shims. Keep this list
/// in sync with the shim implementations in
/// `internal/plugin_runtime_package_shims.dart`.
const List<String> kPluginRuntimeInspectionPackages = <String>[
  'axios',
  'cheerio',
  'crypto-js',
  'dayjs',
  'big-integer',
  'qs',
  'he',
  'webdav',
  '@react-native-cookies/cookies',
];

/// Default per-invocation timeout. Matches the axios default that plugins
/// historically assume.
const Duration kPluginInvocationDefaultTimeout = Duration(seconds: 15);

/// A loaded plugin JS instance.
///
/// The plugin script is executed exactly once at construction time; subsequent
/// [invoke] / [inspect] calls reuse the same [JavascriptRuntime] so top-level
/// state (tokens, cookies, etc.) is preserved across calls.
class PluginRuntimeInstance {
  PluginRuntimeInstance._({
    required JavascriptRuntime runtime,
    required PluginRuntimeHttpBridge httpBridge,
    required String instanceId,
    required String scriptHash,
    required List<String> consoleLogs,
    required PluginRuntimeLogger? logger,
  }) : _runtime = runtime,
       _httpBridge = httpBridge,
       _instanceId = instanceId,
       _scriptHash = scriptHash,
       _consoleLogs = consoleLogs,
       _logger = logger;

  final JavascriptRuntime _runtime;
  final PluginRuntimeHttpBridge _httpBridge;
  final String _instanceId;
  final String _scriptHash;
  final List<String> _consoleLogs;
  final PluginRuntimeLogger? _logger;

  final _invokeMutex = _SerialQueue();

  // Captured at load time; never mutated afterwards.
  List<String> _loadedRequiredPackages = const <String>[];
  List<String> _loadedMissingPackages = const <String>[];
  String? _loadErrorMessage;
  String? _loadErrorStackTrace;

  bool _disposed = false;
  // Flipped to true on any timeout; caller can use this to flag the plugin
  // as "warning" in diagnostics even though the instance itself continues
  // serving subsequent calls.
  bool _hasTimedOut = false;
  String? _lastTimeoutMessage;

  String get instanceId => _instanceId;
  String get scriptHash => _scriptHash;
  bool get hasTimedOut => _hasTimedOut;
  String? get lastTimeoutMessage => _lastTimeoutMessage;

  /// Boots a [JavascriptRuntime], registers bridges on instance-scoped
  /// channels, then executes [script] exactly once.
  static Future<PluginRuntimeInstance> load({
    required String script,
    required String scriptHash,
    required String sourceUrl,
    required String appVersion,
    required String os,
    required String language,
    required AppPaths appPaths,
    Map<String, String> userVariables = const <String, String>{},
    String? storageKey,
  }) async {
    final instanceId =
        'i${DateTime.now().microsecondsSinceEpoch}_${scriptHash.substring(0, scriptHash.length >= 8 ? 8 : scriptHash.length)}';
    final runtime = _createRuntime();

    final bigIntBridge = PluginRuntimeBigIntBridge();
    final cookieStore = PluginRuntimeCookieStore(
      JsonFileStore(appPaths.pluginCookiesFilePath),
    );
    final stateBridge = PluginRuntimeStateBridge.withCookieStore(
      appPaths: appPaths,
      cookieStore: cookieStore,
    );
    final httpBridge = PluginRuntimeHttpBridge(cookieStore: cookieStore);
    final webDavBridge = PluginRuntimeWebDavBridge();
    final consoleLogs = <String>[];
    final logger = storageKey == null
        ? null
        : PluginRuntimeLogger(
            directoryPath: appPaths.pluginLogsDirectory.path,
            storageKey: storageKey,
          );

    // Register every bridge on an instance-scoped channel. Channel routing in
    // `flutter_js` is per JavascriptRuntime instance anyway, but the suffix
    // makes cross-instance leakage impossible if we ever reuse a runtime.
    runtime.onMessage('MusicFreeBigInt#$instanceId', bigIntBridge.handle);
    runtime.onMessage('MusicFreeCrypto#$instanceId', handleCryptoBridge);
    runtime.onMessage('MusicFreeCheerio#$instanceId', handleCheerioBridge);
    runtime.onMessage(
      'MusicFreeHtmlEntities#$instanceId',
      handleHtmlEntitiesBridge,
    );
    runtime.onMessage('MusicFreeHttp#$instanceId', httpBridge.handle);
    runtime.onMessage(
      'MusicFreeStorage#$instanceId',
      stateBridge.handleStorage,
    );
    runtime.onMessage(
      'MusicFreeCookies#$instanceId',
      stateBridge.handleCookies,
    );
    runtime.onMessage('MusicFreeWebDav#$instanceId', webDavBridge.handle);
    runtime.onMessage('MusicFreeConsole#$instanceId', (dynamic args) {
      if (args is List && args.length > 1) {
        final level = args.first.toString();
        final message = args.skip(1).map((e) => e.toString()).join(' ');
        consoleLogs.add(message);
        if (logger != null) {
          logger.append(level: level, message: message);
        }
      }
      return '';
    });

    final instance = PluginRuntimeInstance._(
      runtime: runtime,
      httpBridge: httpBridge,
      instanceId: instanceId,
      scriptHash: scriptHash,
      consoleLogs: consoleLogs,
      logger: logger,
    );

    await instance._bootstrap(
      script: script,
      sourceUrl: sourceUrl,
      appVersion: appVersion,
      os: os,
      language: language,
      userVariables: userVariables,
    );

    return instance;
  }

  Future<void> _bootstrap({
    required String script,
    required String sourceUrl,
    required String appVersion,
    required String os,
    required String language,
    required Map<String, String> userVariables,
  }) async {
    final context = PluginRuntimeExecutionContext(
      script: script,
      sourceUrl: sourceUrl,
      appVersion: appVersion,
      os: os,
      language: language,
      userVariables: userVariables,
      supportedPackages: kPluginRuntimeInspectionPackages,
    );

    final initScript =
        '''
(function() {
  // Route every MusicFree* channel through this instance's suffixed name so
  // two plugins can never share bridge handlers.
  var __mf_native_sendMessage = sendMessage;
  var __mf_instanceId = ${jsonEncode(_instanceId)};
  var __mf_routedSendMessage = function(channel, payload) {
    if (typeof channel === 'string' && channel.indexOf('MusicFree') === 0 && channel.indexOf('#') === -1) {
      return __mf_native_sendMessage(channel + '#' + __mf_instanceId, payload);
    }
    return __mf_native_sendMessage(channel, payload);
  };
  // eslint-disable-next-line no-global-assign
  sendMessage = __mf_routedSendMessage;

${buildPluginRuntimeSharedScope(context)}

  // Expose runtime handles for subsequent inspect / invoke scripts.
  globalThis.__mf_plugin = plugin;
  globalThis.__mf_requiredPackages = __musicfree_requiredPackages;
  globalThis.__mf_missingPackages = __musicfree_missingPackages;
  // Network side effects are disabled during inspect and must be explicitly
  // enabled by invoke wrappers.
  globalThis.__mf_allowNetworkAccess = function(allow) {
    __musicfree_allowNetworkAccess = !!allow;
  };
  return JSON.stringify({
    ok: true,
    requiredPackages: __musicfree_requiredPackages,
    missingPackages: __musicfree_missingPackages,
  });
})();
''';

    try {
      final payload = await _evaluateJson(initScript, sourceUrl: sourceUrl);
      _loadedRequiredPackages = _readStringList(payload, 'requiredPackages');
      _loadedMissingPackages = _readStringList(payload, 'missingPackages');
    } catch (error, stackTrace) {
      _loadErrorMessage = error.toString();
      _loadErrorStackTrace = stackTrace.toString();
    }
  }

  /// Inspect the already-loaded plugin and return its manifest.
  Future<PluginRuntimeResult> inspect({required String sourceUrl}) async {
    _assertNotDisposed();
    if (_loadErrorMessage != null) {
      return PluginRuntimeResult(
        success: false,
        diagnostics: PluginDiagnostics(
          status: PluginParseStatus.error,
          checkedAt: DateTime.now(),
          message: _loadErrorMessage,
          stackTrace: _loadErrorStackTrace,
          logs: _drainConsoleLogs(),
        ),
      );
    }

    return _invokeMutex.run(() async {
      final capturedLogs = _drainConsoleLogs();
      try {
        final payload = await _evaluateJson(
          _buildInspectScript(),
          sourceUrl: sourceUrl,
        );
        final manifest = PluginManifest.fromJson(payload);
        final requiredPackages = _readStringList(payload, 'requiredPackages');
        final missingPackages = _readStringList(payload, 'missingPackages');
        final logs = _mergeLogs(
          capturedLogs: capturedLogs,
          requiredPackages: requiredPackages,
          missingPackages: missingPackages,
          scope: 'inspect',
        );

        if (manifest.platform.isEmpty) {
          return PluginRuntimeResult(
            success: false,
            diagnostics: PluginDiagnostics(
              status: PluginParseStatus.error,
              checkedAt: DateTime.now(),
              message: 'Plugin export is missing platform.',
              logs: logs,
              requiredPackages: requiredPackages,
              missingPackages: missingPackages,
            ),
          );
        }

        final parseStatus = missingPackages.isEmpty
            ? PluginParseStatus.mounted
            : PluginParseStatus.warning;

        return PluginRuntimeResult(
          success: parseStatus == PluginParseStatus.mounted,
          manifest: PluginManifest(
            platform: manifest.platform,
            version: manifest.version,
            appVersion: manifest.appVersion,
            author: manifest.author,
            description: manifest.description,
            sourceUrl: manifest.sourceUrl,
            supportedMethods: manifest.supportedMethods,
            supportedSearchTypes: manifest.supportedSearchTypes
                .where((e) => e.isNotEmpty)
                .toList(growable: false),
            userVariables: manifest.userVariables
                .where((item) => item.key.isNotEmpty)
                .toList(growable: false),
          ),
          diagnostics: PluginDiagnostics(
            status: parseStatus,
            checkedAt: DateTime.now(),
            message: missingPackages.isEmpty
                ? 'Plugin inspected successfully.'
                : 'Plugin inspected with unsupported package shims: ${missingPackages.join(', ')}.',
            logs: logs,
            requiredPackages: requiredPackages,
            missingPackages: missingPackages,
          ),
        );
      } catch (error, stackTrace) {
        return PluginRuntimeResult(
          success: false,
          diagnostics: PluginDiagnostics(
            status: PluginParseStatus.error,
            checkedAt: DateTime.now(),
            message: error.toString(),
            stackTrace: stackTrace.toString(),
            logs: capturedLogs,
          ),
        );
      }
    });
  }

  /// Invoke a method on the already-loaded plugin. Calls are serialized per
  /// instance so QuickJS pending-job ordering stays deterministic.
  ///
  /// [timeout] enforces an upper bound on how long a single method call can
  /// run. When exceeded the result is marked with `didTimeout = true`; the
  /// instance itself stays usable for subsequent calls (the timed-out JS
  /// continues running in the background but its resolution is discarded).
  Future<PluginMethodCallResult> invoke({
    required String method,
    List<dynamic> arguments = const <dynamic>[],
    String? sourceUrl,
    Map<String, String>? userVariables,
    Duration timeout = kPluginInvocationDefaultTimeout,
  }) async {
    _assertNotDisposed();
    if (_loadErrorMessage != null) {
      return PluginMethodCallResult(
        success: false,
        errorMessage: _loadErrorMessage,
        stackTrace: _loadErrorStackTrace,
        logs: _drainConsoleLogs(),
        requiredPackages: _loadedRequiredPackages,
        missingPackages: _loadedMissingPackages,
      );
    }

    return _invokeMutex.run(() async {
      final stopwatch = Stopwatch()..start();
      final capturedLogs = _drainConsoleLogs();
      await _logger?.append(
        level: 'invoke',
        message: 'start method=$method args=${arguments.length}',
      );
      try {
        final evaluation = _evaluateJson(
          _buildInvokeScript(
            method: method,
            arguments: arguments,
            userVariables: userVariables,
          ),
          sourceUrl: sourceUrl ?? '',
        );
        final payload = await evaluation.timeout(
          timeout,
          onTimeout: () {
            _hasTimedOut = true;
            final timeoutMessage =
                'Plugin method "$method" timed out after ${timeout.inMilliseconds}ms.';
            _lastTimeoutMessage = timeoutMessage;
            throw PluginInvocationTimeoutException(
              method: method,
              timeout: timeout,
              storageKey: _scriptHash,
            );
          },
        );
        stopwatch.stop();
        final requiredPackages = _readStringList(payload, 'requiredPackages');
        final missingPackages = _readStringList(payload, 'missingPackages');
        final success = payload['success'] as bool? ?? false;
        await _logger?.append(
          level: success ? 'invoke' : 'invoke-error',
          message:
              'end method=$method success=$success duration=${stopwatch.elapsedMilliseconds}ms'
              '${success ? '' : ' error=${payload['errorMessage']}'}',
        );
        return PluginMethodCallResult(
          success: success,
          data: payload['data'],
          errorMessage: payload['errorMessage'] as String?,
          stackTrace: payload['stackTrace'] as String?,
          logs: _mergeLogs(
            capturedLogs: capturedLogs,
            requiredPackages: requiredPackages,
            missingPackages: missingPackages,
            scope: 'invoke',
          ),
          requiredPackages: requiredPackages,
          missingPackages: missingPackages,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      } on PluginInvocationTimeoutException catch (error) {
        stopwatch.stop();
        await _logger?.append(
          level: 'invoke-timeout',
          message:
              'method=$method timeout=${timeout.inMilliseconds}ms duration=${stopwatch.elapsedMilliseconds}ms',
        );
        return PluginMethodCallResult(
          success: false,
          errorMessage: error.toString(),
          logs: capturedLogs,
          requiredPackages: _loadedRequiredPackages,
          missingPackages: _loadedMissingPackages,
          didTimeout: true,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      } catch (error, stackTrace) {
        stopwatch.stop();
        await _logger?.append(
          level: 'invoke-error',
          message:
              'method=$method error=$error duration=${stopwatch.elapsedMilliseconds}ms',
        );
        return PluginMethodCallResult(
          success: false,
          errorMessage: error.toString(),
          stackTrace: stackTrace.toString(),
          logs: capturedLogs,
          requiredPackages: _loadedRequiredPackages,
          missingPackages: _loadedMissingPackages,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }
    });
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _httpBridge.dispose();
    _runtime.dispose();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static JavascriptRuntime _createRuntime() {
    if (Platform.isWindows || Platform.isLinux || Platform.isAndroid) {
      final runtime = QuickJsRuntime2(hostPromiseRejectionHandler: (_) {});
      runtime.enableFetch();
      runtime.enableHandlePromises();
      return runtime;
    }
    return getJavascriptRuntime();
  }

  String _buildInspectScript() {
    return '''
(function() {
  var plugin = globalThis.__mf_plugin;
  var requiredPackages = globalThis.__mf_requiredPackages || [];
  var missingPackages = globalThis.__mf_missingPackages || [];
  var supportedMethods = [];
  if (plugin) {
    for (var key in plugin) {
      if (typeof plugin[key] === 'function') {
        supportedMethods.push(key);
      }
    }
  }
  return JSON.stringify({
    platform: plugin && plugin.platform ? plugin.platform : '',
    version: plugin && plugin.version ? plugin.version : null,
    appVersion: plugin && plugin.appVersion ? plugin.appVersion : null,
    author: plugin && plugin.author ? plugin.author : null,
    description: plugin && plugin.description ? plugin.description : null,
    sourceUrl: plugin && plugin.srcUrl ? plugin.srcUrl : null,
    supportedMethods: supportedMethods,
    supportedSearchTypes: Array.isArray(plugin && plugin.supportedSearchType)
      ? plugin.supportedSearchType : [],
    userVariables: Array.isArray(plugin && plugin.userVariables)
      ? plugin.userVariables : [],
    requiredPackages: requiredPackages,
    missingPackages: missingPackages,
  });
})();
''';
  }

  String _buildInvokeScript({
    required String method,
    required List<dynamic> arguments,
    Map<String, String>? userVariables,
  }) {
    final encodedMethod = jsonEncode(method);
    final encodedArgs = jsonEncode(arguments);
    final userVariablesSetter = userVariables == null
        ? ''
        : 'globalThis.__mf_userVariables = ${jsonEncode(userVariables)};';
    return '''
(function() {
  $userVariablesSetter
  var plugin = globalThis.__mf_plugin;
  var requiredPackages = globalThis.__mf_requiredPackages || [];
  var missingPackages = globalThis.__mf_missingPackages || [];
  if (typeof globalThis.__mf_allowNetworkAccess === 'function') {
    globalThis.__mf_allowNetworkAccess(true);
  }
  var targetMethod = plugin ? plugin[$encodedMethod] : null;
  if (typeof targetMethod !== 'function') {
    return JSON.stringify({
      success: false,
      errorMessage: 'Plugin does not export method: ' + $encodedMethod,
      requiredPackages: requiredPackages,
      missingPackages: missingPackages,
    });
  }
  return Promise.resolve(targetMethod.apply(plugin, $encodedArgs))
    .then(function(result) {
      return JSON.stringify({
        success: true,
        data: result === undefined ? null : result,
        requiredPackages: requiredPackages,
        missingPackages: missingPackages,
      });
    })
    .catch(function(error) {
      return JSON.stringify({
        success: false,
        errorMessage: error && error.message ? error.message : String(error),
        stackTrace: error && error.stack ? error.stack : null,
        requiredPackages: requiredPackages,
        missingPackages: missingPackages,
      });
    });
})();
''';
  }

  Future<Map<String, dynamic>> _evaluateJson(
    String script, {
    required String sourceUrl,
  }) async {
    final result = await _runtime.evaluateAsync(script, sourceUrl: sourceUrl);
    _runtime.executePendingJob();
    final resolved = await _runtime
        .handlePromise(result)
        .catchError((_) => result);
    final decoded = jsonDecode(resolved.stringResult);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    throw const FormatException('Runtime wrapper must return a JSON object.');
  }

  List<String> _drainConsoleLogs() {
    if (_consoleLogs.isEmpty) return const <String>[];
    final copy = List<String>.unmodifiable(_consoleLogs);
    _consoleLogs.clear();
    return copy;
  }

  List<String> _mergeLogs({
    required List<String> capturedLogs,
    required List<String> requiredPackages,
    required List<String> missingPackages,
    required String scope,
  }) {
    return <String>[
      ...capturedLogs,
      ...requiredPackages.map((p) => '[$scope] require($p)'),
      ...missingPackages.map((p) => '[$scope] unsupported package shim: $p'),
    ];
  }

  List<String> _readStringList(Map<String, dynamic> payload, String key) {
    return (payload[key] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('PluginRuntimeInstance has been disposed.');
    }
  }
}

/// Ensures only one async task runs at a time. QuickJS pending-job ordering
/// assumes the embedder serializes access, and our JSON bridges rely on that.
class _SerialQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await task());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
