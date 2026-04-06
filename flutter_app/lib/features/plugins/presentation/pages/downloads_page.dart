import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/ui/app_shell.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: AppShell(
        title: '下载管理',
        subtitle: '查看已下载歌曲和正在进行中的下载任务。',
        child: _DownloadsBody(),
      ),
    );
  }
}

class _DownloadsBody extends StatelessWidget {
  const _DownloadsBody();

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
            tabs: const <Widget>[
              Tab(text: '已下载'),
              Tab(text: '下载中'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Expanded(
          child: TabBarView(
            children: <Widget>[
              _DownloadEmptyState(
                icon: Icons.download_done_rounded,
                title: '暂无已下载歌曲',
                description: '下载器数据层还未迁移完成，这里先保留与原项目一致的页面结构。',
              ),
              _DownloadEmptyState(
                icon: Icons.downloading_rounded,
                title: '暂无下载任务',
                description: '后续接入真实下载队列后，这里会显示实时状态与进度。',
              ),
            ],
          ),
        ),
      ],
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
        color: theme.colorScheme.surface,
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
