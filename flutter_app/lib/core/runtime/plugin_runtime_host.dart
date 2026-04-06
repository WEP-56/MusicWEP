import 'dart:io';
import 'dart:convert';

import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_js/extensions/fetch.dart';
import 'package:pub_semver/pub_semver.dart';

import '../filesystem/app_paths.dart';
import '../../features/plugins/domain/plugin.dart';
import '../../features/plugins/domain/plugin_capability.dart';
import 'internal/plugin_runtime_execution_context.dart';
import 'internal/plugin_runtime_bigint_bridge.dart';
import 'internal/plugin_runtime_host_bridges.dart';
import 'internal/plugin_runtime_http_bridge.dart';
import 'internal/plugin_runtime_inspect_wrapper_builder.dart';
import 'internal/plugin_runtime_state_bridge.dart';
import 'internal/plugin_runtime_invoke_wrapper_builder.dart';
import 'internal/plugin_runtime_webdav_bridge.dart';
import 'plugin_runtime_adapter.dart';
import 'plugin_runtime_result.dart';

class PluginRuntimeHost implements PluginRuntimeAdapter {
  PluginRuntimeHost({required AppPaths appPaths})
    : _runtime = _createRuntime(),
      _bigIntBridge = PluginRuntimeBigIntBridge(),
      _stateBridge = PluginRuntimeStateBridge(appPaths),
      _httpBridge = PluginRuntimeHttpBridge(),
      _webDavBridge = PluginRuntimeWebDavBridge() {
    _runtime.onMessage('MusicFreeBigInt', _bigIntBridge.handle);
    _runtime.onMessage('MusicFreeCrypto', handleCryptoBridge);
    _runtime.onMessage('MusicFreeCheerio', handleCheerioBridge);
    _runtime.onMessage('MusicFreeHttp', _httpBridge.handle);
    _runtime.onMessage('MusicFreeStorage', _stateBridge.handleStorage);
    _runtime.onMessage('MusicFreeCookies', _stateBridge.handleCookies);
    _runtime.onMessage('MusicFreeWebDav', _webDavBridge.handle);
  }

  static const List<String> _inspectionPackages = <String>[
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

  final PluginRuntimeBigIntBridge _bigIntBridge;
  final JavascriptRuntime _runtime;
  final PluginRuntimeStateBridge _stateBridge;
  final PluginRuntimeHttpBridge _httpBridge;
  final PluginRuntimeWebDavBridge _webDavBridge;

  static JavascriptRuntime _createRuntime() {
    if (Platform.isWindows || Platform.isLinux || Platform.isAndroid) {
      final JavascriptRuntime runtime = QuickJsRuntime2(
        hostPromiseRejectionHandler: (_) {
          // Plugin method wrappers convert promise rejections into structured results.
        },
      );
      runtime.enableFetch();
      runtime.enableHandlePromises();
      return runtime;
    }
    return getJavascriptRuntime();
  }

  @override
  Future<PluginRuntimeResult> inspectPlugin({
    required String script,
    required String sourceUrl,
    required String appVersion,
    required String os,
    required String language,
    Map<String, String> userVariables = const <String, String>{},
  }) async {
    final capturedLogs = _captureConsoleLogs();
    final context = _createContext(
      script: script,
      sourceUrl: sourceUrl,
      appVersion: appVersion,
      os: os,
      language: language,
      userVariables: userVariables,
    );

    try {
      final payload = await _runJsonWrapper(
        buildPluginInspectWrapper(context),
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

      final compatibilityMessage = _checkCompatibility(
        pluginVersionConstraint: manifest.appVersion,
        appVersion: appVersion,
      );
      final parseStatus =
          compatibilityMessage == null && missingPackages.isEmpty
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
          supportedMethods: manifest.supportedMethods
              .where((method) => PluginCapability.fromMethod(method) != null)
              .toList(growable: false),
          supportedSearchTypes: manifest.supportedSearchTypes
              .where((entry) => entry.isNotEmpty)
              .toList(growable: false),
          userVariables: manifest.userVariables
              .where((item) => item.key.isNotEmpty)
              .toList(growable: false),
        ),
        diagnostics: PluginDiagnostics(
          status: parseStatus,
          checkedAt: DateTime.now(),
          message: _buildDiagnosticsMessage(
            compatibilityMessage: compatibilityMessage,
            missingPackages: missingPackages,
          ),
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
  }

  @override
  Future<PluginMethodCallResult> invokeMethod({
    required String script,
    required String sourceUrl,
    required String appVersion,
    required String os,
    required String language,
    required String method,
    List<dynamic> arguments = const <dynamic>[],
    Map<String, String> userVariables = const <String, String>{},
  }) async {
    final capturedLogs = _captureConsoleLogs();
    final context = _createContext(
      script: script,
      sourceUrl: sourceUrl,
      appVersion: appVersion,
      os: os,
      language: language,
      userVariables: userVariables,
    );

    try {
      final payload = await _runJsonWrapper(
        buildPluginInvokeWrapper(context, method: method, arguments: arguments),
        sourceUrl: sourceUrl,
      );
      final requiredPackages = _readStringList(payload, 'requiredPackages');
      final missingPackages = _readStringList(payload, 'missingPackages');
      return PluginMethodCallResult(
        success: payload['success'] as bool? ?? false,
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
      );
    } catch (error, stackTrace) {
      return PluginMethodCallResult(
        success: false,
        errorMessage: error.toString(),
        stackTrace: stackTrace.toString(),
        logs: capturedLogs,
        requiredPackages: const <String>[],
        missingPackages: const <String>[],
      );
    }
  }

  PluginRuntimeExecutionContext _createContext({
    required String script,
    required String sourceUrl,
    required String appVersion,
    required String os,
    required String language,
    required Map<String, String> userVariables,
  }) {
    return PluginRuntimeExecutionContext(
      script: script,
      sourceUrl: sourceUrl,
      appVersion: appVersion,
      os: os,
      language: language,
      userVariables: userVariables,
      supportedPackages: _inspectionPackages,
    );
  }

  Future<Map<String, dynamic>> _runJsonWrapper(
    String wrapper, {
    required String sourceUrl,
  }) async {
    final result = await _runtime.evaluateAsync(wrapper, sourceUrl: sourceUrl);
    _runtime.executePendingJob();
    final resolved = await _runtime
        .handlePromise(result)
        .catchError((_) => result);
    final payload = jsonDecode(resolved.stringResult);
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is Map) {
      return payload.map((key, value) => MapEntry(key.toString(), value));
    }
    throw const FormatException('Runtime wrapper must return a JSON object.');
  }

  List<String> _captureConsoleLogs() {
    final logs = <String>[];
    _runtime.onMessage('MusicFreeConsole', (dynamic args) {
      if (args is List && args.length > 1) {
        logs.add(args.skip(1).map((entry) => entry.toString()).join(' '));
      }
    });
    return logs;
  }

  List<String> _mergeLogs({
    required List<String> capturedLogs,
    required List<String> requiredPackages,
    required List<String> missingPackages,
    required String scope,
  }) {
    return <String>[
      ...capturedLogs,
      ...requiredPackages.map(
        (packageName) => '[$scope] require($packageName)',
      ),
      ...missingPackages.map(
        (packageName) => '[$scope] unsupported package shim: $packageName',
      ),
    ];
  }

  List<String> _readStringList(Map<String, dynamic> payload, String key) {
    return (payload[key] as List<dynamic>? ?? const <dynamic>[])
        .map((entry) => entry.toString())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  String _buildDiagnosticsMessage({
    required String? compatibilityMessage,
    required List<String> missingPackages,
  }) {
    if (compatibilityMessage != null && missingPackages.isNotEmpty) {
      return '$compatibilityMessage Unsupported packages referenced during inspection: ${missingPackages.join(', ')}.';
    }
    if (compatibilityMessage != null) {
      return compatibilityMessage;
    }
    if (missingPackages.isNotEmpty) {
      return 'Plugin inspected with unsupported package shims: ${missingPackages.join(', ')}.';
    }
    return 'Plugin inspected successfully.';
  }

  String? _checkCompatibility({
    required String? pluginVersionConstraint,
    required String appVersion,
  }) {
    if (pluginVersionConstraint == null ||
        pluginVersionConstraint.trim().isEmpty) {
      return null;
    }

    try {
      final constraint = VersionConstraint.parse(
        pluginVersionConstraint.trim(),
      );
      final currentVersion = Version.parse(appVersion);
      if (constraint.allows(currentVersion)) {
        return null;
      }
      return 'Plugin expects appVersion $pluginVersionConstraint, current app is $appVersion.';
    } catch (_) {
      return 'Unable to validate appVersion constraint: $pluginVersionConstraint';
    }
  }

  @override
  void dispose() {
    _httpBridge.dispose();
    _runtime.dispose();
  }
}
