import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app/app_environment_provider.dart';
import '../../core/filesystem/app_paths.dart';
import '../../core/runtime/plugin_runtime_host.dart';
import '../../core/storage/json_file_store.dart';
import 'application/plugin_method_service.dart';
import 'application/plugin_manager_service.dart';
import 'domain/plugin.dart';
import 'infrastructure/plugin_file_repository.dart';
import 'infrastructure/plugin_meta_repository.dart';
import 'infrastructure/plugin_subscription_repository.dart';

final appPathsProvider = FutureProvider<AppPaths>((ref) async {
  return AppPaths.create();
});

final pluginManagerServiceProvider = FutureProvider<PluginManagerService>((
  ref,
) async {
  final appEnvironment = await ref.watch(appEnvironmentProvider.future);
  final appPaths = await ref.watch(appPathsProvider.future);
  final runtime = PluginRuntimeHost(appPaths: appPaths);
  ref.onDispose(runtime.dispose);

  return PluginManagerService(
    fileRepository: PluginFileRepository(appPaths),
    metaRepository: PluginMetaRepository(
      JsonFileStore(appPaths.pluginMetaFilePath),
    ),
    subscriptionRepository: PluginSubscriptionRepository(
      JsonFileStore(appPaths.subscriptionsFilePath),
    ),
    runtime: runtime,
    appVersion: appEnvironment.version,
    os: appEnvironment.runtimeOs,
    language: appEnvironment.languageTag,
  );
});

final pluginSnapshotProvider = FutureProvider<PluginManagerSnapshot>((
  ref,
) async {
  final service = await ref.watch(pluginManagerServiceProvider.future);
  return service.load();
});

final pluginMethodServiceProvider = FutureProvider<PluginMethodService>((
  ref,
) async {
  final service = await ref.watch(pluginManagerServiceProvider.future);
  return PluginMethodService(service);
});

class PluginController extends AsyncNotifier<PluginManagerSnapshot> {
  @override
  Future<PluginManagerSnapshot> build() async {
    final service = await ref.watch(pluginManagerServiceProvider.future);
    return service.load();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = await ref.read(pluginManagerServiceProvider.future);
      return service.load();
    });
  }

  Future<void> installFromLocal(String sourcePath) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = await ref.read(pluginManagerServiceProvider.future);
      return service.installFromLocal(sourcePath);
    });
  }

  Future<void> installFromUrl(String url) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = await ref.read(pluginManagerServiceProvider.future);
      return service.installFromUrl(url);
    });
  }

  Future<void> setPluginEnabled(PluginRecord plugin, bool enabled) async {
    final previous = state;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = await ref.read(pluginManagerServiceProvider.future);
      return service.setPluginEnabled(plugin, enabled);
    });
    if (state.hasError) {
      state = previous;
    }
  }

  Future<void> uninstallPlugin(PluginRecord plugin) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = await ref.read(pluginManagerServiceProvider.future);
      return service.uninstallPlugin(plugin);
    });
  }

  Future<void> reorderPlugins(List<PluginRecord> plugins) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = await ref.read(pluginManagerServiceProvider.future);
      return service.reorderPlugins(plugins);
    });
  }

  Future<void> updatePlugin(PluginRecord plugin) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = await ref.read(pluginManagerServiceProvider.future);
      return service.updatePlugin(plugin);
    });
  }

  Future<void> saveSubscriptions(List<PluginSubscription> subscriptions) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = await ref.read(pluginManagerServiceProvider.future);
      return service.saveSubscriptions(subscriptions);
    });
  }

  Future<void> refreshSubscriptions() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = await ref.read(pluginManagerServiceProvider.future);
      return service.refreshSubscriptions();
    });
  }
}

final pluginControllerProvider =
    AsyncNotifierProvider<PluginController, PluginManagerSnapshot>(
      PluginController.new,
    );
