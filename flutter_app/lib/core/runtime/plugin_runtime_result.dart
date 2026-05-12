import '../../features/plugins/domain/plugin.dart';

/// Thrown when a plugin method runs longer than the caller-configured
/// timeout. The instance that produced the timeout is marked as "warning"
/// so the UI can surface the condition without losing top-level state.
class PluginInvocationTimeoutException implements Exception {
  const PluginInvocationTimeoutException({
    required this.method,
    required this.timeout,
    this.storageKey,
  });

  final String method;
  final Duration timeout;
  final String? storageKey;

  @override
  String toString() {
    final keyPart = storageKey == null ? '' : ' for $storageKey';
    return 'Plugin method "$method"$keyPart timed out after '
        '${timeout.inMilliseconds}ms.';
  }
}

class PluginRuntimeResult {
  const PluginRuntimeResult({
    required this.success,
    required this.diagnostics,
    this.manifest,
  });

  final bool success;
  final PluginManifest? manifest;
  final PluginDiagnostics diagnostics;
}

class PluginMethodCallResult {
  const PluginMethodCallResult({
    required this.success,
    required this.logs,
    required this.requiredPackages,
    required this.missingPackages,
    this.data,
    this.errorMessage,
    this.stackTrace,
    this.didTimeout = false,
    this.durationMs,
  });

  final bool success;
  final dynamic data;
  final String? errorMessage;
  final String? stackTrace;
  final List<String> logs;
  final List<String> requiredPackages;
  final List<String> missingPackages;
  final bool didTimeout;
  final int? durationMs;
}
