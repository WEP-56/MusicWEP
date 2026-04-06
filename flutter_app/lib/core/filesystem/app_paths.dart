import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class AppPaths {
  const AppPaths({
    required this.rootDirectory,
    required this.appDataDirectory,
    required this.pluginsDirectory,
    required this.cacheDirectory,
    required this.pluginRuntimeCacheDirectory,
    required this.logsDirectory,
    required this.pluginLogsDirectory,
    required this.configFilePath,
    required this.pluginMetaFilePath,
    required this.subscriptionsFilePath,
    required this.pluginStorageFilePath,
    required this.pluginCookiesFilePath,
  });

  final Directory rootDirectory;
  final Directory appDataDirectory;
  final Directory pluginsDirectory;
  final Directory cacheDirectory;
  final Directory pluginRuntimeCacheDirectory;
  final Directory logsDirectory;
  final Directory pluginLogsDirectory;
  final String configFilePath;
  final String pluginMetaFilePath;
  final String subscriptionsFilePath;
  final String pluginStorageFilePath;
  final String pluginCookiesFilePath;

  static Future<AppPaths> create() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final rootDirectory = Directory(
      path.join(supportDirectory.path, 'musicfree_flutter'),
    );

    final appDataDirectory = Directory(
      path.join(rootDirectory.path, 'app_data'),
    );
    final pluginsDirectory = Directory(
      path.join(rootDirectory.path, 'plugins'),
    );
    final cacheDirectory = Directory(path.join(rootDirectory.path, 'cache'));
    final pluginRuntimeCacheDirectory = Directory(
      path.join(cacheDirectory.path, 'plugin_runtime'),
    );
    final logsDirectory = Directory(path.join(rootDirectory.path, 'logs'));
    final pluginLogsDirectory = Directory(
      path.join(logsDirectory.path, 'plugins'),
    );

    for (final directory in <Directory>[
      rootDirectory,
      appDataDirectory,
      pluginsDirectory,
      cacheDirectory,
      pluginRuntimeCacheDirectory,
      logsDirectory,
      pluginLogsDirectory,
    ]) {
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    }

    return AppPaths(
      rootDirectory: rootDirectory,
      appDataDirectory: appDataDirectory,
      pluginsDirectory: pluginsDirectory,
      cacheDirectory: cacheDirectory,
      pluginRuntimeCacheDirectory: pluginRuntimeCacheDirectory,
      logsDirectory: logsDirectory,
      pluginLogsDirectory: pluginLogsDirectory,
      configFilePath: path.join(appDataDirectory.path, 'config.json'),
      pluginMetaFilePath: path.join(appDataDirectory.path, 'plugin_meta.json'),
      subscriptionsFilePath: path.join(
        appDataDirectory.path,
        'subscriptions.json',
      ),
      pluginStorageFilePath: path.join(
        appDataDirectory.path,
        'plugin_storage.json',
      ),
      pluginCookiesFilePath: path.join(
        appDataDirectory.path,
        'plugin_cookies.json',
      ),
    );
  }
}
