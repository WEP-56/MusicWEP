import 'dart:convert';

class PluginRuntimeExecutionContext {
  const PluginRuntimeExecutionContext({
    required this.script,
    required this.sourceUrl,
    required this.appVersion,
    required this.os,
    required this.language,
    required this.userVariables,
    required this.supportedPackages,
  });

  final String script;
  final String sourceUrl;
  final String appVersion;
  final String os;
  final String language;
  final Map<String, String> userVariables;
  final List<String> supportedPackages;

  String encode(Object? value) => jsonEncode(value);
}
