import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/ui/app_shell.dart';
import '../../../downloads/domain/download_models.dart';
import '../../../downloads/download_providers.dart';

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(downloadControllerProvider);
    final downloadedTasks = ref.watch(downloadedTasksProvider);
    final downloadingTasks = ref.watch(downloadingTasksProvider);

    return AppShell(
      title: '下载管理',
      subtitle: '查看已下载歌曲和当前下载任务。',
      child: DefaultTabController(
        length: 2,
        child: Builder(
          builder: (context) {
            if (tasksAsync.hasError && tasksAsync.valueOrNull == null) {
              return Center(child: Text(tasksAsync.error.toString()));
            }
            if (tasksAsync.isLoading && tasksAsync.valueOrNull == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return _DownloadsBody(
              downloadedTasks: downloadedTasks,
              downloadingTasks: downloadingTasks,
            );
          },
        ),
      ),
    );
  }
}

class _DownloadsBody extends StatelessWidget {
  const _DownloadsBody({
    required this.downloadedTasks,
    required this.downloadingTasks,
  });

  final List<DownloadTask> downloadedTasks;
  final List<DownloadTask> downloadingTasks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTheme.colorsOf(context).accent;
    return Column(
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: theme.colorScheme.onSurface,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorColor: accent,
            dividerColor: theme.dividerColor,
            tabs: <Widget>[
              Tab(text: '已下载 (${downloadedTasks.length})'),
              Tab(text: '下载中 (${downloadingTasks.length})'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            children: <Widget>[
              _TaskTable(
                emptyIcon: Icons.download_done_rounded,
                emptyTitle: '暂无已下载歌曲',
                emptyDescription: '从搜索、歌单、排行榜或播放列表里点击下载后，完成的歌曲会显示在这里。',
                tasks: downloadedTasks,
                showStatusColumn: false,
              ),
              _TaskTable(
                emptyIcon: Icons.downloading_rounded,
                emptyTitle: '暂无下载任务',
                emptyDescription: '加入下载队列的歌曲会在这里显示等待、进度或失败原因。',
                tasks: downloadingTasks,
                showStatusColumn: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskTable extends ConsumerWidget {
  const _TaskTable({
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.tasks,
    required this.showStatusColumn,
  });

  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyDescription;
  final List<DownloadTask> tasks;
  final bool showStatusColumn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (tasks.isEmpty) {
      return _DownloadEmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        description: emptyDescription,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppTheme.translucentSurfaceVariant(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: <Widget>[
                const SizedBox(width: 44, child: Text('#')),
                const Expanded(flex: 4, child: Text('标题')),
                const Expanded(flex: 3, child: Text('歌手')),
                const Expanded(flex: 3, child: Text('专辑')),
                if (showStatusColumn)
                  const Expanded(flex: 3, child: Text('状态'))
                else
                  const Expanded(flex: 3, child: Text('保存位置')),
                const SizedBox(width: 88, child: Text('来源')),
                const SizedBox(
                  width: 96,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('操作'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: tasks.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: theme.dividerColor),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _TaskRow(
                  index: index,
                  task: task,
                  showStatusColumn: showStatusColumn,
                  onRetry: task.status == DownloadTaskStatus.failed
                      ? () => ref
                            .read(downloadControllerProvider.notifier)
                            .retryTask(task.id)
                      : null,
                  onDelete: () => ref
                      .read(downloadControllerProvider.notifier)
                      .removeTask(
                        task.id,
                        deleteFile: task.status == DownloadTaskStatus.completed,
                      ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.index,
    required this.task,
    required this.showStatusColumn,
    required this.onDelete,
    this.onRetry,
  });

  final int index;
  final DownloadTask task;
  final bool showStatusColumn;
  final VoidCallback onDelete;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTheme.colorsOf(context).accent;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 44,
            child: Text(
              '${index + 1}',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              task.track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              task.track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              task.track.album ?? '-',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            flex: 3,
            child: showStatusColumn
                ? _DownloadStatusText(task: task)
                : Text(
                    task.filePath ?? '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
          ),
          SizedBox(
            width: 88,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  task.track.platform,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 96,
            child: Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 4,
                children: <Widget>[
                  if (onRetry != null)
                    IconButton(
                      tooltip: '重试',
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  IconButton(
                    tooltip: task.status == DownloadTaskStatus.completed
                        ? '删除文件'
                        : '移除任务',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadStatusText extends StatelessWidget {
  const _DownloadStatusText({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = switch (task.status) {
      DownloadTaskStatus.waiting => '等待中',
      DownloadTaskStatus.downloading =>
        '${_formatBytes(task.downloadedBytes)} / ${_formatBytes(task.totalBytes ?? 0)}',
      DownloadTaskStatus.failed =>
        task.errorMessage?.trim().isNotEmpty == true
            ? '失败：${task.errorMessage}'
            : '下载失败',
      DownloadTaskStatus.completed => '已完成',
    };
    final color = switch (task.status) {
      DownloadTaskStatus.waiting => theme.colorScheme.onSurfaceVariant,
      DownloadTaskStatus.downloading => const Color(0xFF0A95C8),
      DownloadTaskStatus.failed => theme.colorScheme.error,
      DownloadTaskStatus.completed => const Color(0xFF0A95C8),
    };
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color),
    );
  }
}

class _DownloadEmptyState extends StatelessWidget {
  const _DownloadEmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTheme.colorsOf(context).accent;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 52, color: accent),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  const units = <String>['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }
  final fixed = value >= 100
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$fixed ${units[unitIndex]}';
}
