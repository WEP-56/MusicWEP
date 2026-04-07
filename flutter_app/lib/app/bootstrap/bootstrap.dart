import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app/app_environment_provider.dart';
import '../../features/plugins/plugin_providers.dart';
import '../../features/settings/application/app_settings_controller.dart';

final bootstrapProvider = FutureProvider<void>((ref) async {
  await ref.watch(appEnvironmentProvider.future);
  await ref.watch(appPathsProvider.future);
  await ref.watch(appSettingsControllerProvider.future);
  await ref.watch(pluginManagerServiceProvider.future);
});
