import 'plugin_runtime_execution_context.dart';
import 'plugin_runtime_shared_scope_builder.dart';

String buildPluginInspectWrapper(PluginRuntimeExecutionContext context) {
  return '''
(function() {
${buildPluginRuntimeSharedScope(context)}
const supportedMethods = [];
for (const key in plugin) {
  if (typeof plugin[key] === 'function') {
    supportedMethods.push(key);
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
    ? plugin.supportedSearchType
    : [],
  userVariables: Array.isArray(plugin && plugin.userVariables) ? plugin.userVariables : [],
  requiredPackages: __musicfree_requiredPackages,
  missingPackages: __musicfree_missingPackages,
  sourceUrlHint: ${context.encode(context.sourceUrl)},
});
})();
''';
}
