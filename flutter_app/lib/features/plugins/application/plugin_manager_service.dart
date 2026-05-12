import 'package:path/path.dart' as path;

import '../../../core/runtime/plugin_runtime_adapter.dart';
import '../../../core/runtime/plugin_runtime_host.dart';
import '../../../core/runtime/plugin_runtime_result.dart';
import 'plugin_installation_coordinator.dart';
import 'plugin_search_executor.dart';
import '../domain/plugin.dart';
import '../domain/plugin_search.dart';
import '../infrastructure/plugin_file_repository.dart';
import '../infrastructure/plugin_meta_repository.dart';
import '../infrastructure/plugin_subscription_repository.dart';

class PluginManagerSnapshot {
  const PluginManagerSnapshot({
    required this.plugins,
    required this.subscriptions,
  });

  final List<PluginRecord> plugins;
  final List<PluginSubscription> subscriptions;
}

class PluginManagerService {
  PluginManagerService({
    required PluginFileRepository fileRepository,
    required PluginMetaRepository metaRepository,
    required PluginSubscriptionRepository subscriptionRepository,
    required PluginRuntimeAdapter runtime,
    required this.appVersion,
    this.os = 'windows',
    this.language = 'zh-CN',
  }) : _fileRepository = fileRepository,
       _metaRepository = metaRepository,
       _subscriptionRepository = subscriptionRepository,
       _runtime = runtime;

  final PluginFileRepository _fileRepository;
  final PluginMetaRepository _metaRepository;
  final PluginSubscriptionRepository _subscriptionRepository;
  final PluginRuntimeAdapter _runtime;
  final String appVersion;
  final String os;
  final String language;

  PluginInstallationCoordinator get _installationCoordinator {
    return PluginInstallationCoordinator(
      fileRepository: _fileRepository,
      metaRepository: _metaRepository,
      subscriptionRepository: _subscriptionRepository,
      runtime: _runtime,
      loadPlugins: _loadPlugins,
      appVersion: appVersion,
      os: os,
      language: language,
    );
  }

  PluginSearchExecutor get _searchExecutor {
    return PluginSearchExecutor(
      fileRepository: _fileRepository,
      runtime: _runtime,
      loadPlugins: _loadPlugins,
      appVersion: appVersion,
      os: os,
      language: language,
    );
  }

  Future<PluginManagerSnapshot> load() async {
    final metaMap = await _metaRepository.loadAll();
    final subscriptions = await _subscriptionRepository.loadAll();
    final files = await _fileRepository.listPluginFiles();

    final plugins = <PluginRecord>[];
    final loadedStorageKeys = <String>{};
    final seenHashes = <String>{};
    final duplicateFilePaths = <String>[];
    for (final file in files) {
      final script = await _fileRepository.readScript(file.path);
      final hash = _fileRepository.calculateHash(script);
      if (!seenHashes.add(hash)) {
        duplicateFilePaths.add(file.path);
        continue;
      }
      final runtimeResult = await _runtime.inspectPlugin(
        script: script,
        sourceUrl: file.uri.toString(),
        appVersion: appVersion,
        os: os,
        language: language,
      );
      final manifest = runtimeResult.manifest;
      final storageKey = manifest?.platform.isNotEmpty == true
          ? manifest!.platform
          : 'hash:$hash';
      final existingMeta = metaMap[storageKey] ?? PluginMetaRecord.initial();
      final mergedMeta = existingMeta.copyWith(
        sourceUrl: _installationCoordinator.resolveStoredSourceUrl(
          manifestSourceUrl: manifest?.sourceUrl,
          existingSourceUrl: existingMeta.sourceUrl,
        ),
        installedVersion: manifest?.version ?? existingMeta.installedVersion,
        diagnostics: runtimeResult.diagnostics,
      );
      metaMap[storageKey] = mergedMeta;
      loadedStorageKeys.add(storageKey);
      plugins.add(
        PluginRecord(
          filePath: file.path,
          fileName: path.basename(file.path),
          hash: hash,
          manifest: manifest,
          meta: mergedMeta,
        ),
      );
    }

    for (final filePath in duplicateFilePaths) {
      await _fileRepository.deletePlugin(filePath);
    }

    metaMap.removeWhere((key, _) => !loadedStorageKeys.contains(key));

    plugins.sort((left, right) {
      final orderCompare = left.meta.order.compareTo(right.meta.order);
      if (orderCompare != 0) {
        return orderCompare;
      }
      return left.displayName.toLowerCase().compareTo(
        right.displayName.toLowerCase(),
      );
    });

    await _metaRepository.saveAll(metaMap);

    return PluginManagerSnapshot(
      plugins: plugins,
      subscriptions: subscriptions,
    );
  }

  Future<PluginManagerSnapshot> installFromLocal(String sourcePath) async {
    await _installationCoordinator.installFromLocal(sourcePath);
    return load();
  }

  Future<PluginManagerSnapshot> installFromUrl(String inputUrl) async {
    await _installationCoordinator.installFromUrl(inputUrl);
    return load();
  }

  Future<PluginManagerSnapshot> saveSubscriptions(
    List<PluginSubscription> subscriptions,
  ) async {
    await _installationCoordinator.saveSubscriptions(subscriptions);
    return load();
  }

  Future<PluginManagerSnapshot> refreshSubscriptions() async {
    await _installationCoordinator.refreshSubscriptions();
    return load();
  }

  Future<PluginManagerSnapshot> setPluginEnabled(
    PluginRecord plugin,
    bool enabled,
  ) async {
    final records = await _metaRepository.loadAll();
    records[plugin.storageKey] = plugin.meta.copyWith(enabled: enabled);
    await _metaRepository.saveAll(records);
    return load();
  }

  Future<PluginManagerSnapshot> uninstallPlugin(PluginRecord plugin) async {
    await _fileRepository.deletePlugin(plugin.filePath);
    final records = await _metaRepository.loadAll();
    records.remove(plugin.storageKey);
    await _metaRepository.saveAll(records);
    return load();
  }

  Future<PluginManagerSnapshot> reorderPlugins(
    List<PluginRecord> plugins,
  ) async {
    final records = await _metaRepository.loadAll();
    for (var index = 0; index < plugins.length; index++) {
      final plugin = plugins[index];
      final record = records[plugin.storageKey] ?? plugin.meta;
      records[plugin.storageKey] = record.copyWith(order: index);
    }
    await _metaRepository.saveAll(records);
    return load();
  }

  Future<PluginManagerSnapshot> updatePlugin(PluginRecord plugin) async {
    await _installationCoordinator.updatePlugin(plugin);
    return load();
  }

  Future<List<PluginSearchResult>> searchAllEnabled({
    required String query,
    required PluginSearchType type,
    int page = 1,
  }) async {
    return _searchExecutor.searchAllEnabled(
      query: query,
      type: type,
      page: page,
    );
  }

  Future<PluginSearchResult> searchPlugin({
    required PluginRecord plugin,
    required String query,
    required PluginSearchType type,
    int page = 1,
  }) {
    return _searchExecutor.searchPlugin(
      plugin: plugin,
      query: query,
      type: type,
      page: page,
    );
  }

  Future<PluginMethodCallResult> invokePluginMethod(
    PluginRecord plugin, {
    required String method,
    List<dynamic> arguments = const <dynamic>[],
    Duration? timeout,
  }) async {
    final script = await _fileRepository.readScript(plugin.filePath);
    final result = await _runtime.invokeMethod(
      script: script,
      sourceUrl: Uri.file(plugin.filePath).toString(),
      appVersion: appVersion,
      os: os,
      language: language,
      method: method,
      arguments: arguments,
      userVariables: plugin.meta.userVariables,
      storageKey: plugin.storageKey,
      timeout: timeout,
    );
    await _recordInvocationDiagnostics(plugin, method, result);
    return result;
  }

  Future<void> _recordInvocationDiagnostics(
    PluginRecord plugin,
    String method,
    PluginMethodCallResult result,
  ) async {
    try {
      final records = await _metaRepository.loadAll();
      // If the plugin was deleted between the invoke and now, skip the write
      // to avoid re-inserting a stale record.
      if (!records.containsKey(plugin.storageKey)) return;

      final existingMeta = records[plugin.storageKey]!;
      final existingDiagnostics = existingMeta.diagnostics;
      if (existingDiagnostics == null) return;

      final nextFailureCount = result.success
          ? existingDiagnostics.invokeFailureCount
          : existingDiagnostics.invokeFailureCount + 1;
      final nextStatus = result.didTimeout
          ? PluginParseStatus.warning
          : existingDiagnostics.status;

      final updatedDiagnostics = existingDiagnostics.copyWith(
        status: nextStatus,
        lastInvokeAt: DateTime.now(),
        invokeFailureCount: nextFailureCount,
      );
      final withError = result.success
          ? updatedDiagnostics
          : updatedDiagnostics.copyWith(
              lastInvokeErrorMessage: result.didTimeout
                  ? '[$method] ${result.errorMessage ?? "timeout"}'
                  : '[$method] ${result.errorMessage ?? "failed"}',
            );

      records[plugin.storageKey] = existingMeta.copyWith(
        diagnostics: withError,
      );
      await _metaRepository.saveAll(records);
    } catch (error) {
      // Diagnostics recording is best-effort. Never let it crash the caller.
      // ignore: avoid_print
      print('_recordInvocationDiagnostics: $error');
    }
  }

  /// Persists [variables] as the current plugin's user variables. Returns
  /// the refreshed snapshot so UI layers can pick up the new values.
  Future<PluginManagerSnapshot> updatePluginUserVariables(
    PluginRecord plugin,
    Map<String, String> variables,
  ) async {
    final records = await _metaRepository.loadAll();
    final existing = records[plugin.storageKey] ?? plugin.meta;
    final sanitized = <String, String>{};
    variables.forEach((key, value) {
      final trimmedKey = key.trim();
      if (trimmedKey.isEmpty) return;
      sanitized[trimmedKey] = value;
    });
    records[plugin.storageKey] = existing.copyWith(
      userVariables: Map.unmodifiable(sanitized),
    );
    await _metaRepository.saveAll(records);
    // Evict the cached runtime instance so the next call picks up new values.
    if (_runtime is PluginRuntimeHost) {
      final script = await _fileRepository.readScript(plugin.filePath);
      (_runtime).evictInstance(script);
    }
    return load();
  }

  Future<List<PluginRecord>> _loadPlugins() async {
    return (await load()).plugins;
  }
}
