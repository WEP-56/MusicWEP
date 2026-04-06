import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/ui/app_shell.dart';
import '../../../../shared/ui/section_card.dart';
import '../../domain/plugin.dart';
import '../../plugin_providers.dart';

class SubscriptionsPage extends ConsumerWidget {
  const SubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(pluginControllerProvider);
    final controller = ref.read(pluginControllerProvider.notifier);

    return AppShell(
      title: '订阅',
      subtitle: '管理插件订阅源，并刷新整组音乐源。',
      actions: <Widget>[
        FilledButton.tonalIcon(
          onPressed: snapshot.isLoading
              ? null
              : () => _showSubscriptionEditor(context, controller),
          icon: const Icon(Icons.add_rounded),
          label: const Text('新增订阅'),
        ),
        FilledButton.icon(
          onPressed: snapshot.isLoading
              ? null
              : controller.refreshSubscriptions,
          icon: const Icon(Icons.sync_rounded),
          label: const Text('刷新全部'),
        ),
      ],
      child: snapshot.when(
        data: (data) {
          if (data.subscriptions.isEmpty) {
            return const SectionCard(child: Center(child: Text('还没有添加任何订阅源。')));
          }

          return SectionCard(
            padding: const EdgeInsets.all(8),
            child: ListView.separated(
              itemCount: data.subscriptions.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final subscription = data.subscriptions[index];
                return ListTile(
                  title: Text(subscription.name),
                  subtitle: Text(
                    <String>[
                      subscription.url,
                      if (subscription.lastRefreshMessage?.isNotEmpty == true)
                        subscription.lastRefreshMessage!,
                    ].join('\n'),
                  ),
                  trailing: IconButton(
                    tooltip: '移除订阅',
                    onPressed: () async {
                      final next = data.subscriptions.toList(growable: true)
                        ..removeAt(index);
                      await controller.saveSubscriptions(next);
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                  leading: Icon(switch (subscription.lastRefreshSucceeded) {
                    true => Icons.check_circle_outline_rounded,
                    false => Icons.error_outline_rounded,
                    null => Icons.schedule_rounded,
                  }),
                  isThreeLine:
                      subscription.lastRefreshMessage?.isNotEmpty == true,
                  onTap: () => _showSubscriptionEditor(
                    context,
                    controller,
                    existing: subscription,
                    editingIndex: index,
                    existingList: data.subscriptions,
                  ),
                );
              },
            ),
          );
        },
        error: (error, _) => SectionCard(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _showSubscriptionEditor(
    BuildContext context,
    PluginController controller, {
    PluginSubscription? existing,
    int? editingIndex,
    List<PluginSubscription> existingList = const <PluginSubscription>[],
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final urlController = TextEditingController(text: existing?.url ?? '');

    final result = await showDialog<PluginSubscription>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? '新增订阅' : '编辑订阅'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '名称'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: '链接',
                    hintText: 'https://example.com/plugins.json',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(
                  PluginSubscription(
                    name: nameController.text.trim().isEmpty
                        ? '默认订阅'
                        : nameController.text.trim(),
                    url: urlController.text.trim(),
                  ),
                );
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (result == null || result.url.isEmpty) {
      return;
    }

    final next = existingList.toList(growable: true);
    if (editingIndex != null) {
      next[editingIndex] = result;
    } else {
      next.add(result);
    }
    await controller.saveSubscriptions(next);
  }
}
