import 'plugin_runtime_result.dart';

abstract class PluginRuntimeAdapter {
  Future<PluginRuntimeResult> inspectPlugin({
    required String script,
    required String sourceUrl,
    required String appVersion,
    required String os,
    required String language,
    Map<String, String> userVariables,
  });

  Future<PluginMethodCallResult> invokeMethod({
    required String script,
    required String sourceUrl,
    required String appVersion,
    required String os,
    required String language,
    required String method,
    List<dynamic> arguments,
    Map<String, String> userVariables,
  });

  void dispose();
}
