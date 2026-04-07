import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../plugins/plugin_providers.dart';
import 'application/app_cache_manager.dart';

final appCacheManagerProvider = FutureProvider<AppCacheManager>((ref) async {
  final appPaths = await ref.watch(appPathsProvider.future);
  return AppCacheManager(appPaths);
});

final cacheUsageBytesProvider = FutureProvider<int>((ref) async {
  final manager = await ref.watch(appCacheManagerProvider.future);
  return manager.getCacheSizeBytes();
});
