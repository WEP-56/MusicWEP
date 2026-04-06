import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import '../../../core/runtime/plugin_runtime_adapter.dart';
import '../domain/plugin.dart';
import '../infrastructure/plugin_file_repository.dart';
import '../infrastructure/plugin_meta_repository.dart';
import '../infrastructure/plugin_subscription_repository.dart';

class PluginInstallationCoordinator {
  const PluginInstallationCoordinator({
    required PluginFileRepository fileRepository,
    required PluginMetaRepository metaRepository,
    required PluginSubscriptionRepository subscriptionRepository,
    required PluginRuntimeAdapter runtime,
    required Future<List<PluginRecord>> Function() loadPlugins,
    required this.appVersion,
    required this.os,
    required this.language,
  }) : _fileRepository = fileRepository,
       _metaRepository = metaRepository,
       _subscriptionRepository = subscriptionRepository,
       _runtime = runtime,
       _loadPlugins = loadPlugins;

  final PluginFileRepository _fileRepository;
  final PluginMetaRepository _metaRepository;
  final PluginSubscriptionRepository _subscriptionRepository;
  final PluginRuntimeAdapter _runtime;
  final Future<List<PluginRecord>> Function() _loadPlugins;
  final String appVersion;
  final String os;
  final String language;

  Future<void> installFromLocal(String sourcePath) async {
    final lowerExtension = path.extension(sourcePath).toLowerCase();
    if (lowerExtension == '.json') {
      final raw = await File(sourcePath).readAsString();
      final urls = extractSubscriptionUrls(raw);
      for (final url in urls) {
        await installFromRemoteScriptUrl(url);
      }
      return;
    }

    final script = await _fileRepository.readScript(sourcePath);
    await installScript(
      script,
      sourceUrl: Uri.file(sourcePath).toString(),
      preferredBaseName: path.basenameWithoutExtension(sourcePath),
    );
  }

  Future<void> installFromUrl(String inputUrl) async {
    final urls = await resolveInstallUrls(inputUrl.trim());
    for (final url in urls) {
      await installFromRemoteScriptUrl(url);
    }
  }

  Future<void> saveSubscriptions(List<PluginSubscription> subscriptions) async {
    final existing = await _subscriptionRepository.loadAll();
    final merged = subscriptions
        .map((subscription) => mergeSubscription(existing, subscription))
        .toList(growable: false);
    await _subscriptionRepository.saveAll(merged);
  }

  Future<void> refreshSubscriptions() async {
    final subscriptions = await _subscriptionRepository.loadAll();
    final refreshed = <PluginSubscription>[];
    for (final subscription in subscriptions) {
      try {
        final urls = await resolveInstallUrls(subscription.url);
        for (final url in urls) {
          await installFromRemoteScriptUrl(url);
        }
        refreshed.add(
          subscription.copyWith(
            lastRefreshedAt: DateTime.now(),
            lastRefreshSucceeded: true,
            lastRefreshMessage: urls.isEmpty
                ? 'Subscription is empty.'
                : 'Installed ${urls.length} plugin source(s).',
            installedPluginCount: urls.length,
          ),
        );
      } catch (error) {
        refreshed.add(
          subscription.copyWith(
            lastRefreshedAt: DateTime.now(),
            lastRefreshSucceeded: false,
            lastRefreshMessage: error.toString(),
            installedPluginCount: 0,
          ),
        );
      }
    }
    await _subscriptionRepository.saveAll(refreshed);
  }

  Future<void> updatePlugin(PluginRecord plugin) async {
    final sourceUrl = plugin.sourceUrl;
    if (sourceUrl == null || sourceUrl.isEmpty) {
      throw Exception('Plugin has no source URL.');
    }
    await installFromUrl(sourceUrl);
  }

  Future<void> installScript(
    String script, {
    required String sourceUrl,
    String? preferredBaseName,
  }) async {
    final hash = _fileRepository.calculateHash(script);
    final currentPlugins = await _loadPlugins();
    if (currentPlugins.any((plugin) => plugin.hash == hash)) {
      return;
    }

    final runtimeResult = await _runtime.inspectPlugin(
      script: script,
      sourceUrl: sourceUrl,
      appVersion: appVersion,
      os: os,
      language: language,
    );
    final manifest = runtimeResult.manifest;
    if (manifest == null || manifest.platform.trim().isEmpty) {
      throw Exception(
        runtimeResult.diagnostics.message ?? 'Plugin parsing failed.',
      );
    }
    if (runtimeResult.diagnostics.status == PluginParseStatus.error) {
      throw Exception(
        runtimeResult.diagnostics.message ?? 'Plugin inspection failed.',
      );
    }

    final storageKey = manifest.platform;
    final existingPlugin = currentPlugins
        .where((plugin) => plugin.storageKey == storageKey)
        .cast<PluginRecord?>()
        .firstOrNull;
    final existingMeta = existingPlugin?.meta ?? PluginMetaRecord.initial();
    final persistedSourceUrl = resolveStoredSourceUrl(
      manifestSourceUrl: manifest.sourceUrl,
      existingSourceUrl: existingPlugin?.sourceUrl,
      installSourceUrl: isRemoteUrl(sourceUrl) ? sourceUrl : null,
    );

    for (final plugin in currentPlugins) {
      if (plugin.storageKey == storageKey) {
        await _fileRepository.deletePlugin(plugin.filePath);
      }
    }

    await _fileRepository.writeScript(
      script,
      preferredBaseName: preferredBaseName,
    );

    final records = await _metaRepository.loadAll();
    records[storageKey] = existingMeta.copyWith(
      sourceUrl: persistedSourceUrl,
      installedVersion: manifest.version,
      lastUpdatedAt: DateTime.now(),
      lastUpdateMessage: runtimeResult.diagnostics.message,
      diagnostics: runtimeResult.diagnostics,
      order: existingPlugin?.meta.order ?? currentPlugins.length,
    );
    await _metaRepository.saveAll(records);
  }

  Future<List<String>> resolveInstallUrls(String inputUrl) async {
    if (!inputUrl.toLowerCase().endsWith('.json')) {
      return <String>[inputUrl];
    }

    final response = await http.get(Uri.parse(inputUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to fetch subscription JSON: $inputUrl');
    }
    return extractSubscriptionUrls(response.body);
  }

  Future<void> installFromRemoteScriptUrl(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to download plugin ($url): HTTP ${response.statusCode}',
      );
    }
    await installScript(
      response.body,
      sourceUrl: url,
      preferredBaseName: path.basenameWithoutExtension(Uri.parse(url).path),
    );
  }

  List<String> extractSubscriptionUrls(String rawJson) {
    final payload = jsonDecode(rawJson);
    if (payload is Map<String, dynamic> && payload['plugins'] is List) {
      return _readPluginUrlList(payload['plugins'] as List<dynamic>);
    }
    if (payload is Map && payload['plugins'] is List) {
      return _readPluginUrlList(payload['plugins'] as List<dynamic>);
    }
    return <String>[];
  }

  List<String> _readPluginUrlList(List<dynamic> plugins) {
    return plugins
        .whereType<Map>()
        .map((entry) => entry['url']?.toString() ?? '')
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
  }

  PluginSubscription mergeSubscription(
    List<PluginSubscription> existing,
    PluginSubscription next,
  ) {
    final match = existing
        .where((subscription) => subscription.url == next.url)
        .cast<PluginSubscription?>()
        .firstOrNull;
    if (match == null) {
      return next;
    }
    return next.copyWith(
      lastRefreshedAt: match.lastRefreshedAt,
      lastRefreshMessage: match.lastRefreshMessage,
      lastRefreshSucceeded: match.lastRefreshSucceeded,
      installedPluginCount: match.installedPluginCount,
    );
  }

  String? resolveStoredSourceUrl({
    required String? manifestSourceUrl,
    required String? existingSourceUrl,
    String? installSourceUrl,
  }) {
    if (manifestSourceUrl != null && manifestSourceUrl.trim().isNotEmpty) {
      return manifestSourceUrl.trim();
    }
    if (installSourceUrl != null && installSourceUrl.trim().isNotEmpty) {
      return installSourceUrl.trim();
    }
    return existingSourceUrl;
  }

  bool isRemoteUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }
}
