import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:pub_semver/pub_semver.dart';

import '../../features/plugins/domain/plugin.dart';
import '../../features/plugins/domain/plugin_capability.dart';
import '../filesystem/app_paths.dart';
import 'plugin_runtime_adapter.dart';
import 'plugin_runtime_instance.dart';
import 'plugin_runtime_result.dart';

/// Caches [PluginRuntimeInstance]s keyed by script hash so a plugin's top-level
/// state (tokens, cookies, etc.) survives across calls within a session.
///
/// Each `invokeMethod` / `inspectPlugin` call reuses the already-loaded
/// instance. The script is executed exactly once per hash.
class PluginRuntimeHost implements PluginRuntimeAdapter {
  PluginRuntimeHost({
    required AppPaths appPaths,
    Duration invocationTimeout = kPluginInvocationDefaultTimeout,
  }) : _appPaths = appPaths,
       _invocationTimeout = invocationTimeout;

  final AppPaths _appPaths;
  final Duration _invocationTimeout;
  final Map<String, PluginRuntimeInstance> _instancesByHash =
      <String, PluginRuntimeInstance>{};
  final Map<String, Future<PluginRuntimeInstance>> _loading =
      <String, Future<PluginRuntimeInstance>>{};
  bool _disposed = false;

  /// Returns a ready instance for [script]. Reuses the cached instance if
  /// the hash matches, otherwise loads and caches a new one.
  Future<PluginRuntimeInstance> acquireInstance({
    required String script,
    required String sourceUrl,
    required String appVersion,
    required String os,
    required String language,
    Map<String, String> userVariables = const <String, String>{},
    String? storageKey,
  }) {
    _assertNotDisposed();
    final hash = _hashScript(script);
    final cached = _instancesByHash[hash];
    if (cached != null) {
      return Future<PluginRuntimeInstance>.value(cached);
    }
    final pending = _loading[hash];
    if (pending != null) return pending;

    final future = PluginRuntimeInstance.load(
      script: script,
      scriptHash: hash,
      sourceUrl: sourceUrl,
      appVersion: appVersion,
      os: os,
      language: language,
      appPaths: _appPaths,
      userVariables: userVariables,
      storageKey: storageKey,
    ).then((instance) {
      _instancesByHash[hash] = instance;
      _loading.remove(hash);
      return instance;
    }).catchError((Object error, StackTrace stackTrace) {
      _loading.remove(hash);
      throw error;
    });
    _loading[hash] = future;
    return future;
  }

  /// Disposes and forgets the cached instance for [script] so the next call
  /// re-executes the script. Callers should use this when the plugin file
  /// changes on disk.
  void evictInstance(String script) {
    final hash = _hashScript(script);
    final removed = _instancesByHash.remove(hash);
    removed?.dispose();
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
    final instance = await acquireInstance(
      script: script,
      sourceUrl: sourceUrl,
      appVersion: appVersion,
      os: os,
      language: language,
      userVariables: userVariables,
    );
    final result = await instance.inspect(sourceUrl: sourceUrl);

    final manifest = result.manifest;
    if (manifest == null) return result;

    final compatibilityMessage = _checkCompatibility(
      pluginVersionConstraint: manifest.appVersion,
      appVersion: appVersion,
    );
    final filteredManifest = PluginManifest(
      platform: manifest.platform,
      version: manifest.version,
      appVersion: manifest.appVersion,
      author: manifest.author,
      description: manifest.description,
      sourceUrl: manifest.sourceUrl,
      supportedMethods: manifest.supportedMethods
          .where((method) => PluginCapability.fromMethod(method) != null)
          .toList(growable: false),
      supportedSearchTypes: manifest.supportedSearchTypes,
      userVariables: manifest.userVariables,
    );
    final parseStatus =
        compatibilityMessage == null &&
            result.diagnostics.missingPackages.isEmpty
        ? PluginParseStatus.mounted
        : PluginParseStatus.warning;

    return PluginRuntimeResult(
      success: parseStatus == PluginParseStatus.mounted,
      manifest: filteredManifest,
      diagnostics: PluginDiagnostics(
        status: parseStatus,
        checkedAt: result.diagnostics.checkedAt,
        message: _buildDiagnosticsMessage(
          compatibilityMessage: compatibilityMessage,
          missingPackages: result.diagnostics.missingPackages,
        ),
        logs: result.diagnostics.logs,
        requiredPackages: result.diagnostics.requiredPackages,
        missingPackages: result.diagnostics.missingPackages,
      ),
    );
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
    String? storageKey,
    Duration? timeout,
  }) async {
    final instance = await acquireInstance(
      script: script,
      sourceUrl: sourceUrl,
      appVersion: appVersion,
      os: os,
      language: language,
      userVariables: userVariables,
      storageKey: storageKey,
    );
    return instance.invoke(
      method: method,
      arguments: arguments,
      sourceUrl: sourceUrl,
      userVariables: userVariables,
      timeout: timeout ?? _invocationTimeout,
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final instances = _instancesByHash.values.toList(growable: false);
    _instancesByHash.clear();
    _loading.clear();
    for (final instance in instances) {
      instance.dispose();
    }
  }

  String _hashScript(String script) {
    return sha256.convert(utf8.encode(script)).toString();
  }

  String _buildDiagnosticsMessage({
    required String? compatibilityMessage,
    required List<String> missingPackages,
  }) {
    if (compatibilityMessage != null && missingPackages.isNotEmpty) {
      return '$compatibilityMessage Unsupported packages referenced during '
          'inspection: ${missingPackages.join(', ')}.';
    }
    if (compatibilityMessage != null) return compatibilityMessage;
    if (missingPackages.isNotEmpty) {
      return 'Plugin inspected with unsupported package shims: '
          '${missingPackages.join(', ')}.';
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
      if (constraint.allows(currentVersion)) return null;
      return 'Plugin expects appVersion $pluginVersionConstraint, current app '
          'is $appVersion.';
    } catch (_) {
      return 'Unable to validate appVersion constraint: '
          '$pluginVersionConstraint';
    }
  }

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('PluginRuntimeHost has been disposed.');
    }
  }
}
