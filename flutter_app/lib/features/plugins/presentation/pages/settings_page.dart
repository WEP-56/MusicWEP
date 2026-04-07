import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/filesystem/app_paths.dart';
import '../../../../shared/ui/app_shell.dart';
import '../../../downloads/download_providers.dart';
import '../../../settings/application/app_settings_controller.dart';
import '../../../settings/domain/app_settings.dart';
import '../../../settings/presentation/widgets/settings_controls.dart';
import '../../../settings/settings_providers.dart';
import '../../plugin_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final ScrollController _scrollController = ScrollController();
  final Map<_SettingsSection, GlobalKey> _sectionKeys = {
    for (final section in _SettingsSection.values) section: GlobalKey(),
  };
  _SettingsSection _selected = _SettingsSection.normal;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsControllerProvider);
    final appPathsAsync = ref.watch(appPathsProvider);
    final downloadSettingsAsync = ref.watch(downloadSettingsProvider);
    final cacheUsageAsync = ref.watch(cacheUsageBytesProvider);

    return AppShell(
      title: '设置',
      subtitle: '调整常规、播放、下载、歌词、插件与缓存相关行为。',
      child: settingsAsync.when(
        data: (settings) => appPathsAsync.when(
          data: (paths) => downloadSettingsAsync.when(
            data: (downloadSettings) {
              return Column(
                children: <Widget>[
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _SettingsSection.values.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final section = _SettingsSection.values[index];
                        return ChoiceChip(
                          label: Text(section.label),
                          selected: _selected == section,
                          onSelected: (_) => _scrollToSection(section),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      controller: _scrollController,
                      children: <Widget>[
                        _AnchoredSection(
                          key: _sectionKeys[_SettingsSection.normal],
                          title: _SettingsSection.normal.label,
                          child: _NormalSettingsSection(settings: settings),
                        ),
                        _AnchoredSection(
                          key: _sectionKeys[_SettingsSection.playMusic],
                          title: _SettingsSection.playMusic.label,
                          child: _PlayMusicSettingsSection(settings: settings),
                        ),
                        _AnchoredSection(
                          key: _sectionKeys[_SettingsSection.download],
                          title: _SettingsSection.download.label,
                          child: _DownloadSettingsSection(
                            settings: settings,
                            resolvedDownloadPath:
                                downloadSettings.downloadDirectoryPath,
                          ),
                        ),
                        _AnchoredSection(
                          key: _sectionKeys[_SettingsSection.lyric],
                          title: _SettingsSection.lyric.label,
                          child: _LyricSettingsSection(settings: settings),
                        ),
                        _AnchoredSection(
                          key: _sectionKeys[_SettingsSection.plugin],
                          title: _SettingsSection.plugin.label,
                          child: _PluginSettingsSection(settings: settings),
                        ),
                        _AnchoredSection(
                          key: _sectionKeys[_SettingsSection.cache],
                          title: _SettingsSection.cache.label,
                          child: _CacheSettingsSection(
                            settings: settings,
                            cacheUsageAsync: cacheUsageAsync,
                          ),
                        ),
                        _AnchoredSection(
                          key: _sectionKeys[_SettingsSection.shortCut],
                          title: _SettingsSection.shortCut.label,
                          child: const SettingsPlaceholder(
                            title: '快捷键',
                            description: '快捷键配置入口已预留，后续再接入按键录制与全局热键。',
                          ),
                        ),
                        _AnchoredSection(
                          key: _sectionKeys[_SettingsSection.network],
                          title: _SettingsSection.network.label,
                          child: const SettingsPlaceholder(
                            title: '网络',
                            description: '代理与网络诊断配置后续接入，当前先保留位置。',
                          ),
                        ),
                        _AnchoredSection(
                          key: _sectionKeys[_SettingsSection.backup],
                          title: _SettingsSection.backup.label,
                          child: _BackupSection(paths: paths),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
            error: (error, _) => Center(child: Text(error.toString())),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Center(child: Text(error.toString())),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _scrollToSection(_SettingsSection section) async {
    setState(() {
      _selected = section;
    });
    final context = _sectionKeys[section]?.currentContext;
    if (context == null) {
      return;
    }
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
  }
}

class _AnchoredSection extends StatelessWidget {
  const _AnchoredSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _NormalSettingsSection extends ConsumerWidget {
  const _NormalSettingsSection({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSectionCard(
      title: '常规',
      children: <Widget>[
        SettingsField(
          label: '关闭按钮行为',
          hint: '控制顶部栏关闭按钮点击后的默认行为。',
          child: SettingsChoiceChipBar<String>(
            value: settings.normal.closeBehavior,
            options: const <String>['tray', 'minimize', 'exit_app'],
            labelBuilder: (value) => switch (value) {
              'exit_app' => '退出应用',
              'tray' => '托盘运行',
              _ => '最小化',
            },
            onChanged: (value) => ref
                .read(appSettingsControllerProvider.notifier)
                .setNormalCloseBehavior(value),
          ),
        ),
      ],
    );
  }
}

class _PlayMusicSettingsSection extends ConsumerWidget {
  const _PlayMusicSettingsSection({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSectionCard(
      title: '播放',
      children: <Widget>[
        SettingsField(
          label: '默认播放音质',
          child: SettingsChoiceChipBar<String>(
            value: settings.playMusic.defaultQuality,
            options: const <String>['low', 'standard', 'high', 'super'],
            labelBuilder: _qualityLabel,
            onChanged: (value) => ref
                .read(appSettingsControllerProvider.notifier)
                .setPlayDefaultQuality(value),
          ),
        ),
        SettingsField(
          label: '音质缺失时',
          child: SettingsChoiceChipBar<String>(
            value: settings.playMusic.whenQualityMissing,
            options: const <String>['lower', 'higher', 'skip'],
            labelBuilder: (value) => switch (value) {
              'higher' => '优先更高音质',
              'skip' => '仅当前音质',
              _ => '优先更低音质',
            },
            onChanged: (value) => ref
                .read(appSettingsControllerProvider.notifier)
                .setPlayWhenQualityMissing(value),
          ),
        ),
        SettingsField(
          label: '双击列表歌曲',
          hint: '后续逐步让各列表页面统一读取这一项。',
          child: SettingsChoiceChipBar<String>(
            value: settings.playMusic.clickMusicList,
            options: const <String>['normal', 'replace'],
            labelBuilder: (value) => switch (value) {
              'normal' => '追加到播放列表',
              _ => '替换当前播放列表',
            },
            onChanged: (value) => ref
                .read(appSettingsControllerProvider.notifier)
                .setPlayClickMusicList(value),
          ),
        ),
      ],
    );
  }
}

class _DownloadSettingsSection extends ConsumerWidget {
  const _DownloadSettingsSection({
    required this.settings,
    required this.resolvedDownloadPath,
  });

  final AppSettings settings;
  final String resolvedDownloadPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appSettingsControllerProvider.notifier);
    return SettingsSectionCard(
      title: '下载',
      children: <Widget>[
        SettingsField(
          label: '下载目录',
          hint: '修改后会影响后续新增的下载任务。',
          child: SettingsPathField(
            path: settings.download.path?.trim().isNotEmpty == true
                ? settings.download.path!
                : resolvedDownloadPath,
            onChanged: (value) async {
              await controller.setDownloadPath(value);
              ref.invalidate(downloadSettingsProvider);
            },
          ),
        ),
        SettingsField(
          label: '最大并发数',
          child: SettingsChoiceChipBar<int>(
            value: settings.download.concurrency.clamp(1, 20).toInt(),
            options: List<int>.generate(10, (index) => index + 1),
            labelBuilder: (value) => '$value',
            onChanged: (value) async {
              await controller.setDownloadConcurrency(value);
              ref.invalidate(downloadSettingsProvider);
            },
          ),
        ),
        SettingsField(
          label: '默认下载音质',
          child: SettingsChoiceChipBar<String>(
            value: settings.download.defaultQuality,
            options: const <String>['low', 'standard', 'high', 'super'],
            labelBuilder: _qualityLabel,
            onChanged: (value) async {
              await controller.setDownloadDefaultQuality(value);
              ref.invalidate(downloadSettingsProvider);
            },
          ),
        ),
        SettingsField(
          label: '下载音质缺失时',
          child: SettingsChoiceChipBar<String>(
            value: settings.download.whenQualityMissing,
            options: const <String>['lower', 'higher', 'skip'],
            labelBuilder: (value) => switch (value) {
              'higher' => '优先更高音质',
              'skip' => '仅当前音质',
              _ => '优先更低音质',
            },
            onChanged: (value) async {
              await controller.setDownloadWhenQualityMissing(value);
              ref.invalidate(downloadSettingsProvider);
            },
          ),
        ),
      ],
    );
  }
}

class _LyricSettingsSection extends ConsumerWidget {
  const _LyricSettingsSection({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSectionCard(
      title: '歌词',
      children: <Widget>[
        SwitchListTile.adaptive(
          value: settings.lyric.enableDesktopLyric,
          contentPadding: EdgeInsets.zero,
          title: const Text('启用桌面歌词'),
          subtitle: const Text('打开后会跟随播放器状态显示独立歌词窗口。'),
          onChanged: (value) => ref
              .read(appSettingsControllerProvider.notifier)
              .setDesktopLyricEnabled(value),
        ),
      ],
    );
  }
}

class _PluginSettingsSection extends ConsumerWidget {
  const _PluginSettingsSection({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSectionCard(
      title: '插件',
      children: <Widget>[
        SwitchListTile.adaptive(
          value: settings.plugin.autoUpdatePlugin,
          contentPadding: EdgeInsets.zero,
          title: const Text('自动更新插件'),
          subtitle: const Text('当前先补配置项，自动更新调度后续接入。'),
          onChanged: (value) => ref
              .read(appSettingsControllerProvider.notifier)
              .setPluginAutoUpdate(value),
        ),
        SwitchListTile.adaptive(
          value: settings.plugin.notCheckPluginVersion,
          contentPadding: EdgeInsets.zero,
          title: const Text('跳过插件版本检查'),
          subtitle: const Text('当前先补配置项，版本校验接入后生效。'),
          onChanged: (value) => ref
              .read(appSettingsControllerProvider.notifier)
              .setPluginSkipVersionCheck(value),
        ),
      ],
    );
  }
}

class _CacheSettingsSection extends ConsumerWidget {
  const _CacheSettingsSection({
    required this.settings,
    required this.cacheUsageAsync,
  });

  final AppSettings settings;
  final AsyncValue<int> cacheUsageAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSectionCard(
      title: '缓存',
      children: <Widget>[
        SettingsField(
          label: '清除缓存',
          hint: '达到上限后会自动按最旧缓存优先清理。',
          child: Row(
            children: <Widget>[
              Expanded(
                child: cacheUsageAsync.when(
                  data: (value) =>
                      SelectableText('当前占用：${_formatBytes(value)}'),
                  error: (error, _) => Text('读取缓存失败：$error'),
                  loading: () => const Text('正在统计缓存占用...'),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: cacheUsageAsync.isLoading
                    ? null
                    : () => _showClearCacheDialog(context, ref),
                child: const Text('删除缓存'),
              ),
            ],
          ),
        ),
        SettingsField(
          label: '缓存最大值',
          hint: '达到此值会自动清理缓存。',
          child: SettingsChoiceChipBar<int>(
            value: settings.cache.maxSizeMb,
            options: const <int>[128, 256, 512, 1024, 2048, 4096],
            labelBuilder: (value) => value >= 1024
                ? '${(value / 1024).toStringAsFixed(value % 1024 == 0 ? 0 : 1)} GB'
                : '$value MB',
            onChanged: (value) async {
              await ref
                  .read(appSettingsControllerProvider.notifier)
                  .setCacheMaxSizeMb(value);
              ref.invalidate(cacheUsageBytesProvider);
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showClearCacheDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final currentUsage = ref.read(cacheUsageBytesProvider).valueOrNull ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('清除缓存'),
          content: Text('当前缓存占用 ${_formatBytes(currentUsage)}。\n\n确认删除缓存文件？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final manager = await ref.read(appCacheManagerProvider.future);
    await manager.clearCache();
    ref.invalidate(cacheUsageBytesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('缓存已清理。')));
    }
  }
}

class _BackupSection extends StatelessWidget {
  const _BackupSection({required this.paths});

  final AppPaths paths;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: '备份',
      children: <Widget>[
        SettingsField(
          label: '应用数据目录',
          child: SelectableText(paths.appDataDirectory.path),
        ),
        SettingsField(
          label: '插件目录',
          child: SelectableText(paths.pluginsDirectory.path),
        ),
        SettingsField(
          label: '日志目录',
          child: SelectableText(paths.logsDirectory.path),
        ),
        const Text('WebDAV 与备份恢复流程后续接入，这一节先保留本地目录信息。'),
      ],
    );
  }
}

enum _SettingsSection {
  normal('常规'),
  playMusic('播放'),
  download('下载'),
  lyric('歌词'),
  plugin('插件'),
  cache('缓存'),
  shortCut('快捷键'),
  network('网络'),
  backup('备份');

  const _SettingsSection(this.label);

  final String label;
}

String _qualityLabel(String value) {
  return switch (value) {
    'low' => '低音质',
    'high' => '高音质',
    'super' => '超高音质',
    _ => '标准音质',
  };
}

String _formatBytes(int bytes) {
  const units = <String>['B', 'KB', 'MB', 'GB'];
  var size = bytes.toDouble();
  var unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex += 1;
  }
  final fractionDigits = size >= 100 ? 0 : (size >= 10 ? 1 : 2);
  return '${size.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
}
