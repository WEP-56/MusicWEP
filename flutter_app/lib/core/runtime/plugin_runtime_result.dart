import '../../features/plugins/domain/plugin.dart';

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
  });

  final bool success;
  final dynamic data;
  final String? errorMessage;
  final String? stackTrace;
  final List<String> logs;
  final List<String> requiredPackages;
  final List<String> missingPackages;
}
