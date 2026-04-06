import 'plugin_runtime_execution_context.dart';
import 'plugin_runtime_shared_scope_builder.dart';

String buildPluginInvokeWrapper(
  PluginRuntimeExecutionContext context, {
  required String method,
  required List<dynamic> arguments,
}) {
  return '''
(function() {
${buildPluginRuntimeSharedScope(context)}
const targetMethod = plugin ? plugin[${context.encode(method)}] : null;
if (typeof targetMethod !== 'function') {
  return JSON.stringify({
    success: false,
    errorMessage: 'Plugin does not export method: ' + ${context.encode(method)},
    logs: [],
    requiredPackages: __musicfree_requiredPackages,
    missingPackages: __musicfree_missingPackages,
    sourceUrlHint: ${context.encode(context.sourceUrl)},
  });
}
__musicfree_allowNetworkAccess = true;
return Promise.resolve(
  targetMethod.apply(plugin, ${context.encode(arguments)})
).then(function(result) {
  return JSON.stringify({
    success: true,
    data: result === undefined ? null : result,
    logs: [],
    requiredPackages: __musicfree_requiredPackages,
    missingPackages: __musicfree_missingPackages,
    sourceUrlHint: ${context.encode(context.sourceUrl)},
  });
}).catch(function(error) {
  return JSON.stringify({
    success: false,
    errorMessage: error && error.message ? error.message : String(error),
    stackTrace: error && error.stack ? error.stack : null,
    logs: [],
    requiredPackages: __musicfree_requiredPackages,
    missingPackages: __musicfree_missingPackages,
    sourceUrlHint: ${context.encode(context.sourceUrl)},
  });
});
})();
''';
}
