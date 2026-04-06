import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app/app_environment_provider.dart';
import '../../../../shared/ui/app_shell.dart';
import '../../../../shared/ui/section_card.dart';
import '../../plugin_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appEnvironment = ref.watch(appEnvironmentProvider);
    final appPaths = ref.watch(appPathsProvider);

    return AppShell(
      title: '设置',
      subtitle: '查看版本、平台信息和本地数据目录。',
      child: appEnvironment.when(
        data: (environment) => appPaths.when(
          data: (paths) {
            return ListView(
              children: <Widget>[
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '应用信息',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      _SettingLine(label: '应用名', value: environment.appName),
                      _SettingLine(label: '包名', value: environment.packageName),
                      _SettingLine(label: '版本', value: environment.version),
                      _SettingLine(
                        label: '构建号',
                        value: environment.buildNumber,
                      ),
                      _SettingLine(
                        label: '平台',
                        value: environment.platform.name,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '数据目录',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      _SettingLine(
                        label: '根目录',
                        value: paths.rootDirectory.path,
                      ),
                      _SettingLine(
                        label: '应用数据',
                        value: paths.appDataDirectory.path,
                      ),
                      _SettingLine(
                        label: '插件目录',
                        value: paths.pluginsDirectory.path,
                      ),
                      _SettingLine(
                        label: '缓存目录',
                        value: paths.cacheDirectory.path,
                      ),
                      _SettingLine(
                        label: '日志目录',
                        value: paths.logsDirectory.path,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          error: (error, _) => SectionCard(child: Text(error.toString())),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => SectionCard(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _SettingLine extends StatelessWidget {
  const _SettingLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          SelectableText(value),
        ],
      ),
    );
  }
}
