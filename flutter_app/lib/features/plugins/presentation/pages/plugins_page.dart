import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/ui/app_shell.dart';
import '../../domain/plugin.dart';
import '../../plugin_providers.dart';

class PluginsPage extends ConsumerWidget {
  const PluginsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(pluginControllerProvider);
    final controller = ref.read(pluginControllerProvider.notifier);
    final theme = Theme.of(context);

    return AppShell(
      title: '插件管理',
      subtitle: '安装、更新、卸载并管理音乐源插件。',
      child: snapshot.when(
        data: (data) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  OutlinedButton(
                    onPressed: snapshot.isLoading
                        ? null
                        : () async {
                            final picked = await FilePicker.platform.pickFiles(
                              allowMultiple: false,
                              type: FileType.custom,
                              allowedExtensions: const <String>['js', 'json'],
                            );
                            final path = picked?.files.single.path;
                            if (path == null || !context.mounted) {
                              return;
                            }
                            await controller.installFromLocal(path);
                          },
                    child: const Text('从本地文件安装'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: snapshot.isLoading
                        ? null
                        : () => _showInstallUrlDialog(context, controller),
                    child: const Text('从网络安装插件'),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => context.go('/subscriptions'),
                    child: const Text('订阅设置'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: snapshot.isLoading
                        ? null
                        : controller.refreshSubscriptions,
                    child: const Text('更新订阅'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: <Widget>[
                      const _PluginTableHeader(),
                      Expanded(
                        child: data.plugins.isEmpty
                            ? Center(
                                child: Text(
                                  '还没有安装任何插件。',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: data.plugins.length,
                                separatorBuilder: (_, _) => Divider(
                                  height: 1,
                                  color: theme.dividerColor,
                                ),
                                itemBuilder: (context, index) {
                                  final plugin = data.plugins[index];
                                  return _PluginTableRow(
                                    index: index,
                                    plugin: plugin,
                                    onUpdate: plugin.sourceUrl == null
                                        ? null
                                        : () => controller.updatePlugin(plugin),
                                    onDelete: () =>
                                        controller.uninstallPlugin(plugin),
                                    onDetails: () => context.go(
                                      '/plugins/${Uri.encodeComponent(plugin.storageKey)}',
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        error: (error, _) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _showInstallUrlDialog(
    BuildContext context,
    PluginController controller,
  ) async {
    final textController = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('安装插件'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '粘贴 .js 插件链接或 .json 订阅地址',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(textController.text.trim()),
              child: const Text('安装'),
            ),
          ],
        );
      },
    );

    if (value != null && value.isNotEmpty) {
      await controller.installFromUrl(value);
    }
  }
}

class _PluginTableHeader extends StatelessWidget {
  const _PluginTableHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 60,
            child: Center(child: Text('#', style: headerStyle)),
          ),
          Expanded(flex: 3, child: Text('来源', style: headerStyle)),
          Expanded(flex: 2, child: Text('版本号', style: headerStyle)),
          Expanded(flex: 2, child: Text('作者', style: headerStyle)),
          Expanded(flex: 4, child: Text('操作', style: headerStyle)),
        ],
      ),
    );
  }
}

class _PluginTableRow extends StatelessWidget {
  const _PluginTableRow({
    required this.index,
    required this.plugin,
    required this.onDetails,
    required this.onDelete,
    this.onUpdate,
  });

  final int index;
  final PluginRecord plugin;
  final VoidCallback onDetails;
  final VoidCallback onDelete;
  final VoidCallback? onUpdate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 60,
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              plugin.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              plugin.version ?? '-',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              plugin.manifest?.author?.trim().isNotEmpty == true
                  ? plugin.manifest!.author!
                  : '未知作者',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 4,
            child: Wrap(
              spacing: 12,
              children: <Widget>[
                _ActionText(label: '详情', onTap: onDetails),
                _ActionText(label: '更新', onTap: onUpdate),
                _ActionText(label: '卸载', onTap: onDelete, danger: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionText extends StatelessWidget {
  const _ActionText({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final accent = AppTheme.colorsOf(context).accent;
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: disabled
              ? Theme.of(context).disabledColor
              : (danger ? const Color(0xFFE65C4F) : accent),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
